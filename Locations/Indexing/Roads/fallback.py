"""Nearby-road approaches for footprints with no geometric boundary inlets."""
from collections import defaultdict
import math
from access import footprint, road_candidate

FALLBACK_VERSION = 'nearby-approaches-1'
FALLBACK_SETTINGS = {'strongGapM': 150.0, 'maximumGapM': 500.0,
                     'distinctAlongCorridorM': 150.0}
UNCHECKED = ['water', 'slope', 'fences', 'entrances', 'vehicle-traversal', 'vertical-access']


def add_fallbacks(roads, graph, sites, inlets, coverage, settings=None):
    """Retain local closest approaches on each corridor/tier run, without sector quotas.

    A component is connectivity evidence, never an approach identity. Runs split at
    junctions, class changes, distance tiers and missing candidates. Separated local
    minima also survive on a curved corridor. These are unassessed straight gaps.
    """
    settings = dict(FALLBACK_SETTINGS if settings is None else settings)
    if not 0 <= settings['strongGapM'] <= settings['maximumGapM']:
        raise ValueError('Invalid fallback distance tiers')
    valid = {r['id']: r for r in roads if r['geometryStatus'] != 'unavailable'}
    buckets = defaultdict(set)
    for rid, r in valid.items():
        a, b = r['beginASL'], r['endASL']
        for x in range(math.floor(min(a[0], b[0])/500), math.floor(max(a[0], b[0])/500)+1):
            for y in range(math.floor(min(a[1], b[1])/500), math.floor(max(a[1], b[1])/500)+1):
                buckets[x, y].add(rid)
    edge_map = {e['id']: e for e in graph['edges']}
    counts = {c['locationId']: dict(c, fallbackCount=0, strongFallbacks=0, secondaryFallbacks=0)
              for c in coverage}
    result = list(inlets)
    for site in sorted(sites, key=lambda s: s['id']):
        report = counts[site['id']]
        if report['inletCount']:
            continue
        shape = footprint(site)
        radius = (shape[2][0] if shape[0] == 'circle' else math.hypot(*shape[2])) + settings['maximumGapM']
        cx, cy = shape[1][:2]
        possible = set()
        for x in range(math.floor((cx-radius)/500), math.floor((cx+radius)/500)+1):
            for y in range(math.floor((cy-radius)/500), math.floor((cy+radius)/500)+1):
                possible.update(buckets[x, y])
        candidates = {}
        for rid in sorted(possible):
            gap, _, departure, target = road_candidate(shape, valid[rid])
            if gap <= settings['maximumGapM']:
                candidates[rid] = {'gap': gap, 'position': departure, 'target': target,
                                   'tier': 'strong' if gap <= settings['strongGapM'] else 'secondary'}
        selected = defaultdict(set)
        edges = sorted({ref['edgeId'] for rid in candidates for ref in valid[rid]['graphRefs']})

        def choose(run, eid):
            if not run:
                return
            best = min(run, key=lambda row: (candidates[row[0]]['gap'], row[0]))
            retained = [best]
            # A flat distance plateau is one closest approach, not a sequence
            # of independent minima sampled at arbitrary section intervals.
            plateaus = []
            for row in run:
                if plateaus and abs(candidates[row[0]]['gap']-candidates[plateaus[-1][0][0]]['gap']) <= 1e-6:
                    plateaus[-1].append(row)
                else:
                    plateaus.append([row])
            minima = []
            for i, plateau in enumerate(plateaus):
                row = min(plateau, key=lambda r: (candidates[r[0]]['gap'], r[0]))
                gap = candidates[row[0]]['gap']
                if (i == 0 or gap < candidates[plateaus[i-1][0][0]]['gap']) and (i == len(plateaus)-1 or gap < candidates[plateaus[i+1][0][0]]['gap']):
                    minima.append(row)
            for row in sorted(minima, key=lambda row: (candidates[row[0]]['gap'], row[0])):
                if all(abs(row[1]-other[1]) >= settings['distinctAlongCorridorM'] for other in retained):
                    retained.append(row)
            for rid, _ in retained:
                selected[rid].add(eid)

        for eid in edges:
            edge = edge_map[eid]
            run = []
            tier = None
            for rid, offset in zip(edge['roadIds'], edge['sourceOffsetsM']):
                candidate = candidates.get(rid)
                next_tier = candidate['tier'] if candidate else None
                if next_tier != tier or not candidate:
                    choose(run, eid)
                    run = []
                if candidate:
                    run.append((rid, offset))
                tier = next_tier
            choose(run, eid)
        for rid in candidates:
            if not valid[rid]['graphRefs']:
                selected[rid]  # isolated ordinary-link network
        additions = []
        for rid in sorted(selected):
            r, c = valid[rid], candidates[rid]
            pos = c['position']
            additions.append({'locationId': site['id'], 'roadId': rid, 'roadIds': [rid],
                              'componentId': r['componentId'], 'positionASL': pos,
                              'footprintApproach2D': c['target'][:2], 'footprintGapM': c['gap'],
                              'straightLineDistanceM': c['gap'], 'approachPathLengthM': None,
                              'approachHeightStatus': 'unmeasured', 'candidateTier': c['tier'],
                              'kind': 'nearby-road', 'status': 'candidate',
                              'bearingDegrees': math.degrees(math.atan2(pos[0]-cx, pos[1]-cy)) % 360,
                              'graphRefs': [dict(ref, roadId=rid) for ref in r['graphRefs']],
                              'approachCorridorIds': sorted(selected[rid]),
                              'evidence': ['nearest-chord-to-footprint', 'no-boundary-inlet'],
                              'unchecked': list(UNCHECKED), 'method': FALLBACK_VERSION})
        additions.sort(key=lambda a: (a['bearingDegrees'], a['footprintGapM'], a['roadId']))
        for i, a in enumerate(additions, 1):
            a.update(id=site['id']+f'-nearby-{i:03d}', number=i)
        result.extend(additions)
        report.update(fallbackCount=len(additions), candidateCount=len(additions),
                      strongFallbacks=sum(a['candidateTier'] == 'strong' for a in additions),
                      secondaryFallbacks=sum(a['candidateTier'] == 'secondary' for a in additions),
                      nearbySectionsWithinFallbackBand=len(candidates),
                      nearestRoadGapM=min((c['gap'] for c in candidates.values()), default=None),
                      fallbackStatus='unassessed-approaches' if additions else 'none-within-search-limit',
                      automaticFallbackLimitM=settings['maximumGapM'])
    return result, [counts[k] for k in sorted(counts)]
