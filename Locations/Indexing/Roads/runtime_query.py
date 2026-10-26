"""Bounded searches on runtime.json only. No native roads, footprints or rebuilds."""
import argparse
import heapq
import json
import math
from pathlib import Path


def require_schema(package):
    if package.get('schemaVersion') != 2:
        raise ValueError('Runtime schema 2 required; rebuild the index before querying split-edge geography')


def candidate_indices(package, location_id, kind=None, tier=None, maximum_gap_m=None, limit=None):
    """Cheap per-site shortlist, ordered by measured gap/connector, with no default cap.

    This is a geometric filter only. Mobility, threat, utility and feasibility remain
    Analysis decisions. The export retains every candidate even when a caller limits
    this returned shortlist.
    """
    require_schema(package)
    if limit is not None and (not isinstance(limit, int) or limit < 0):
        raise ValueError('Candidate limit must be a nonnegative integer or None')
    if maximum_gap_m is not None and (not math.isfinite(maximum_gap_m) or maximum_gap_m < 0):
        raise ValueError('Maximum gap must be finite and nonnegative')
    location = package['locationIndexById'][location_id]
    result = []
    for i in package['attachmentsByLocation'][location]:
        a = package['attachments'][i]
        if kind is not None and a[3] != kind:
            continue
        if tier is not None and a[4] != tier:
            continue
        if maximum_gap_m is not None and a[5] > maximum_gap_m:
            continue
        result.append(i)
    return result if limit is None else result[:limit]


def attachment_details(package, attachment_id):
    """Execution handoff coordinates and uncertainty using only the compact package."""
    require_schema(package)
    i = package['attachmentIndexById'][attachment_id]
    a, g = package['attachments'][i], package['attachmentGeometry'][i]
    return {'attachmentId': a[0], 'locationId': package['locations'][a[1]],
            'nodeId': package['nodes'][a[2]][0],
            'componentId': package['components'][package['nodes'][a[2]][1]],
            'kind': a[3], 'candidateTier': a[4], 'offRoadGapM': a[5], 'anchorConnectorM': a[6],
            'roadDepartureASL': list(g[0]), 'projectedAnchorASL': list(g[1]),
            'footprintApproach2D': list(g[2]), 'footprintApproachHeightStatus': g[3],
            'vehicleTraversalStatus': g[4]}


def route_geography(package, edge_path):
    """Actual footprint interior along an oriented split-edge walk, plus nearby evidence.

    Only nonempty intervals count as overlap. Nearby outside relationships are
    returned separately and never imply control or a complete alternative route.
    """
    require_schema(package)
    inside, nearby = {}, {}
    offset = 0.0
    previous_node = None
    for eid, direction in edge_path:
        if direction not in [-1, 1]:
            raise ValueError('Edge orientation must be 1 or -1')
        edge = package['edges'][eid]
        start_node, end_node = (edge[0], edge[1]) if direction == 1 else (edge[1], edge[0])
        if previous_node is not None and previous_node != start_node:
            raise ValueError('Route geometry requires a contiguous edge walk')
        previous_node = end_node
        length = edge[2]
        for index in package['corridorsByEdge'][eid]:
            location, _, relation, gap, intervals = package['corridors'][index]
            location_id = package['locations'][location]
            if intervals:
                record = inside.setdefault(location, {'locationId': location_id, 'insideDistanceM': 0.0,
                                                       'routeIntervalsM': [], 'edgeIds': []})
                record['edgeIds'].append(package['edgeIds'][eid])
                ordered = intervals if direction == 1 else reversed(intervals)
                for lo, hi in ordered:
                    left, right = (lo, hi) if direction == 1 else (length-hi, length-lo)
                    record['routeIntervalsM'].append([offset+left, offset+right])
                    record['insideDistanceM'] += hi-lo
            elif relation == 'bypasses':
                record = nearby.setdefault(location, {'locationId': location_id, 'nearestGapM': gap, 'edgeIds': []})
                record['nearestGapM'] = min(record['nearestGapM'], gap)
                record['edgeIds'].append(package['edgeIds'][eid])
        offset += length
    return {'overlappingLocations': [inside[i] for i in sorted(inside)],
            'nearbyOutsideLocations': [nearby[i] for i in sorted(nearby)],
            'interpretation': package['geographicSemantics']}


