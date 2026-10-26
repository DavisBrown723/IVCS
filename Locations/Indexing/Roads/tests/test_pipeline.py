"""Exercise the promoted CLI and the combined build's publication contract."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from test_index import rows, both

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('map_pipeline', ROOT.parent/'pipeline.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ProductionPipeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.base = Path(cls.temp.name)/'complete'
        cls.base.mkdir()
        site = {'id':'altis_test','type':'town','world':'Altis','position':[20,0,0],
                'size':5,'indexVersion':7,'indexVariant':'adaptive-footprints-settlement-ports-v2'}
        cls.site = site
        payload = 'private _locations = [];\r\n_locations pushBack (createHashMapFromArray '+json.dumps(list(site.items()))+');\r\n_locations\r\n'
        (cls.base/'locations.sqf').write_bytes(payload.encode())
        for name in ['objects.sqf','catalog.sqf']:
            (cls.base/name).write_bytes(b'[]\r\n')
        sha = lambda name: hashlib.sha256((cls.base/name).read_bytes()).hexdigest()
        (cls.base/'source.json').write_text(json.dumps({'sha256':sha('locations.sqf'),'inventorySha256':sha('objects.sqf')}))
        cls.raw = {'meta':['Altis',30720,[],0,3,False],
                   'roads':rows([(0,0),(20,0),(40,0)],both([(0,1),(1,2)])), 'places':[]}
        (cls.base/'capture.json').write_text(json.dumps(cls.raw))
        cls.command = [sys.executable,str(ROOT/'index.py'),'--locations',str(cls.base/'locations.sqf'),
                       '--capture',str(cls.base/'capture.json'),'--output',str(cls.base/'roads'),
                       '--viewer-directory',str(cls.base/'viewer')]
        subprocess.run(cls.command,check=True,capture_output=True,text=True)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_cli_generates_one_matching_complete_build_at_custom_destination(self):
        report=module.validate(self.base)
        self.assertEqual(report['status'],'complete')
        self.assertEqual(report['summary']['locations'],1)
        self.assertGreater(report['summary']['boundaryInlets'],0)
        self.assertIn('roads/runtime.json',report['files'])
        self.assertIn('viewer/data.js',report['files'])

    def test_modified_native_locations_cannot_publish_with_stale_roads(self):
        with tempfile.TemporaryDirectory() as temp:
            target=Path(temp)/'stage';shutil.copytree(self.base,target)
            f=target/'locations.sqf';f.write_bytes(f.read_bytes().replace(b'20, 0, 0',b'21, 0, 0'))
            source=json.loads((target/'source.json').read_text());source['sha256']=hashlib.sha256(f.read_bytes()).hexdigest()
            (target/'source.json').write_text(json.dumps(source))
            with self.assertRaisesRegex(ValueError,'different location file'):
                module.validate(target)

    def test_stale_viewer_prevents_publication(self):
        with tempfile.TemporaryDirectory() as temp:
            target=Path(temp)/'stage';shutil.copytree(self.base,target)
            f=target/'viewer/data.js';s=f.read_text();f.write_text(s.replace('Locations/Indexing/Roads','Old/Build'))
            with self.assertRaisesRegex(ValueError,'Viewer contains a different build'):
                module.validate(target)

    def test_other_terrain_capture_cannot_silently_use_altis_basemap(self):
        with tempfile.TemporaryDirectory() as temp:
            target=Path(temp);raw=dict(self.raw,meta=['Stratis',8192,[],0,3,False])
            (target/'capture.json').write_text(json.dumps(raw))
            cmd=list(self.command)
            cmd[cmd.index('--capture')+1]=str(target/'capture.json')
            cmd[cmd.index('--output')+1]=str(target/'roads')
            cmd[cmd.index('--viewer-directory')+1]=str(target/'viewer')
            result=subprocess.run(cmd,capture_output=True,text=True)
            self.assertNotEqual(result.returncode,0)
            self.assertIn('Altis-specific',result.stderr)
            self.assertFalse((target/'roads/manifest.json').exists())
