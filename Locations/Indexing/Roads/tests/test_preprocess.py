"""Regression checks for approaches and offline routing preprocessing."""
import copy
import json
import math
from pathlib import Path
import random
import sys
import os
import unittest

ROOT = Path(__file__).resolve().parents[1]
DATA = Path(os.environ.get('IVCS_ROAD_OUTPUT', ROOT.parent/'output/altis/roads'))
VIEWER = Path(os.environ.get('IVCS_ROAD_VIEWER', DATA.parent/'viewer'))
sys.path.insert(0, str(ROOT))
import index as indexer
import access
import fallback
import preprocess as pp
from runtime_query import find_route


def fixture(centres, links, heights=None, bridges=()):
    raw = []
    for i, p in enumerate(centres):
        x, y = p
        z = heights[i] if heights else 10
        raw.append([i, str(i), [x, y, z], ['ROAD', 8, False, '', '', '',
                   [x-10, y, z], [x+10, y, z], i in bridges, 0],
                   [b if a == i else a for a, b in links if i in [a, b]], []])
    roads = indexer.normalize(raw)
    graph = indexer.network(roads)
    lookup = {int(r['sourceRef']): r for r in roads}
    return roads, graph, lookup


def site(name='site', position=(0, 0), radius=10):
    return {'id': name, 'position': list(position)+[0], 'size': radius,
            'footprint': ['circle', list(position)+[0], [radius, radius], 0]}


def attachment(name, location, road, position=None, gap=0):
    return {'id': name, 'locationId': location, 'roadId': road['id'], 'roadIds': [road['id']],
            'componentId': road['componentId'], 'positionASL': position or road['positionASL'],
            'kind': 'nearby-road' if gap else 'boundary-inlet', 'footprintGapM': gap}


def pipeline(roads, graph, attachments, sites=None, settings=None):
    return pp.preprocess(roads, graph, sites or [], attachments,
                         {'roadDatasetId': 'r', 'locationDatasetId': 'l', 'attachmentDatasetId': 'a'}, settings)


class FallbackFixtures(unittest.TestCase):
    def test_thresholds_and_secondary_retention(self):
        roads, graph, _ = fixture([(0, 160), (0, 160.01), (0, 510), (0, 510.01)], [])
        s = site()
        inlets, coverage = access.attachments(roads, [s], graph['connections'])
        output, coverage = fallback.add_fallbacks(roads, graph, [s], inlets, coverage)
        self.assertEqual(len(output), 3)
        tiers = {round(a['footprintGapM'], 2): a['candidateTier'] for a in output}
        self.assertEqual(tiers, {150: 'strong', 150.01: 'secondary', 500: 'secondary'})
        for a in output:
            self.assertEqual(len(a['footprintApproach2D']), 2)
            self.assertIsNone(a['approachPathLengthM'])
            self.assertEqual(a['approachHeightStatus'], 'unmeasured')
            self.assertIn('water', a['unchecked'])

    def test_distance_is_from_rectangle_not_centre(self):
        roads, graph, _ = fixture([(1000, 50)], [])
        s = site()
        s['footprint'] = ['rectangle', [0, 0, 0], [1000, 10], 0]
        a, c = access.attachments(roads, [s], graph['connections'])
        a, _ = fallback.add_fallbacks(roads, graph, [s], a, c)
        self.assertAlmostEqual(a[0]['footprintGapM'], 40)

    def test_parallel_flat_corridor_is_one_approach_not_repeated_samples(self):
        roads, graph, _ = fixture([(x, 50) for x in range(-300, 301, 100)], [(i, i+1) for i in range(6)])
        s = site(radius=1000)
        s['footprint'] = ['rectangle', [0, 0, 0], [1000, 10], 0]
        a, c = access.attachments(roads, [s], graph['connections'])
        a, _ = fallback.add_fallbacks(roads, graph, [s], a, c)
        self.assertEqual(len(a), 1)
        self.assertEqual(a[0]['footprintGapM'], 40)

    def test_internal_road_is_zero_gap_fallback_not_inlet(self):
        roads, graph, _ = fixture([(0, 0)], [])
        s = site(radius=100)
        a, c = access.attachments(roads, [s], graph['connections'])
        a, _ = fallback.add_fallbacks(roads, graph, [s], a, c)
        self.assertEqual(a[0]['kind'], 'nearby-road')
        self.assertEqual(a[0]['footprintGapM'], 0)
        self.assertIn('vertical-access', a[0]['unchecked'])

    def test_real_boundary_inlets_do_not_get_fallbacks(self):
        roads, graph, _ = fixture([(10, 0), (100, 0)], [(0, 1)])
        s = site(radius=15)
        a, c = access.attachments(roads, [s], graph['connections'])
        output, _ = fallback.add_fallbacks(roads, graph, [s], a, c)
        self.assertEqual(output, a)
        self.assertGreater(len(a), 0)

    def test_custom_band_and_no_candidates_does_not_mean_unreachable(self):
        roads, graph, _ = fixture([(0, 600)], [])
        s = site()
        a, c = access.attachments(roads, [s], graph['connections'])
        output, report = fallback.add_fallbacks(roads, graph, [s], a, c)
        self.assertEqual(output, [])
        self.assertEqual(report[0]['fallbackStatus'], 'none-within-search-limit')
        output, _ = fallback.add_fallbacks(roads, graph, [s], a, c,
                                          dict(fallback.FALLBACK_SETTINGS, maximumGapM=600))
        self.assertEqual(len(output), 1)


