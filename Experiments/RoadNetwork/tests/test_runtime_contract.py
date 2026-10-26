"""Runtime schema 2: precise traversed overlap and execution-ready coordinate lookup."""
import copy
import json
import math
from collections import defaultdict
from pathlib import Path
import random
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import preprocess as pp
from runtime_query import find_route, route_geography, attachment_details, candidate_indices
from test_preprocess import fixture, site, attachment, pipeline


def outside_then_town(cut=500):
    roads, graph, r = fixture([(0, 0), (300, 0), (600, 0), (900, 0), (1200, 0)],
                             [(0, 1), (1, 2), (2, 3), (3, 4)])
    road = r[1] if cut <= 600 else r[3]
    a = [attachment('start', 'start-site', r[0]),
         attachment('outside', 'outside-site', road, [cut, 0, 10]),
         attachment('finish', 'finish-site', r[4])]
    return pipeline(roads, graph, a, [site('town', (1000, 0), 100)])


class RuntimeGeographyFixtures(unittest.TestCase):
    def test_outside_part_does_not_inherit_town_elsewhere_on_source_edge(self):
        d = outside_then_town()
        self.assertEqual(len(d['corridors']), 1)
        self.assertTrue(d['corridors'][0]['insideIntervalsM'])
        route = find_route(d['runtime'], 'start', 'outside')
        self.assertEqual(route['geography']['overlappingLocations'], [])
        nearby = route['geography']['nearbyOutsideLocations']
        self.assertEqual([r['locationId'] for r in nearby], ['town'])
        self.assertAlmostEqual(nearby[0]['nearestGapM'], 400)
        self.assertAlmostEqual(route['roadDistanceM'], 500)

    def test_positive_overlap_uses_local_split_offsets_and_full_route_offsets(self):
        d = outside_then_town()
        p = d['runtime']
        actual = [r for r in p['corridors'] if r[4]]
        self.assertEqual(len(actual), 1)
        self.assertEqual(actual[0][4], [[400.0, 600.0]])
        route = find_route(p, 'start', 'finish')
        overlap = route['geography']['overlappingLocations']
        self.assertEqual(len(overlap), 1)
        self.assertEqual(overlap[0]['locationId'], 'town')
        self.assertAlmostEqual(overlap[0]['insideDistanceM'], 200)
        self.assertEqual(overlap[0]['routeIntervalsM'], [[900.0, 1100.0]])

    def test_reverse_route_orients_interior_intervals_along_travel(self):
        p = outside_then_town()['runtime']
        forward = find_route(p, 'start', 'finish')
        reverse = find_route(p, 'finish', 'start')
        self.assertEqual(reverse['geography']['overlappingLocations'][0]['routeIntervalsM'], [[100.0, 300.0]])
        self.assertEqual(forward['roadDistanceM'], reverse['roadDistanceM'])

    def test_boundary_contact_alone_does_not_count_as_interior(self):
        p = outside_then_town(900)['runtime']
        route = find_route(p, 'start', 'outside')
        self.assertEqual(route['geography']['overlappingLocations'], [])
        self.assertAlmostEqual(route['geography']['nearbyOutsideLocations'][0]['nearestGapM'], 0)
        positive = find_route(p, 'outside', 'finish')
        self.assertAlmostEqual(positive['geography']['overlappingLocations'][0]['insideDistanceM'], 200)

    def test_disjoint_source_intervals_are_clipped_without_filling_the_gap(self):
        graph = {'edges': [{'id': 'd', 'from': 'a', 'to': 'b', 'componentId': 'c',
                           'sourceEdgeId': 'e', 'sourceStartOffsetM': 100, 'sourceEndOffsetM': 300,
                           'length3dM': 200, 'geometryASL': [[100, 0, 10], [300, 0, 10]]}]}
        source = [{'locationId': 'town', 'sourceEdgeId': 'e', 'insideIntervalsM': [[0, 120], [200, 230], [350, 400]], 'attachmentIds': []}]
        result = pp.split_corridor_relations(graph, source, [site('town')], [], pp.PREPROCESS_SETTINGS)
        self.assertEqual(result[0]['insideIntervalsM'], [[0, 20], [100, 130]])
        self.assertEqual(result[0]['insideLengthM'], 50)

    def test_outside_piece_beyond_band_is_omitted_even_if_source_enters(self):
        p = outside_then_town(300)['runtime']
        route = find_route(p, 'start', 'outside')
        self.assertEqual(route['geography']['overlappingLocations'], [])
        self.assertEqual(route['geography']['nearbyOutsideLocations'], [])

    def test_runtime_schema_one_is_rejected_instead_of_misreading_source_indices(self):
        p = outside_then_town()['runtime']
        p['schemaVersion'] = 1
        with self.assertRaisesRegex(ValueError, 'schema 2'):
            find_route(p, 'start', 'finish')

    def test_route_geography_rejects_disconnected_edge_walk(self):
        p = outside_then_town()['runtime']
        with self.assertRaisesRegex(ValueError, 'contiguous'):
            route_geography(p, [[0, 1], [0, 1]])


class SavedRuntimeContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = ROOT/'output/altis'
        cls.load = staticmethod(lambda name: json.loads((root/(name+'.json')).read_text()))
        cls.p = cls.load('runtime')
        cls.routing = cls.load('routing-graph')
        cls.source_relations = cls.load('corridors')
        cls.relations = cls.load('routing-corridors')
        cls.attachments = cls.load('attachments')
        cls.anchors = cls.load('routing-anchors')
        cls.manifest = cls.load('manifest')
        cls.previous = json.loads((ROOT/'baseline/nonstopping-fallbacks-before/output/altis/runtime.json').read_text())
        cls.old = json.loads((ROOT/'baseline/runtime-v1/output/altis/runtime.json').read_text())
        cls.by_source = defaultdict(list)
        for r in cls.source_relations:
            cls.by_source[r['sourceEdgeId']].append(r)

    def test_all_runtime_intervals_equal_clipped_authoring_intervals(self):
        packed = {(self.p['locations'][r[0]], self.p['edgeIds'][r[1]]): r for r in self.p['corridors']}
        authored = {(r['locationId'], r['routingEdgeId']): r for r in self.relations}
        self.assertEqual(len(packed), len(self.p['corridors']))
        self.assertEqual(set(packed), set(authored))
        legacy_false_joins = 0
        for edge in self.routing['edges']:
            for source in self.by_source[edge['sourceEdgeId']]:
                start, end = edge['sourceStartOffsetM'], edge['sourceEndOffsetM']
                intervals = [[max(lo, start)-start, min(hi, end)-start]
                             for lo, hi in source['insideIntervalsM'] if max(lo, start) < min(hi, end)]
                r = packed.get((source['locationId'], edge['id']))
                if intervals:
                    self.assertIsNotNone(r)
                if r is not None:
                    self.assertEqual(r[4], intervals)
                    self.assertEqual(r[4], authored[source['locationId'], edge['id']]['insideIntervalsM'])
                    self.assertEqual(r[2], authored[source['locationId'], edge['id']]['relation'])
                    self.assertEqual(r[3], authored[source['locationId'], edge['id']]['nearestFootprintGapM'])
                    self.assertEqual(r[2] == 'bypasses', not bool(intervals))
                    for lo, hi in intervals:
                        self.assertGreaterEqual(lo, 0)
                        self.assertLess(lo, hi)
                        self.assertLessEqual(hi, edge['length3dM'])
                if source['insideIntervalsM'] and not intervals:
                    legacy_false_joins += 1
                    self.assertFalse(r and r[4])
        self.assertGreater(legacy_false_joins, 0)

    def test_saved_town_267_example_is_outside_on_d000000(self):
        eid = self.previous['edgeIds'].index('d000000')
        rows = [self.previous['corridors'][i] for i in self.previous['corridorsByEdge'][eid]
                if self.previous['locations'][self.previous['corridors'][i][0]] == 'altis_town_267']
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0][2], 'bypasses')
        self.assertEqual(rows[0][4], [])
        self.assertAlmostEqual(rows[0][3], 84.98792620625669)
        self.assertFalse(any(r['locationId'] == 'altis_town_267' for r in route_geography(self.previous, [[eid, 1]])['overlappingLocations']))
        later = [r for r in self.previous['corridors'] if self.previous['locations'][r[0]] == 'altis_town_267' and r[4]
                 and self.previous['edges'][r[1]][5] == self.previous['edges'][eid][5]]
        self.assertTrue(later)
        self.assertAlmostEqual(sum(hi-lo for r in later for lo, hi in r[4]), 1264.1076106163234-986.5651001058327, places=7)

    def test_edge_lookup_reaches_each_relationship_exactly_once(self):
        found = []
        self.assertEqual(len(self.p['corridorsByEdge']), len(self.p['edges']))
        for eid, indices in enumerate(self.p['corridorsByEdge']):
            for i in indices:
                self.assertEqual(self.p['corridors'][i][1], eid)
                found.append(i)
        self.assertEqual(sorted(found), list(range(len(self.p['corridors']))))

    def test_compact_coordinates_match_authoring_without_zero_height_assumptions(self):
        source = {a['id']: a for a in self.attachments}
        anchors = {a['attachmentId']: a for a in self.anchors}
        self.assertEqual(len(self.p['attachmentGeometry']), len(self.p['attachments']))
        for i, a in enumerate(self.p['attachments']):
            record = attachment_details(self.p, a[0])
            original, anchor = source[a[0]], anchors[a[0]]
            self.assertEqual(self.p['attachmentIndexById'][a[0]], i)
            self.assertEqual(record['roadDepartureASL'], original['positionASL'])
            self.assertEqual(record['projectedAnchorASL'], anchor['projectedPositionASL'])
            self.assertEqual(record['footprintApproach2D'], original['footprintApproach2D'])
            self.assertEqual(len(record['footprintApproach2D']), 2)
            self.assertEqual(record['footprintApproachHeightStatus'], 'unmeasured')
            self.assertEqual(record['vehicleTraversalStatus'], 'unassessed')
            self.assertEqual(record['offRoadGapM'], original['footprintGapM'])
            self.assertEqual(record['anchorConnectorM'], anchor['connectorLength3dM'])

    def test_candidate_lookup_retains_every_alternative_and_returns_empty_sites(self):
        by_location = defaultdict(set)
        for i, a in enumerate(self.p['attachments']):
            by_location[a[1]].add(i)
        seen = []
        for loc, name in enumerate(self.p['locations']):
            self.assertEqual(self.p['locationIndexById'][name], loc)
            indices = candidate_indices(self.p, name)
            self.assertEqual(set(indices), by_location[loc])
            self.assertEqual(indices, sorted(indices, key=lambda i: (self.p['attachments'][i][5], self.p['attachments'][i][6], self.p['attachments'][i][0])))
            seen.extend(indices)
        self.assertEqual(sorted(seen), list(range(len(self.p['attachments']))))
        self.assertEqual(max(map(len, self.p['attachmentsByLocation'])), 76)
        self.assertEqual(sum(not x for x in self.p['attachmentsByLocation']), 4)

    def test_optional_shortlist_does_not_discard_exported_candidates(self):
        before = pp.digest(self.p)
        all_candidates = candidate_indices(self.p, 'altis_power_1145')
        strong = candidate_indices(self.p, 'altis_power_1145', kind='nearby-road', tier='strong', maximum_gap_m=150, limit=1)
        self.assertEqual(len(strong), 1)
        self.assertLess(self.p['attachments'][strong[0]][5], 37)
        self.assertLess(len(strong), len(all_candidates))
        self.assertEqual(candidate_indices(self.p, 'altis_power_1145'), all_candidates)
        record = attachment_details(self.p, self.p['attachments'][strong[0]][0])
        record['roadDepartureASL'][0] = -1
        self.assertEqual(pp.digest(self.p), before)

    def test_source_graph_preserved_and_updated_dependencies_consistent(self):
        for key in ['components', 'sourceEdgeIds']:
            self.assertEqual(self.p[key], self.old[key], key)
        self.assertEqual(self.p['dependencies']['roadDatasetId'], self.old['dependencies']['roadDatasetId'])
        for key in ['roadDatasetId','locationDatasetId','attachmentDatasetId','preprocessingDatasetId']:
            self.assertEqual(self.p['dependencies'][key],self.manifest[key])
        self.assertNotEqual(self.p['dependencies']['locationDatasetId'], self.old['dependencies']['locationDatasetId'])
        self.assertNotEqual(self.p['dependencies']['attachmentDatasetId'], self.old['dependencies']['attachmentDatasetId'])
        self.assertNotEqual(self.p['dependencies']['preprocessingDatasetId'], self.old['dependencies']['preprocessingDatasetId'])
        self.assertEqual(self.p['schemaVersion'], 2)
        self.assertEqual(self.manifest['schemaVersion'], 4)
        self.assertEqual(self.manifest['runtimeSchemaVersion'], 2)
        self.assertEqual(pp.digest(self.p), self.manifest['runtimeDatasetId'])

    def test_unchanged_endpoint_routes_preserve_physical_distance_across_reindex(self):
        old_by={a[0]:i for i,a in enumerate(self.previous['attachments'])}
        common=[a[0] for i,a in enumerate(self.p['attachments']) if a[0] in old_by
                and self.p['attachmentGeometry'][i] == self.previous['attachmentGeometry'][old_by[a[0]]]]
        rnd=random.Random(74)
        for _ in range(30):
            a,b=rnd.sample(common,2)
            before=find_route(self.previous,a,b);after=find_route(self.p,a,b)
            self.assertEqual(before['status'],after['status'])
            if before['status']=='found':self.assertAlmostEqual(before['roadDistanceM'],after['roadDistanceM'],places=6)

    def test_seeded_runtime_routes_use_only_exported_geometry_and_consistent_intervals(self):
        rnd = random.Random(42)
        names = [a[0] for a in self.p['attachments']]
        found = 0
        for _ in range(100):
            a, b = rnd.sample(names, 2)
            result = find_route(self.p, a, b)
            self.assertNotEqual(result['status'], 'search-limit')
            self.assertEqual(len(result['endpointApproaches']), 2)
            if result['status'] != 'found':
                self.assertEqual(result['status'], 'disconnected-road-networks')
                continue
            found += 1
            self.assertAlmostEqual(result['roadDistanceM'], sum(self.p['edges'][eid][2] for eid, _ in result['edgePath']), places=7)
            for r in result['geography']['overlappingLocations']:
                total = sum(hi-lo for lo, hi in r['routeIntervalsM'])
                self.assertAlmostEqual(total, r['insideDistanceM'], places=7)
                self.assertGreater(total, 0)
                for lo, hi in r['routeIntervalsM']:
                    self.assertGreaterEqual(lo, 0)
                    self.assertLessEqual(hi, result['roadDistanceM']+1e-7)
        self.assertGreater(found, 80)


if __name__ == '__main__':
    unittest.main(verbosity=2)
