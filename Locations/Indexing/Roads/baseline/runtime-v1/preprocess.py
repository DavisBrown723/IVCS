"""Offline routing anchors, corridor evidence and compact Analysis inputs.

All routes stay on ordinary-link topology. Sites are references, never transit nodes.
"""
from bisect import bisect_right
from collections import defaultdict
import hashlib
import heapq
import json
import math
from access import footprint, _boundary_parameters, _side, road_candidate

PREPROCESS_VERSION = 'strategic-access-1'
PREPROCESS_SETTINGS = {'bypassBandM': 500.0, 'anchorMergeToleranceM': 1e-7,
                       'anchorMetric': 'source-constrained-section-centre-3d',
                       'baselinePolicy': 'shortest-to-adjacent-attachment-nodes'}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def distance(a, b, dimensions=3):
    return math.sqrt(sum((a[i]-b[i])**2 for i in range(dimensions)))


def interpolate(a, b, t):
    return [a[i]+t*(b[i]-a[i]) for i in range(3)]


def project(p, a, b):
    v = [b[i]-a[i] for i in range(3)]
    length2 = sum(x*x for x in v)
    t = max(0, min(1, sum((p[i]-a[i])*v[i] for i in range(3))/length2)) if length2 else 0
    q = interpolate(a, b, t)
    return distance(p, q), t, q


def edge_point(edge, offset):
    offsets = edge['sourceOffsetsM']
    i = min(len(offsets)-2, max(0, bisect_right(offsets, offset)-1))
    t = (offset-offsets[i])/(offsets[i+1]-offsets[i]) if offsets[i+1] > offsets[i] else 0
    return interpolate(edge['geometryASL'][i], edge['geometryASL'][i+1], t)


def edge_geometry(edge, start, end):
    return [edge_point(edge, start)] + [p for p, d in zip(edge['geometryASL'], edge['sourceOffsetsM'])
                                      if start < d < end] + [edge_point(edge, end)]


def resolve_anchors(roads, graph, attachments, settings):
    roads = {r['id']: r for r in roads}
    edges = {e['id']: e for e in graph['edges']}
    anchors = []
    for a in attachments:
        sources = set(a['roadIds'])
        primary = roads[a['roadId']]
        p = a['positionASL']
        candidates = []
        # At an observed junction, use its retained vertex. Picking an arbitrary
        # incident edge would move the junction and change its branch choices.
        if len(sources) == 1 and primary.get('nodeId'):
            anchor = {'nodeId': primary['nodeId'], 'projectedPositionASL': primary['positionASL'],
                      'method': 'source-retained-node'}
        else:
            for eid in sorted({ref['edgeId'] for rid in sources for ref in roads[rid]['graphRefs']}):
                edge = edges[eid]
                for i, (ra, rb) in enumerate(zip(edge['roadIds'], edge['roadIds'][1:])):
                    if len(sources) > 1:
                        allowed = ra in sources and rb in sources
                    else:
                        allowed = ra in sources or rb in sources
                    if not allowed:
                        continue
                    error, t, q = project(p, edge['geometryASL'][i], edge['geometryASL'][i+1])
                    offset = edge['sourceOffsetsM'][i] + t*(edge['sourceOffsetsM'][i+1]-edge['sourceOffsetsM'][i])
                    candidates.append((error, eid, offset, q))
            if candidates:
                _, eid, offset, q = min(candidates)
                anchor = {'sourceEdgeId': eid, 'offsetM': offset, 'projectedPositionASL': q,
                          'method': 'projection-on-source-adjacent-ordinary-link'}
            else:
                # Isolated sections and coincident source centres have no usable
                # segment. Their measured connector remains a separate route cost.
                if 'nodeId' not in primary:
                    raise ValueError('Attachment has no topologically supported anchor: '+a['id'])
                anchor = {'nodeId': primary['nodeId'], 'projectedPositionASL': primary['positionASL'],
                          'method': 'source-retained-node'}
        anchor.update(attachmentId=a['id'], locationId=a['locationId'],
                      componentId=a['componentId'], sourceRoadIds=sorted(sources),
                      connectorLength3dM=distance(p, anchor['projectedPositionASL']),
                      projectionError2dM=distance(p, anchor['projectedPositionASL'], 2),
                      metric=settings['anchorMetric'], status='approximate-strategic-anchor')
        anchors.append(anchor)
    return anchors


