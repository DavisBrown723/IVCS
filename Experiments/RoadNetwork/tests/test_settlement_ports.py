"""Generated location and dependent dataset checks for settlement-port absorption."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from index import load_locations, digest


class SavedSettlementPorts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.locations=json.loads((ROOT/'output/altis/locations.json').read_text())
        cls.by={s['id']:s for s in cls.locations}
        cls.old=json.loads((ROOT/'baseline/nonstopping-fallbacks-before/output/altis/locations.json').read_text())
        cls.old_by={s['id']:s for s in cls.old}
        cls.report=json.loads((ROOT/'output/altis/location-comparison.json').read_text())
        cls.manifest=json.loads((ROOT/'output/altis/manifest.json').read_text())

    def test_eligible_altis_ports_absorbed_with_roles_components_and_counts(self):
        expected={'altis_port_38':('altis_town_23',67),'altis_port_195':('altis_town_3310',50),'altis_port_291':('altis_town_4303',82)}
        for port,(host,count) in expected.items():
            self.assertNotIn(port,self.by)
            owners=[s for s in self.locations if any(c[0]==port for c in s.get('components',[]))]
            self.assertEqual([s['id'] for s in owners],[host])
            s=self.by[host]
            self.assertEqual(s['type'],'town')
            self.assertIn([port,'port',float(count)],s['components'])
            self.assertEqual(dict(s['typeCounts'])['port'],dict(self.old_by[host]['typeCounts']).get('port',0)+count)
            self.assertEqual(s['objectCount'],self.old_by[host]['objectCount']+count)

    def test_standalone_ports_and_complete_port_evidence_retained(self):
        ports=[s for s in self.locations if s['type']=='port']
        self.assertEqual(len(ports),19)
        self.assertIn('altis_port_0',{s['id'] for s in ports})
        self.assertIn('altis_port_252',{s['id'] for s in ports})
        for s in ports:
            before=self.old_by[s['id']]
            for key in ['types','objectCount','typeCounts','models','components','footprint']:
                self.assertEqual(s.get(key),before.get(key))
        total=lambda sites:sum(dict(s['typeCounts']).get('port',0) for s in sites)
        self.assertEqual(total(self.locations),503)
        self.assertEqual(total(self.locations),total(self.old))

    def test_military_companion_is_retained_as_independent_site(self):
        # The port is consumed by support ownership before general compounds.
        # Its former military neighbour now retains its own identity and power support.
        s=self.by['altis_base_220'];old=self.old_by['altis_port_291']
        self.assertEqual(s['type'],'base')
        self.assertEqual(s['typeCounts'],[['base',4.0],['power',1.0]])
        self.assertEqual(s['militaryBuildings'],old['militaryBuildings'])
        self.assertEqual(s['militaryBuildingCounts'],old['militaryBuildingCounts'])

    def test_native_source_input_and_export_dependencies_match(self):
        source=json.loads((ROOT/'inputs/source.json').read_text())
        self.assertEqual(self.locations,load_locations(ROOT/'inputs/altis-locations.sqf'))
        self.assertEqual(self.locations,load_locations(ROOT/'Locations/output/altis/locations.sqf'))
        self.assertEqual(digest(self.locations),self.manifest['locationDatasetId'])
        self.assertEqual(source['locationDatasetId'],self.manifest['locationDatasetId'])
        self.assertEqual(source['sha256'],hashlib.sha256((ROOT/'inputs/altis-locations.sqf').read_bytes()).hexdigest())
        self.assertNotEqual(self.report['previousLocationDatasetId'],self.manifest['locationDatasetId'])
        self.assertEqual(len(self.locations),278)
        for s in self.locations:
            self.assertEqual(s['indexVersion'],7)
            self.assertEqual(s['indexVariant'],'adaptive-footprints-settlement-ports-v2')
        known=set(self.by)
        for name,key in [('attachments','locationId'),('routing-anchors','locationId'),('corridors','locationId'),('routing-corridors','locationId'),('accessibility','locationId')]:
            rows=json.loads((ROOT/('output/altis/'+name+'.json')).read_text())
            self.assertTrue(all(r[key] in known for r in rows),name)
        for c in json.loads((ROOT/'output/altis/objective-connections.json').read_text()):
            self.assertIn(c['fromLocationId'],known);self.assertIn(c['toLocationId'],known)


if __name__=='__main__':unittest.main(verbosity=2)