def find_route(package, start_id, target_id, blocked_source_edges=(), blocked_bridge_roads=(),
               road_type_weights=None, offroad_weight=1.0, maximum_nodes=10000):
    require_schema(package)
    weights = dict(road_type_weights or {})
    if offroad_weight < 0 or any(not math.isfinite(v) or v < 0 for v in weights.values()) or not math.isfinite(offroad_weight):
        raise ValueError('Cost weights must be finite and nonnegative')
    a = package['attachments'][package['attachmentIndexById'][start_id]]
    b = package['attachments'][package['attachmentIndexById'][target_id]]
    start, target = a[2], b[2]
    base = {'fromAttachmentId': start_id, 'toAttachmentId': target_id,
            'dependencies': package['dependencies'], 'offRoadGapM': [a[5], b[5]],
            'anchorConnectorM': [a[6], b[6]], 'approachAssessment': 'unassessed',
            'endpointApproaches': [attachment_details(package, start_id), attachment_details(package, target_id)]}
    if package['nodes'][start][1] != package['nodes'][target][1]:
        return dict(base, status='disconnected-road-networks', visitedNodes=0)
    blocked_sources, blocked_bridges = set(blocked_source_edges), set(blocked_bridge_roads)
    queue = [(0.0, start)]
    costs = {start: 0.0}
    parents = {}
    visited = 0
    while queue:
        cost, at = heapq.heappop(queue)
        if cost != costs[at]:
            continue
        visited += 1
        if visited > maximum_nodes:
            return dict(base, status='search-limit', visitedNodes=visited-1)
        if at == target:
            path = []
            while at != start:
                prev, eid = parents[at]
                e = package['edges'][eid]
                path.append([eid, 1 if e[0] == prev else -1])
                at = prev
            path.reverse()
            road_distance = sum(package['edges'][eid][2] for eid, _ in path)
            return dict(base, status='found', visitedNodes=visited, roadDistanceM=road_distance,
                        road2dM=sum(package['edges'][eid][3] for eid, _ in path),
                        policyCost=cost+sum(base['anchorConnectorM'])+offroad_weight*sum(base['offRoadGapM']),
                        edgePath=path, geography=route_geography(package, path),
                        edgeIds=[package['edgeIds'][eid] for eid, _ in path])
        for nxt, eid in package['adjacency'][at]:
            e = package['edges'][eid]
            attr = package['attributes'][e[4]]
            if package['sourceEdgeIds'][e[5]] in blocked_sources or blocked_bridges.intersection(attr['bridgeRoadIds']):
                continue
            multiplier = max((weights.get(t, 1.0) for t in attr['roadTypes']), default=1.0)
            value = cost+e[2]*multiplier
            if value < costs.get(nxt, math.inf):
                costs[nxt] = value
                parents[nxt] = (at, eid)
                heapq.heappush(queue, (value, nxt))
    return dict(base, status='no-road-route-under-overlay', visitedNodes=visited)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('from_attachment')
    parser.add_argument('to_attachment')
    parser.add_argument('--runtime', type=Path, default=Path(__file__).parent/'output/altis/runtime.json')
    parser.add_argument('--block-edge', action='append', default=[])
    parser.add_argument('--block-bridge', action='append', default=[])
    parser.add_argument('--maximum-nodes', type=int, default=10000)
    args = parser.parse_args()
    package = json.loads(args.runtime.read_text(encoding='utf-8'))
    print(json.dumps(find_route(package, args.from_attachment, args.to_attachment,
                                args.block_edge, args.block_bridge, maximum_nodes=args.maximum_nodes), indent=2))


if __name__ == '__main__':
    main()
