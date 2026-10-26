"""Baseline discovery records off-road attachments without treating them as road gates."""
import json
from pathlib import Path
import os
import unittest
from test_preprocess import fixture, attachment, pipeline
from runtime_query import find_route

ROOT=Path(__file__).resolve().parents[1]
DATA = Path(os.environ.get('IVCS_ROAD_OUTPUT', ROOT.parent/'output/altis/roads'))
VIEWER = Path(os.environ.get('IVCS_ROAD_VIEWER', DATA.parent/'viewer'))


def pairs(connections):
    return {frozenset([c['fromAttachmentId'],c['toAttachmentId']]):c for c in connections}


class NonStoppingFallbackFixtures(unittest.TestCase):
    def test_dorida_power_chalkeia_triangle_with_real_distances(self):
        roads,graph,r=fixture([(0,0),(100,0),(200,0),(300,0)],[(0,1),(1,2),(2,3)])
        a=[attachment('Dorida','town-a',r[0]), attachment('Power','power',r[1],gap=40), attachment('Chalkeia','town-b',r[3])]
        d=pipeline(roads,graph,a); cs=pairs(d['objectiveConnections'])
        self.assertEqual(set(cs),{frozenset(p) for p in [('Dorida','Power'),('Power','Chalkeia'),('Dorida','Chalkeia')]})
        self.assertEqual(cs[frozenset(['Dorida','Chalkeia'])]['roadDistanceM'],300)
        self.assertEqual(cs[frozenset(['Dorida','Chalkeia'])]['offRoadGapM'],[0,0])
        self.assertEqual(cs[frozenset(['Dorida','Power'])]['roadDistanceM'],100)
        self.assertEqual(cs[frozenset(['Chalkeia','Power'])]['roadDistanceM'],200)
        self.assertIn('fallback-only',d['runtime']['baselineNodeKinds'])

    def test_multiple_fallback_nodes_do_not_stop_or_add_intermediate_approach_cost(self):
        roads,graph,r=fixture([(0,0),(100,0),(200,0),(300,0)],[(0,1),(1,2),(2,3)])
        a=[attachment('a','A',r[0]),attachment('p1','P',r[1],[100,5,10],gap=45),
           attachment('p2','P',r[2],[200,7,10],gap=80),attachment('b','B',r[3])]
        d=pipeline(roads,graph,a);c=pairs(d['objectiveConnections'])[frozenset(['a','b'])]
        self.assertEqual(c['roadDistanceM'],300)
        self.assertEqual(c['offRoadGapM'],[0,0]);self.assertEqual(c['anchorConnectorM'],[0,0])
        self.assertGreater(len(c['edgePath']),1)
        own=pairs(d['objectiveConnections'])[frozenset(['p1','p2'])]
        self.assertEqual(own['roadDistanceM'],100)
        self.assertEqual(sorted(own['offRoadGapM']),[45,80])
        self.assertEqual(sorted(own['anchorConnectorM']),[5,7])

    def test_genuine_boundary_node_still_stops_discovery(self):
        roads,graph,r=fixture([(0,0),(100,0),(200,0),(300,0)],[(0,1),(1,2),(2,3)])
        a=[attachment('a','A',r[0]),attachment('middle','town',r[1]),
           attachment('power','P',r[2],gap=40),attachment('b','B',r[3])]
        d=pipeline(roads,graph,a);cs=pairs(d['objectiveConnections'])
        self.assertIn(frozenset(['a','middle']),cs)
        self.assertNotIn(frozenset(['a','power']),cs)
        self.assertNotIn(frozenset(['a','b']),cs)
        self.assertIn(frozenset(['middle','b']),cs)
        self.assertEqual(find_route(d['runtime'],'a','b')['roadDistanceM'],300)

    def test_mixed_node_stops_but_origin_still_expands(self):
        roads,graph,r=fixture([(0,0),(100,0),(200,0)],[(0,1),(1,2)])
        a=[attachment('a','A',r[0]),attachment('inlet','town',r[1]),
           attachment('fallback','P',r[1],gap=40),attachment('b','B',r[2])]
        d=pipeline(roads,graph,a);cs=pairs(d['objectiveConnections'])
        self.assertIn('mixed',d['runtime']['baselineNodeKinds'])
        self.assertIn(frozenset(['a','fallback']),cs)
        self.assertIn(frozenset(['b','fallback']),cs)
        self.assertNotIn(frozenset(['a','b']),cs)
        self.assertEqual(cs[frozenset(['inlet','fallback'])]['roadDistanceM'],0)
        self.assertEqual(sorted(cs[frozenset(['inlet','fallback'])]['offRoadGapM']),[0,40])

    def test_shared_fallback_site_cannot_bridge_networks(self):
        roads,graph,r=fixture([(0,0),(100,0),(200,0),(300,0)],[(0,1),(2,3)])
        a=[attachment('a','A',r[0]),attachment('p1','P',r[1],gap=30),
           attachment('p2','P',r[2],gap=30),attachment('b','B',r[3])]
        d=pipeline(roads,graph,a);cs=pairs(d['objectiveConnections'])
        self.assertEqual(set(cs),{frozenset(['a','p1']),frozenset(['b','p2'])})
        self.assertEqual(find_route(d['runtime'],'a','b')['status'],'disconnected-road-networks')

    def test_fallbacks_do_not_shortcut_external_detour(self):
        roads,graph,r=fixture([(0,0),(0,100),(100,100),(100,0)],[(0,1),(1,2),(2,3)])
        a=[attachment('a','shared',r[0],gap=30),attachment('b','shared',r[3],gap=40)]
        c=pipeline(roads,graph,a)['objectiveConnections'][0]
        self.assertEqual(c['roadDistanceM'],300)
        self.assertEqual(sorted(c['offRoadGapM']),[30,40])


class SavedNonStoppingBaseline(unittest.TestCase):
    def test_altis_dorida_chalkeia_power_triangle_exists(self):
        cs=json.loads((DATA/'objective-connections.json').read_text())
        wanted={'altis_town_5090','altis_town_5229','altis_power_1145'}
        present={frozenset([c['fromLocationId'],c['toLocationId']]) for c in cs
                 if c['fromLocationId'] in wanted and c['toLocationId'] in wanted and c['fromLocationId']!=c['toLocationId']}
        self.assertEqual(present,{frozenset(p) for p in [('altis_town_5090','altis_town_5229'),('altis_town_5090','altis_power_1145'),('altis_town_5229','altis_power_1145')]})

    def test_baseline_paths_may_cross_only_fallback_attachment_nodes_internally(self):
        cs=json.loads((DATA/'objective-connections.json').read_text())
        p=json.loads((DATA/'runtime.json').read_text())
        edge_index={eid:i for i,eid in enumerate(p['edgeIds'])}
        saw_fallback=False
        for c in cs:
            for eid,direction in c['edgePath'][:-1]:
                e=p['edges'][edge_index[eid]]; node=e[1] if direction==1 else e[0]
                self.assertNotIn(p['baselineNodeKinds'][node],['boundary-inlet','mixed'])
                saw_fallback |= p['baselineNodeKinds'][node]=='fallback-only'
        self.assertTrue(saw_fallback)


if __name__=='__main__':unittest.main(verbosity=2)