def split_graph(roads, graph, anchors, settings):
    by_road = {r['id']: r for r in roads}
    by_edge = {e['id']: e for e in graph['edges']}
    evidence = {tuple(sorted((c['a'], c['b']))): c['evidence'] for c in graph['connections'] if c['accepted']}
    nodes = [dict(n) for n in graph['nodes']]
    anchors_by_edge = defaultdict(list)
    for a in anchors:
        if 'sourceEdgeId' in a:
            anchors_by_edge[a['sourceEdgeId']].append(a)
    result = []
    for eid, edge in sorted(by_edge.items()):
        length = edge['length3dM']
        cuts = [(0.0, edge['from'])]
        for a in sorted(anchors_by_edge[eid], key=lambda a: (a['offsetM'], a['attachmentId'])):
            offset = a['offsetM']
            if length-offset <= settings['anchorMergeToleranceM']:
                a['nodeId'] = edge['to']
            elif offset-cuts[-1][0] <= settings['anchorMergeToleranceM']:
                a['nodeId'] = cuts[-1][1]
            else:
                nid = 'split-'+eid+f'-{len(cuts):04d}'
                a['nodeId'] = nid
                cuts.append((offset, nid))
                nodes.append({'id': nid, 'componentId': edge['componentId'],
                              'positionASL': a['projectedPositionASL'], 'reasons': ['attachment-anchor']})
        cuts.append((length, edge['to']))
        for (start, u), (end, v) in zip(cuts, cuts[1:]):
            # Zero-length source links still carry real topology and must survive.
            geometry = edge_geometry(edge, start, end)
            indices = [i for i in range(len(edge['roadIds'])-1)
                       if edge['sourceOffsetsM'][i] < end and edge['sourceOffsetsM'][i+1] > start]
            if not indices:
                indices = list(range(len(edge['roadIds'])-1))
            source_ids = sorted({edge['roadIds'][j] for i in indices for j in [i, i+1]})
            members = [by_road[r] for r in source_ids]
            attrs = {'roadTypes': sorted({r['type'] for r in members}),
                     'minimumWidthM': min((r['widthM'] for r in members), default=None) if all('widthM' in r for r in members) else None,
                     'pedestrianPresent': any(r.get('pedestrian', False) for r in members),
                     'bridgeRoadIds': [r['id'] for r in members if r['bridge']],
                     'connectionEvidence': sorted({evidence[tuple(sorted(edge['roadIds'][i:i+2]))] for i in indices}),
                     'vehicleTraversal': 'unassessed'}
            result.append({'id': f'd{len(result):06d}', 'from': u, 'to': v,
                           'componentId': edge['componentId'], 'sourceEdgeId': eid,
                           'sourceStartOffsetM': start, 'sourceEndOffsetM': end,
                           'length3dM': end-start,
                           'length2dM': sum(distance(a, b, 2) for a, b in zip(geometry, geometry[1:])),
                           'geometryASL': geometry, 'attributes': attrs})
    return {'nodes': nodes, 'edges': result,
            'metric': settings['anchorMetric'], 'policy': 'Only original ordinary-link edges are split; attachments add no graph links.'}


def corridor_relations(graph, sites, anchors, settings):
    references = defaultdict(list)
    incident = defaultdict(list)
    for edge in graph['edges']:
        incident[edge['from']].append(edge['id'])
        incident[edge['to']].append(edge['id'])
    for a in anchors:
        for eid in [a['sourceEdgeId']] if 'sourceEdgeId' in a else incident[a['nodeId']]:
            references[a['locationId'], eid].append(a['attachmentId'])
    bounds = {e['id']: (min(p[0] for p in e['geometryASL']), min(p[1] for p in e['geometryASL']),
                        max(p[0] for p in e['geometryASL']), max(p[1] for p in e['geometryASL'])) for e in graph['edges']}
    result = []
    for site in sorted(sites, key=lambda s: s['id']):
        shape = footprint(site)
        radius = (shape[2][0] if shape[0] == 'circle' else math.hypot(*shape[2]))+settings['bypassBandM']
        cx, cy = shape[1][:2]
        for edge in graph['edges']:
            xmin, ymin, xmax, ymax = bounds[edge['id']]
            if xmax < cx-radius or xmin > cx+radius or ymax < cy-radius or ymin > cy+radius:
                continue
            intervals = []
            gap = math.inf
            for i, (a, b) in enumerate(zip(edge['geometryASL'], edge['geometryASL'][1:])):
                gap = min(gap, road_candidate(shape, {'beginASL': a, 'endASL': b})[0])
                roots = sorted(set([0.0, 1.0]+_boundary_parameters(shape, a, b)))
                base, end = edge['sourceOffsetsM'][i:i+2]
                for lo, hi in zip(roots, roots[1:]):
                    if _side(shape, interpolate(a, b, (lo+hi)/2)) != 1:
                        continue
                    start, finish = base+lo*(end-base), base+hi*(end-base)
                    if intervals and abs(intervals[-1][1]-start) < 1e-6:
                        intervals[-1][1] = finish
                    else:
                        intervals.append([start, finish])
            if gap > settings['bypassBandM']:
                continue
            if not intervals:
                relation = 'bypasses'
            elif any(lo > 1e-6 and hi < edge['length3dM']-1e-6 for lo, hi in intervals):
                relation = 'traverses'
            elif all(_side(shape, p) == 1 for p in [edge['geometryASL'][0], edge['geometryASL'][-1]]):
                relation = 'within'
            else:
                relation = 'enters'
            result.append({'locationId': site['id'], 'sourceEdgeId': edge['id'],
                           'componentId': edge['componentId'], 'relation': relation,
                           'insideIntervalsM': intervals, 'nearestFootprintGapM': gap,
                           'attachmentIds': sorted(references[site['id'], edge['id']]),
                           'evidence': 'section-centre-polyline-vs-saved-footprint',
                           'interpretation': 'geographic-only; route-utility-and-control-unassessed'})
    return result


