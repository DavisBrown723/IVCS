"""Check real Altis ownership after the spatial compound policy change."""
import json
import os
from pathlib import Path
import unittest
from access import distance, nearest_in_shape

ROOT=Path(__file__).resolve().parents[2]
DATA=Path(os.environ.get('IVCS_ROAD_OUTPUT',ROOT/'output/altis/roads'))

def components(site):
    return site.get('components',[[site['id'],site['type'],site['objectCount']]])

class SavedSpatialMerges(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old=json.loads((ROOT/'baseline/spatial-merging-before/roads/locations.json').read_text(encoding='utf-8'))
        cls.new=json.loads((DATA/'locations.json').read_text(encoding='utf-8'))
        cls.by={s['id']:s for s in cls.new}
        cls.owners={}
        for s in cls.new:
            for cid,kind,count in components(s):
                cls.owners.setdefault(cid,[]).append(s['id'])

    def test_every_previous_source_component_has_exactly_one_owner(self):
        for s in self.old:
            for cid,kind,count in components(s):
                self.assertEqual(len(self.owners.get(cid,[])),1,cid)
                owner=self.by[self.owners[cid][0]]
                # Singleton fallback records can include annotations; actual component rows are exact.
                if 'components' in s:self.assertIn([cid,kind,count],components(owner))

    def test_airport_absorbs_southwest_base_and_all_its_support(self):
        self.assertNotIn('altis_base_90',self.by)
        old=next(s for s in self.old if s['id']=='altis_base_90')
        for c in components(old):
            self.assertEqual(self.owners[c[0]],['altis_airfield_169'])
            self.assertIn(c,self.by['altis_airfield_169']['components'])
        airport=self.by['altis_airfield_169']
        self.assertEqual(airport['type'],'base')
        self.assertIn('air',airport['types'])
        self.assertEqual(airport['footprint'][0],'rectangle')
        self.assertGreater(airport['objectCount'],1580)
        self.assertEqual(sum(n for m,n in airport['models']),airport['objectCount'])

    def test_northern_core_is_not_fully_contained(self):
        airport=self.by['altis_airfield_169']
        north=self.by['altis_base_132']
        self.assertEqual(self.owners['altis_base_132'],['altis_base_132'])
        old=next(s for s in self.old if s['id']=='altis_base_132')
        self.assertEqual(north['components'],old['components'])
        # This real site is not the fully-contained case exercised by native fixtures.
        # Even its displayed (support-inclusive) rectangle excludes military buildings.
        gaps=[distance(p,nearest_in_shape(airport['footprint'],p))
              for kind,cls,model,p in north['militaryBuildings']]
        self.assertGreater(sum(g>0.01 for g in gaps),0)
        self.assertGreater(max(gaps),50)

    def test_airport_reassesses_support_after_core_consolidation(self):
        airport=self.by['altis_airfield_169']
        for cid in ['altis_fuel_52','altis_radiotower_22']:
            self.assertEqual(self.owners[cid],['altis_airfield_169'])
            self.assertNotIn(cid,set(self.by))
        self.assertIn('fuel',airport['types'])
        self.assertIn('radiotower',airport['types'])

    def test_input_inventory_and_road_topology_unchanged(self):
        before=json.loads((ROOT/'baseline/spatial-merging-before/source.json').read_text(encoding='utf-8'))
        after=json.loads((DATA.parent/'source.json').read_text(encoding='utf-8'))
        self.assertEqual(before['inventorySha256'],after['inventorySha256'])
        old=json.loads((ROOT/'baseline/spatial-merging-before/roads/manifest.json').read_text(encoding='utf-8'))
        new=json.loads((DATA/'manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(old['roadDatasetId'],new['roadDatasetId'])
        for k in ['locationDatasetId','attachmentDatasetId','preprocessingDatasetId','runtimeDatasetId']:
            self.assertNotEqual(old[k],new[k],k)

if __name__=='__main__':unittest.main()
