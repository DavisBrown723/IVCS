import unittest,math,json
from pathlib import Path
from proximity import closest
circle=lambda x,y,r:['circle',[x,y,0],[r,r],0]
rect=lambda x,y,w,h,a=0:['rectangle',[x,y,0],[w,h],a]
class Geometry(unittest.TestCase):
 def check_gap(self,a,b,expected):
  d,p,q=closest(a,b);rev,r,s=closest(b,a)
  self.assertAlmostEqual(d,expected,places=6);self.assertAlmostEqual(d,rev,places=6);self.assertAlmostEqual(math.dist(p,q),d,places=6)
 def test_circles(self):self.check_gap(circle(0,0,10),circle(100,0,20),70)
 def test_circle_overlap(self):self.check_gap(circle(0,0,100),circle(20,0,10),0)
 def test_circle_rectangle(self):self.check_gap(circle(0,0,10),rect(100,0,20,40),70)
 def test_rotated_rectangle(self):self.check_gap(circle(0,0,10),rect(100,0,20,40,90),50)
 def test_rectangles(self):self.check_gap(rect(0,0,10,10),rect(40,50,10,10),math.hypot(20,30))
 def test_containment(self):self.check_gap(rect(0,0,100,100,20),rect(0,0,10,10),0)
 def test_crossing_rectangles(self):self.check_gap(rect(0,0,100,10),rect(0,0,100,10,90),0)
 def test_touch(self):self.check_gap(rect(0,0,10,10),rect(20,0,10,10),0)
 def test_saved_syrta(self):
  d=json.loads((Path(__file__).parent/'output/objective-graph.json').read_text());ids={s['id']:i for i,s in enumerate(d['nodes'])};a,b=ids['altis_town_2067'],ids['altis_base_38'];link=next(l for l in d['proximityLinks'] if {l['a'],l['b']}=={a,b})
  self.assertTrue(800<link['gapM']<850);self.assertGreater(link['centerDistanceM'],1000);self.assertFalse(any({l['a'],l['b']}=={a,b} for l in d['links']));self.assertGreater(link['gapM'],750);self.assertLessEqual(link['gapM'],1000)
 def test_saved_integrity(self):
  d=json.loads((Path(__file__).parent/'output/objective-graph.json').read_text());seen=set()
  for l in d['proximityLinks']:
   key=(l['a'],l['b']);self.assertNotIn(key,seen);seen.add(key);self.assertLess(*key);self.assertGreaterEqual(l['gapM'],0);self.assertLessEqual(l['gapM'],2000)
   a,b=(d['nodes'][i]['footprint'] for i in key);self.assertAlmostEqual(closest(a,b)[0],l['gapM']);self.assertAlmostEqual(closest(b,a)[0],l['gapM']);self.assertAlmostEqual(math.dist(*l['points']),l['gapM']);self.assertEqual(l['traversal'],'unassessed')
if __name__=='__main__':unittest.main()
