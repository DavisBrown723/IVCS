"""Bounded searches on runtime.json only. No native roads, footprints or rebuilds."""
import argparse
import heapq
import json
import math
from pathlib import Path


def find_route(package, start_id, target_id, blocked_source_edges=(), blocked_bridge_roads=(),
               road_type_weights=None, offroad_weight=1.0, maximum_nodes=10000):
    weights = dict(road_type_weights or {})
    if offroad_weight < 0 or any(not math.isfinite(v) or v < 0 for v in weights.values()) or not math.isfinite(offroad_weight):
        raise ValueError('Cost weights must be finite and nonnegative')
    access = {a[0]: a for a in package['attachments']}
    a, b = access[start_id], access[target_id]
    start, target = a[2], b[2]
    base = {'fromAttachmentId': start_id, 'toAttachmentId': target_id,
            'dependencies': package['dependencies'], 'offRoadGapM': [a[5], b[5]],
            'anchorConnectorM': [a[6], b[6]], 'approachAssessment': 'unassessed'}
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
                        edgePath=path,
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