def adjacency(graph):
    result = defaultdict(list)
    for e in graph['edges']:
        result[e['from']].append((e['to'], e['length3dM'], e['id'], 1))
        result[e['to']].append((e['from'], e['length3dM'], e['id'], -1))
    return result


def adjacent_connections(graph, anchors, attachments):
    """Sparse baseline: shortest paths to next attachment vertices on each branch.

    All graph junctions and alternatives are retained separately in the runtime
    adjacency. This table is not an exhaustive path catalogue or an objective graph
    on which objective IDs may be used as interchangeable/free transit vertices.
    """
    adj = adjacency(graph)
    edges = {e['id']: e for e in graph['edges']}
    access = {a['id']: a for a in attachments}
    at_node = defaultdict(list)
    for a in anchors:
        at_node[a['nodeId']].append(a)
    result = []
    for start in sorted(at_node):
        costs = {start: 0.0}
        parents = {}
        queue = [(0.0, start)]
        reached = []
        while queue:
            cost, at = heapq.heappop(queue)
            if cost != costs[at]:
                continue
            if at in at_node:
                reached.append(at)
                if at != start:
                    continue
            for nxt, length, eid, direction in adj[at]:
                value = cost+length
                if value < costs.get(nxt, math.inf):
                    costs[nxt] = value
                    parents[nxt] = (at, eid, direction)
                    heapq.heappush(queue, (value, nxt))
        for end in reached:
            if end < start:
                continue
            path = []
            at = end
            while at != start:
                prev, eid, direction = parents[at]
                path.append([eid, direction])
                at = prev
            path.reverse()
            attrs = [edges[eid]['attributes'] for eid, _ in path]
            for a in at_node[start]:
                for b in at_node[end]:
                    if start == end and a['attachmentId'] >= b['attachmentId']:
                        continue
                    aa, bb = access[a['attachmentId']], access[b['attachmentId']]
                    result.append({'fromAttachmentId': a['attachmentId'], 'toAttachmentId': b['attachmentId'],
                                   'fromLocationId': a['locationId'], 'toLocationId': b['locationId'],
                                   'fromNodeId': start, 'toNodeId': end, 'componentId': a['componentId'],
                                   'kind': 'same-site-network-path' if a['locationId'] == b['locationId'] else 'between-site-network-path',
                                   'roadDistanceM': costs[end],
                                   'anchorConnectorM': [a['connectorLength3dM'], b['connectorLength3dM']],
                                   'offRoadGapM': [aa['footprintGapM'], bb['footprintGapM']],
                                   'edgePath': path,
                                   'roadTypes': sorted({t for attr in attrs for t in attr['roadTypes']}),
                                   'bridgeRoadIds': sorted({r for attr in attrs for r in attr['bridgeRoadIds']}),
                                   'uncertainty': ['strategic-centreline-approximation', 'endpoint-approaches-unassessed', 'vehicle-traversal-unassessed']})
    result.sort(key=lambda c: (c['fromAttachmentId'], c['toAttachmentId']))
    for i, c in enumerate(result):
        c['id'] = f'connection-{i:06d}'
    return result


def accessibility_summary(roads, sites, attachments):
    by_road = {r['id']: r for r in roads}
    by_site = defaultdict(list)
    for a in attachments:
        by_site[a['locationId']].append(a)
    output = []
    for s in sorted(sites, key=lambda s: s['id']):
        entries = by_site[s['id']]
        gaps = [a['footprintGapM'] for a in entries]
        output.append({'locationId': s['id'], 'attachmentIds': [a['id'] for a in entries],
                       'inletCount': sum(a['kind'] == 'boundary-inlet' for a in entries),
                       'fallbackCount': sum(a['kind'] == 'nearby-road' for a in entries),
                       'roadTypes': sorted({by_road[a['roadId']]['type'] for a in entries}),
                       'componentIds': sorted({a['componentId'] for a in entries}),
                       'minimumOffRoadGapM': min(gaps, default=None),
                       'maximumOffRoadGapM': max(gaps, default=None),
                       'independentRouteCount': None, 'vehicleAccess': 'unassessed',
                       'coverage': 'candidates' if entries else 'none-within-automatic-search-limit',
                       'relevanceScore': None})
    return output