class RoutingFixtures(unittest.TestCase):
    def test_same_edge_exact_offset_distance_and_connector_separation(self):
        roads, graph, r = fixture([(0, 0), (100, 0), (200, 0), (300, 0)], [(0, 1), (1, 2), (2, 3)])
        a = [attachment('a', 'A', r[1], [130, 0, 10], 20),
             attachment('b', 'B', r[2], [170, 3, 10], 30)]
        d = pipeline(roads, graph, a)
        route = find_route(d['runtime'], 'a', 'b')
        self.assertAlmostEqual(route['roadDistanceM'], 40)
        self.assertEqual(route['offRoadGapM'], [20, 30])
        self.assertEqual(route['anchorConnectorM'], [0, 3])
        self.assertAlmostEqual(route['policyCost'], 93)

    def test_junction_retains_all_branches(self):
        roads, graph, r = fixture([(0, 0), (100, 0), (200, 0), (100, 100)], [(0, 1), (1, 2), (1, 3)])
        a = [attachment(str(i), str(i), r[i]) for i in range(4)]
        d = pipeline(roads, graph, a)
        self.assertEqual(d['anchors'][1]['nodeId'], r[1]['nodeId'])
        for target in ['0', '2', '3']:
            self.assertAlmostEqual(find_route(d['runtime'], '1', target)['roadDistanceM'], 100)

    def test_overpasses_and_nearby_sources_never_project_to_other_network(self):
        roads, graph, r = fixture([(0, 0), (100, 0), (200, 0), (0, 0), (100, 0), (200, 0)],
                                 [(0, 1), (1, 2), (3, 4), (4, 5)], heights=[10, 10, 10, 30, 30, 30])
        a = [attachment('a', 'A', r[1], [110, 0, 29]), attachment('b', 'B', r[4])]
        d = pipeline(roads, graph, a)
        self.assertEqual(d['anchors'][0]['projectedPositionASL'][2], 10)
        self.assertEqual(find_route(d['runtime'], 'a', 'b')['status'], 'disconnected-road-networks')

    def test_ordinary_interpolation_uses_the_source_link(self):
        roads, graph, r = fixture([(0, 0), (100, 0), (200, 0)], [(0, 1), (1, 2)])
        a = attachment('a', 'A', r[1], [140, 0, 10])
        a['roadIds'] = [r[1]['id'], r[2]['id']]
        d = pipeline(roads, graph, [a])
        self.assertAlmostEqual(d['anchors'][0]['offsetM'], 140)
        self.assertAlmostEqual(d['anchors'][0]['connectorLength3dM'], 0)

    def test_site_cannot_connect_disconnected_inlets_or_fallbacks(self):
        roads, graph, r = fixture([(0, 0), (100, 0), (0, 50), (100, 50)], [(0, 1), (2, 3)])
        a = [attachment('a', 'shared-site', r[0], gap=20), attachment('b', 'shared-site', r[2], gap=30),
             attachment('c', 'remote', r[3])]
        d = pipeline(roads, graph, a)
        self.assertEqual(find_route(d['runtime'], 'a', 'c')['status'], 'disconnected-road-networks')
        self.assertFalse(any(c['fromAttachmentId'] == 'a' and c['toAttachmentId'] in ['b', 'c'] for c in d['objectiveConnections']))

    def test_same_site_external_detour_keeps_full_cost(self):
        roads, graph, r = fixture([(0, 0), (0, 100), (100, 100), (100, 0)], [(0, 1), (1, 2), (2, 3)])
        a = [attachment('a', 'same', r[0]), attachment('b', 'same', r[3])]
        d = pipeline(roads, graph, a)
        self.assertAlmostEqual(find_route(d['runtime'], 'a', 'b')['roadDistanceM'], 300)
        self.assertAlmostEqual(d['objectiveConnections'][0]['roadDistanceM'], 300)

    def test_airport_town_route_and_bridge_closure_keep_bypass(self):
        roads, graph, r = fixture([(0, 0), (100, 0), (200, 0), (100, 100)],
                                 [(0, 1), (1, 2), (0, 3), (3, 2)], bridges=[1])
        a = [attachment('airport', 'airport', r[0]), attachment('destination', 'destination', r[2])]
        d = pipeline(roads, graph, a, [site('town', (100, 0), 25)])
        normal = find_route(d['runtime'], 'airport', 'destination')
        closed = find_route(d['runtime'], 'airport', 'destination', blocked_bridge_roads=[r[1]['id']])
        self.assertEqual(closed['status'], 'found')
        self.assertGreater(closed['roadDistanceM'], normal['roadDistanceM'])
        self.assertTrue(any(c['relation'] == 'bypasses' for c in d['corridors']))
        self.assertTrue(any(c['relation'] in ['enters', 'traverses'] for c in d['corridors']))

    def test_runtime_policy_changes_cost_not_measurements_and_search_is_bounded(self):
        roads, graph, r = fixture([(0, 0), (100, 0), (200, 0)], [(0, 1), (1, 2)])
        d = pipeline(roads, graph, [attachment('a', 'a', r[0]), attachment('b', 'b', r[2])])
        original = copy.deepcopy(d['runtime'])
        normal = find_route(original, 'a', 'b')
        weighted = find_route(original, 'a', 'b', road_type_weights={'ROAD': 2})
        self.assertEqual(normal['roadDistanceM'], weighted['roadDistanceM'])
        self.assertAlmostEqual(weighted['policyCost'], 2*normal['policyCost'])
        self.assertEqual(original, d['runtime'])
        self.assertEqual(find_route(original, 'a', 'b', maximum_nodes=1)['status'], 'search-limit')

    def test_preprocessing_settings_invalidate_only_derived_identity(self):
        roads, graph, r = fixture([(0, 0), (100, 0)], [(0, 1)])
        a = [attachment('a', 'a', r[0])]
        first = pipeline(roads, graph, a)
        second = pipeline(roads, graph, a, settings=dict(pp.PREPROCESS_SETTINGS, bypassBandM=400))
        self.assertNotEqual(first['dependencies']['preprocessingDatasetId'], second['dependencies']['preprocessingDatasetId'])
        for key in ['roadDatasetId', 'locationDatasetId', 'attachmentDatasetId']:
            self.assertEqual(first['dependencies'][key], second['dependencies'][key])

    def test_zero_length_ordinary_link_still_connects(self):
        roads, graph, r = fixture([(0, 0), (0, 0)], [(0, 1)])
        d = pipeline(roads, graph, [attachment('a', 'a', r[0]), attachment('b', 'b', r[1])])
        self.assertEqual(find_route(d['runtime'], 'a', 'b')['status'], 'found')


