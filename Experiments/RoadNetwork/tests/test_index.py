import copy
import heapq
import importlib.util
import json
import math
from pathlib import Path
import random
import unittest
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
import access as access_module
spec=importlib.util.spec_from_file_location('road_index',ROOT/'index.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

def rows(points,links,types=None,extras=None):
    return [[i,str(i),[x,y,10],[(types or {}).get(i,'ROAD'),8,False,'','','',[x-1,y,10],[x+1,y,10],False,0],
             [b for a,b in links if a==i],[b for a,b in (extras or links) if a==i]] for i,(x,y) in enumerate(points)]
def both(pairs): return [(a,b) for a,b in pairs]+[(b,a) for a,b in pairs]
def graph(raw):
    roads=m.normalize(raw);return roads,m.network(roads)
def shortest(adj,start):
    found={start:0};queue=[(0,start)]
    while queue:
        cost,at=heapq.heappop(queue)
        if cost!=found[at]:continue
        for nxt,length in adj.get(at,[]):
            d=cost+length
            if d<found.get(nxt,math.inf):found[nxt]=d;heapq.heappush(queue,(d,nxt))
    return found

class Fixtures(unittest.TestCase):
    def test_chain_condenses(self):
        r,g=graph(rows([(0,0),(10,0),(20,0),(30,0)],both([(0,1),(1,2),(2,3)])))
        self.assertEqual((len(g['nodes']),len(g['edges'])),(2,1));self.assertAlmostEqual(g['edges'][0]['length2dM'],30)
    def test_ring_preserves_parallel_routes(self):
        r,g=graph(rows([(0,0),(10,0),(10,10),(0,10)],both([(0,1),(1,2),(2,3),(3,0)])))
        self.assertEqual((len(g['nodes']),len(g['edges'])),(2,2));self.assertEqual(sum(e['length2dM'] for e in g['edges']),40)
    def test_junction_and_dead_ends_retained(self):
        r,g=graph(rows([(0,0),(10,0),(20,0),(10,10)],both([(0,1),(1,2),(1,3)])))
        self.assertEqual(sum(n['degree']==3 for n in g['nodes']),1);self.assertEqual(sum(n['degree']==1 for n in g['nodes']),3)
    def test_crossing_geometry_does_not_connect(self):
        r,g=graph(rows([(0,0),(0,0)],[]));self.assertEqual(len(g['components']),2)
    def test_one_sided_observation_is_not_one_way(self):
        r,g=graph(rows([(0,0),(10,0)],[(0,1)]));self.assertEqual(len(g['components']),1);self.assertEqual(g['connections'][0]['evidence'],'ordinary-one-sided')
    def test_extended_only_is_diagnostic(self):
        r,g=graph(rows([(0,0),(10,0)],[],extras=both([(0,1)])));self.assertEqual(len(g['components']),2);self.assertFalse(g['connections'][0]['accepted'])
    def test_attribute_change_stops_compression(self):
        r,g=graph(rows([(0,0),(10,0),(20,0),(30,0)],both([(0,1),(1,2),(2,3)]),types={2:'TRACK',3:'TRACK'}));self.assertEqual(len(g['nodes']),4)
    def test_bridge_width_unknown_and_height_from_deck(self):
        raw=rows([(0,0)],[]);raw[0][3][8]=True;raw[0][2][2]=-20
        r,g=graph(raw);self.assertNotIn('widthM',r[0]);self.assertEqual(r[0]['positionASL'][2],10);self.assertIn('bridge',g['nodes'][0]['reasons'])
    def test_missing_endpoints_do_not_create_origin_road(self):
        raw=rows([(1000,2000)],[]);raw[0][3][6]=[0,0,0];raw[0][3][7]=[0,0,0]
        r,g=graph(raw);self.assertEqual(r[0]['geometryStatus'],'unavailable');self.assertEqual(r[0]['beginASL'],[1000,2000,10]);self.assertEqual(g['nodes'],[])
    def test_enumeration_order_does_not_change_graph(self):
        raw=rows([(30,0),(10,0),(20,0)],both([(0,1),(1,2)]));r,g=graph(raw);r2,g2=graph(list(reversed(raw)));self.assertEqual((r,g),(r2,g2))
    def test_dangling_capture_reference_fails(self):
        with self.assertRaises(KeyError):m.normalize(rows([(0,0)],[(0,2)]))
    def test_circle_gap(self):
        p=m.nearest_in_shape(['circle',[0,0,0],[10,10],0],[30,0]);self.assertEqual(p,[10,0])
    def test_rotated_rectangle_excludes_lateral_point(self):
        f=['rectangle',[1000,2000,0],[100,10],37];p=m.from_local(f,[0,30]);target=m.nearest_in_shape(f,p);self.assertAlmostEqual(m.distance(p,target),20)
    def test_road_segment_through_footprint_zero_gap(self):
        r=m.normalize(rows([(0,0)],[]))[0];r['beginASL']=[-1000,0,10];r['endASL']=[1000,0,10]
        self.assertEqual(m.road_candidate(['rectangle',[0,0,0],[10,100],20],r)[0],0)
    def test_no_forced_access_from_far_road(self):
        r,g=graph(rows([(5000,5000)],[]));a,c=m.attachments(r,[{'id':'test','position':[0,0,0],'size':20}],g['connections']);self.assertFalse(a);self.assertEqual(c[0]['candidateCount'],0)
    def test_world_mismatch_rejected(self):
        with self.assertRaises(ValueError):m.build({'meta':['Altis'],'roads':[]},[{'world':'Stratis'}])
    def test_edge_closure_preserves_parallel_bypass(self):
        r,g=graph(rows([(0,0),(10,0),(10,10),(0,10)],both([(0,1),(1,2),(2,3),(3,0)])))
        remaining=g['edges'][1:];adj={}
        for e in remaining:adj.setdefault(e['from'],[]).append((e['to'],e['length3dM']));adj.setdefault(e['to'],[]).append((e['from'],e['length3dM']))
        self.assertIn(g['nodes'][1]['id'],shortest(adj,g['nodes'][0]['id']))


def inlet_fixture(segments,links=None,shape=None,extended=None):
    raw=[]
    for i,(a,b) in enumerate(segments):
        a=list(a)+([10] if len(a)==2 else []);b=list(b)+([10] if len(b)==2 else [])
        raw.append([i,str(i),[(a[j]+b[j])/2 for j in range(3)],
                    ['ROAD',8,False,'','','',a,b,False,0],
                    [q for p,q in both(links or []) if p==i],
                    [q for p,q in both(extended if extended is not None else links or []) if p==i]])
    roads,g=graph(raw)
    site={'id':'fixture','position':[0,0,0],'size':100,'footprint':shape or ['circle',[0,0,0],[100,100],0]}
    return m.attachments(roads,[site],g['connections'])


class InletFixtures(unittest.TestCase):
    def test_through_road_has_both_inlets_with_outside_endpoints(self):
        a,c=inlet_fixture([([-200,0],[200,0])])
        self.assertEqual(len(a),2)
        self.assertEqual({round(x['positionASL'][0]) for x in a},{-100,100})
    def test_internal_road_is_not_an_entrance(self):
        a,c=inlet_fixture([([-50,0],[50,0])])
        self.assertEqual(a,[]);self.assertEqual(c[0]['status'],'roads-without-crossing')
    def test_nearby_parallel_road_is_diagnostic_only(self):
        a,c=inlet_fixture([([-200,130],[200,130])])
        self.assertEqual(a,[]);self.assertAlmostEqual(c[0]['nearestRoadGapM'],30)
        self.assertEqual(c[0]['status'],'nearby-roads-only')
    def test_circle_tangent_is_not_an_inlet(self):
        a,c=inlet_fixture([([-200,100],[200,100])]);self.assertEqual(a,[])
    def test_rectangle_edge_is_not_an_inlet(self):
        a,c=inlet_fixture([([-200,100],[200,100])],shape=['rectangle',[0,0,0],[100,100],0])
        self.assertEqual(a,[])
    def test_shared_boundary_vertex_counted_once(self):
        a,c=inlet_fixture([([-200,0],[-100,0]),([-100,0],[0,0])],links=[(0,1)])
        self.assertEqual(len(a),1);self.assertEqual(len(a[0]['roadIds']),2)
    def test_unconnected_boundary_vertex_does_not_invent_access(self):
        a,c=inlet_fixture([([-200,0],[-100,0]),([-100,0],[0,0])])
        self.assertEqual(a,[])
    def test_close_parallel_entries_survive_in_same_network(self):
        a,c=inlet_fixture([([-200,1],[200,1]),([-200,3],[200,3])],links=[(0,1)])
        self.assertEqual(len(a),4)
    def test_unconnected_crossings_at_same_xy_stay_separate(self):
        a,c=inlet_fixture([([-200,0],[200,0]),([-200,0],[200,0])])
        self.assertEqual(len(a),4)
    def test_different_heights_are_not_collapsed(self):
        a,c=inlet_fixture([([-200,0,10],[200,0,10]),([-200,0,30],[200,0,30])],links=[(0,1)])
        self.assertEqual(len(a),4)
    def test_more_than_twelve_inlets_are_retained(self):
        segments=[]
        for i in range(20):
            angle=2*math.pi*i/20;v=[math.cos(angle),math.sin(angle)]
            segments.append(([x*80 for x in v],[x*120 for x in v]))
        a,c=inlet_fixture(segments)
        self.assertEqual(len(a),20);self.assertEqual([x['number'] for x in a],list(range(1,21)))
    def test_rotated_rectangle_crossings(self):
        shape=['rectangle',[1000,2000,0],[50,100],37]
        a,c=inlet_fixture([(m.from_local(shape,[-200,0]),m.from_local(shape,[200,0]))],shape=shape)
        self.assertEqual(len(a),2)
        for x in a:self.assertAlmostEqual(abs(access_module.to_local(shape,x['positionASL'])[0]),50)
    def test_rectangle_corner_is_one_crossing(self):
        a,c=inlet_fixture([([-200,-200],[0,0])],shape=['rectangle',[0,0,0],[100,100],0])
        self.assertEqual(len(a),1)
    def test_ordinary_gap_is_explicitly_interpolated(self):
        a,c=inlet_fixture([([-200,0],[-120,0]),([-80,0],[0,0])],links=[(0,1)])
        self.assertEqual(len(a),1);self.assertEqual(a[0]['evidence'],['ordinary-link-interpolation'])
        self.assertEqual(c[0]['interpolatedInlets'],1)
    def test_extended_gap_is_not_promoted_to_an_inlet(self):
        a,c=inlet_fixture([([-200,0],[-120,0]),([-80,0],[0,0])],extended=[(0,1)])
        self.assertEqual(a,[])
    def test_crossing_height_is_interpolated_and_access_unassessed(self):
        a,c=inlet_fixture([([-200,0,10],[0,0,30])])
        self.assertAlmostEqual(a[0]['positionASL'][2],20)
        self.assertEqual(a[0]['status'],'candidate');self.assertIn('vehicle-traversal',a[0]['unchecked'])

class SavedData(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.roads=json.loads((ROOT/'output/altis/roads.json').read_text());cls.graph=json.loads((ROOT/'output/altis/graph.json').read_text());cls.access=json.loads((ROOT/'output/altis/attachments.json').read_text());cls.manifest=json.loads((ROOT/'output/altis/manifest.json').read_text())
    def test_all_graph_and_access_references_resolve(self):
        roads={r['id'] for r in self.roads};nodes={n['id'] for n in self.graph['nodes']};edges={e['id'] for e in self.graph['edges']}
        for e in self.graph['edges']:self.assertIn(e['from'],nodes);self.assertIn(e['to'],nodes);self.assertTrue(set(e['roadIds'])<=roads)
        for a in self.access:
            self.assertIn(a['roadId'],roads);self.assertEqual(a['roadDatasetId'],self.manifest['roadDatasetId']);self.assertTrue(all(x['edgeId'] in edges for x in a['graphRefs']))
    def test_compression_preserves_each_link_once(self):
        expected={tuple(sorted([c['a'],c['b']])) for c in self.graph['connections'] if c['accepted']};actual=[]
        for e in self.graph['edges']:actual.extend(tuple(sorted([a,b])) for a,b in zip(e['roadIds'],e['roadIds'][1:]))
        self.assertEqual(set(actual),expected);self.assertEqual(len(actual),len(expected))
    def test_sampled_route_distances_and_reachability_match(self):
        raw={};compressed={}
        for c in self.graph['connections']:
            if c['accepted']:
                raw.setdefault('n-'+c['a'],[]).append(('n-'+c['b'],c['length3dM']));raw.setdefault('n-'+c['b'],[]).append(('n-'+c['a'],c['length3dM']))
        for e in self.graph['edges']:compressed.setdefault(e['from'],[]).append((e['to'],e['length3dM']));compressed.setdefault(e['to'],[]).append((e['from'],e['length3dM']))
        nodes=[n['id'] for n in self.graph['nodes']];samples=random.Random(73).sample(nodes,min(8,len(nodes)))
        for start in samples:
            a,b=shortest(raw,start),shortest(compressed,start)
            for target in nodes:
                self.assertEqual(target in a,target in b)
                if target in a:self.assertAlmostEqual(a[target],b[target],places=6)
    def test_no_missing_geometry_in_graph_or_access(self):
        invalid={r['id'] for r in self.roads if r['geometryStatus']=='unavailable'}
        self.assertFalse(invalid & {n['roadId'] for n in self.graph['nodes']});self.assertFalse(invalid & {a['roadId'] for a in self.access})

    def test_all_inlets_are_on_boundary_with_inside_and_outside_evidence(self):
        sites={s['id']:s for s in json.loads((ROOT/'output/altis/locations.json').read_text())}
        for a in self.access:
            if a['kind']!='boundary-inlet': continue
            shape=m.footprint(sites[a['locationId']])
            self.assertEqual(access_module._side(shape,a['positionASL']),0)
            self.assertEqual(access_module._side(shape,a['insideASL']),1)
            self.assertEqual(access_module._side(shape,a['outsideASL']),-1)
    def test_dorida_has_eight_distinct_perimeter_inlets(self):
        a=[x for x in self.access if x['locationId']=='altis_town_5090']
        self.assertEqual(len(a),8);self.assertEqual(len({x['roadId'] for x in a}),8)
    def test_location_rebuild_preserves_roads_and_updates_location_identity(self):
        old=json.loads((ROOT/'baseline/nearby-access-v1/output/altis/manifest.json').read_text())
        self.assertEqual(self.manifest['roadDatasetId'],old['roadDatasetId'])
        self.assertNotEqual(self.manifest['locationDatasetId'],old['locationDatasetId'])
        self.assertEqual(self.manifest['locationDatasetId'],m.digest(json.loads((ROOT/'output/altis/locations.json').read_text())))
    def test_all_section_inside_outside_transitions_are_represented(self):
        sites=json.loads((ROOT/'output/altis/locations.json').read_text())
        found={(a['locationId'],rid) for a in self.access for rid in a['roadIds']}
        for site in sites:
            shape=m.footprint(site);radius=shape[2][0] if shape[0]=='circle' else math.hypot(*shape[2])
            for r in self.roads:
                if r['geometryStatus']=='unavailable':continue
                if abs(r['positionASL'][0]-shape[1][0])>radius+r['length2dM']/2:continue
                if abs(r['positionASL'][1]-shape[1][1])>radius+r['length2dM']/2:continue
                if access_module._side(shape,r['beginASL'])*access_module._side(shape,r['endASL'])==-1:
                    self.assertIn((site['id'],r['id']),found)

    def test_candidate_distances_and_tags(self):
        for a in self.access:self.assertLessEqual(a['footprintGapM'],500);self.assertEqual(a['status'],'candidate');self.assertNotIn('passable',a)
    def test_viewer_keeps_projection_precision(self):
        text=(ROOT/'viewer/data.js').read_text(encoding='utf-8')
        viewer=json.loads(text.removeprefix('window.ROAD_DATA = ').strip().removesuffix(';'))
        source=self.manifest['basemap']; actual=viewer['manifest']['basemap']
        for key in ['factorX','factorY','tileSize','maxNativeZoom']:
            self.assertEqual(actual[key],source[key])
        for axis in ['factorX','factorY']:
            error=abs(actual[axis]-source[axis])*self.manifest['worldSize']*2**source['maxNativeZoom']
            self.assertLess(error,0.01, 'World-edge displacement must stay below .01 pixels')
    def test_airport_has_multiple_approaches(self):
        a=[x for x in self.access if x['locationId']=='altis_airfield_169'];self.assertGreaterEqual(len(a),4);self.assertTrue(all(x['kind']=='boundary-inlet' for x in a))

if __name__=='__main__':unittest.main(verbosity=2)