def runtime_package(graph, anchors, attachments, connections, relations, dependencies, accessibility):
    nodes = graph['nodes']
    edges = graph['edges']
    nindex = {n['id']: i for i, n in enumerate(nodes)}
    eindex = {e['id']: i for i, e in enumerate(edges)}
    locations = sorted({a['locationId'] for a in attachments} | {r['locationId'] for r in relations} | {s['locationId'] for s in accessibility})
    lindex = {loc: i for i, loc in enumerate(locations)}
    source_edges = sorted({e['sourceEdgeId'] for e in edges})
    sindex = {eid: i for i, eid in enumerate(source_edges)}
    components = sorted({n['componentId'] for n in nodes})
    cindex = {cid: i for i, cid in enumerate(components)}
    attrs = []
    attr_index = {}
    packed_edges = []
    adj = [[] for _ in nodes]
    for e in edges:
        key = digest(e['attributes'])
        if key not in attr_index:
            attr_index[key] = len(attrs)
            attrs.append(e['attributes'])
        u, v = nindex[e['from']], nindex[e['to']]
        i = len(packed_edges)
        packed_edges.append([u, v, e['length3dM'], e['length2dM'], attr_index[key], sindex[e['sourceEdgeId']], e['sourceStartOffsetM'], e['sourceEndOffsetM']])
        adj[u].append([v, i])
        adj[v].append([u, i])
    by_anchor = {a['attachmentId']: a for a in anchors}
    aindex = {a['id']: i for i, a in enumerate(attachments)}
    packed_access = []
    for a in attachments:
        anchor = by_anchor[a['id']]
        packed_access.append([a['id'], lindex[a['locationId']], nindex[anchor['nodeId']], a['kind'],
                              a.get('candidateTier'), a['footprintGapM'], anchor['connectorLength3dM']])
    return {'schemaVersion': 1, 'dependencies': dependencies,
            'schema': {'nodes': ['id', 'componentIndex'],
                       'edges': ['fromNode', 'toNode', 'road3dM', 'road2dM', 'attributeIndex', 'sourceEdgeIndex', 'startM', 'endM'],
                       'adjacency': '[node] -> [neighbourNode, edgeIndex][]',
                       'attachments': ['id', 'locationIndex', 'nodeIndex', 'kind', 'tier', 'offRoadGapM', 'anchorConnector3dM'],
                       'connections': ['fromAttachment', 'toAttachment', 'road3dM', 'orientedEdgePath'],
                       'corridors': ['locationIndex', 'sourceEdgeIndex', 'relation', 'gapM']},
            'metric': graph['metric'], 'policy': 'Attachments are endpoints only; locations never provide transit links. Off-road gaps remain unassessed.',
            'nodes': [[n['id'], cindex[n['componentId']]] for n in nodes],
            'edgeIds': [e['id'] for e in edges], 'edges': packed_edges, 'adjacency': adj, 'attributes': attrs,
            'accessibility': accessibility, 'attachments': packed_access, 'locations': locations, 'components': components, 'sourceEdgeIds': source_edges,
            'connections': [[aindex[c['fromAttachmentId']], aindex[c['toAttachmentId']], c['roadDistanceM'],
                             [[eindex[eid], direction] for eid, direction in c['edgePath']]] for c in connections],
            'corridors': [[lindex[r['locationId']], sindex[r['sourceEdgeId']], r['relation'], r['nearestFootprintGapM']] for r in relations]}


def preprocess(roads, graph, sites, attachments, dependencies, settings=None):
    settings = dict(PREPROCESS_SETTINGS if settings is None else settings)
    anchors = resolve_anchors(roads, graph, attachments, settings)
    routing = split_graph(roads, graph, anchors, settings)
    relations = corridor_relations(graph, sites, anchors, settings)
    connections = adjacent_connections(routing, anchors, attachments)
    accessibility = accessibility_summary(roads, sites, attachments)
    deps = dict(dependencies, preprocessingVersion=PREPROCESS_VERSION, settings=settings)
    payload = {'dependencies': deps, 'anchors': anchors, 'routingGraph': routing,
               'corridors': relations, 'objectiveConnections': connections, 'accessibility': accessibility}
    derived_id = digest(payload)
    deps = dict(deps, preprocessingDatasetId=derived_id)
    runtime = runtime_package(routing, anchors, attachments, connections, relations, deps, accessibility)
    return dict(payload, dependencies=deps, runtime=runtime, runtimeDatasetId=digest(runtime))