class SavedPreprocessing(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        p = DATA
        cls.load = staticmethod(lambda name: json.loads((p/(name+'.json')).read_text()))
        cls.runtime = cls.load('runtime')
        cls.routing = cls.load('routing-graph')
        cls.anchors = cls.load('routing-anchors')
        cls.connections = cls.load('objective-connections')
        cls.attachments = cls.load('attachments')
        cls.manifest = cls.load('manifest')

    def test_boundary_crossings_for_unchanged_locations_preserved(self):
        baseline = ROOT.parent/'baseline/containment-before/roads'
        old = json.loads((baseline/'attachments.json').read_text(encoding='utf-8'))
        before_sites = {s['id']:s for s in json.loads((baseline/'locations.json').read_text(encoding='utf-8'))}
        current_sites = {s['id']:s for s in self.load('locations')}
        unchanged = {sid for sid,s in before_sites.items() if sid in current_sites and
                     all(s.get(k)==current_sites[sid].get(k) for k in ['footprint','position','size'])}
        self.assertGreater(len(unchanged),200)
        old = [a for a in old if a['locationId'] in unchanged and a['kind']=='boundary-inlet']
        fields = ['id', 'locationId', 'roadIds', 'positionASL', 'insideASL', 'outsideASL', 'sources']
        before = [{k: a[k] for k in fields} for a in old]
        after = [{k: a[k] for k in fields} for a in self.attachments if a['kind'] == 'boundary-inlet' and a['locationId'] in unchanged]
        self.assertEqual(before, after)

    def test_dorida_power_has_strong_and_secondary_fallbacks(self):
        a = [a for a in self.attachments if a['locationId'] == 'altis_power_1145']
        self.assertEqual({x['candidateTier'] for x in a}, {'strong', 'secondary'})
        self.assertAlmostEqual(min(x['footprintGapM'] for x in a), 36.204285, places=5)
        self.assertTrue(all(x['kind'] == 'nearby-road' for x in a))

    def test_split_graph_preserves_each_source_distance(self):
        original = {e['id']: e for e in self.load('graph')['edges']}
        groups = {}
        for e in self.routing['edges']:
            groups.setdefault(e['sourceEdgeId'], []).append(e)
        for eid, segments in groups.items():
            self.assertAlmostEqual(sum(e['length3dM'] for e in segments), original[eid]['length3dM'], places=7)
            self.assertAlmostEqual(sum(e['length2dM'] for e in segments), original[eid]['length2dM'], places=7)
        self.assertEqual(set(groups), set(original))

    def test_all_baseline_routes_reconstruct_without_objective_shortcuts(self):
        edges = {e['id']: e for e in self.routing['edges']}
        anchors = {a['attachmentId']: a for a in self.anchors}
        attachments = {a['id']: a for a in self.attachments}
        for c in self.connections:
            a, b = anchors[c['fromAttachmentId']], anchors[c['toAttachmentId']]
            at, total = a['nodeId'], 0
            for eid, direction in c['edgePath']:
                e = edges[eid]
                self.assertEqual(at, e['from'] if direction == 1 else e['to'])
                at = e['to'] if direction == 1 else e['from']
                total += e['length3dM']
            self.assertEqual(at, b['nodeId'])
            self.assertEqual(a['componentId'], b['componentId'])
            self.assertAlmostEqual(total, c['roadDistanceM'], places=7)
            self.assertEqual(c['offRoadGapM'], [attachments[c['fromAttachmentId']]['footprintGapM'], attachments[c['toAttachmentId']]['footprintGapM']])

    def test_runtime_keeps_sites_without_automatic_access(self):
        self.assertEqual(len(self.runtime['locations']), len(self.load('locations')))
        absent = [s for s in self.runtime['accessibility'] if not s['attachmentIds']]
        self.assertEqual(len(absent), 4)
        for s in absent:
            self.assertIsNone(s['minimumOffRoadGapM'])
            self.assertEqual(s['vehicleAccess'], 'unassessed')
            self.assertIsNone(s['relevanceScore'])

    def test_runtime_references_and_compact_size(self):
        p = self.runtime
        for i, neighbours in enumerate(p['adjacency']):
            for other, eid in neighbours:
                e = p['edges'][eid]
                self.assertIn([i, other], [e[:2], e[:2][::-1]])
                self.assertEqual(p['nodes'][i][1], p['nodes'][other][1])
        for a in p['attachments']:
            self.assertLess(a[1], len(p['locations']))
            self.assertLess(a[2], len(p['nodes']))
        core = {k:v for k,v in p.items() if k != 'connections'}
        self.assertLess(len(json.dumps(core,separators=(',',':'))), (DATA/'graph.json').stat().st_size/4)
        self.assertLess((DATA/'runtime.json').stat().st_size, (DATA/'graph.json').stat().st_size)
        self.assertEqual(pp.digest(p), self.manifest['runtimeDatasetId'])

    def test_anchor_provenance_resolves_and_never_changes_components(self):
        nodes = {n['id']: n for n in self.routing['nodes']}
        roads = {r['id']: r for r in self.load('roads')}
        original = {e['id']: e for e in self.load('graph')['edges']}
        for a in self.anchors:
            self.assertEqual(nodes[a['nodeId']]['componentId'], a['componentId'])
            self.assertTrue(all(roads[rid]['componentId'] == a['componentId'] for rid in a['sourceRoadIds']))
            if 'sourceEdgeId' in a:
                edge = original[a['sourceEdgeId']]
                self.assertGreaterEqual(a['offsetM'], 0)
                self.assertLessEqual(a['offsetM'], edge['length3dM'])
                self.assertTrue(set(a['sourceRoadIds']).intersection(edge['roadIds']))

    def test_saved_routes_match_compact_search_for_sampled_adjacent_pairs(self):
        # The baseline stops at intermediate attachment vertices; within its
        # corridor the saved path must match the complete compact graph distance.
        for c in random.Random(42).sample(self.connections, 20):
            r = find_route(self.runtime, c['fromAttachmentId'], c['toAttachmentId'])
            self.assertEqual(r['status'], 'found')
            self.assertLessEqual(r['roadDistanceM'], c['roadDistanceM']+1e-7)


if __name__ == '__main__':
    unittest.main(verbosity=2)
