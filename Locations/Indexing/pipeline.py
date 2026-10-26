"""Validate one complete authoring build before publishing it as the normal map index."""
import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent/'Roads'))
from index import digest, load_locations


def validate(directory):
    directory = Path(directory)
    read = lambda name: json.loads((directory/name).read_text(encoding='utf-8'))
    locations = load_locations(directory/'locations.sqf')
    manifest = read('roads/manifest.json')
    runtime = read('roads/runtime.json')
    source = read('source.json')
    sha = lambda name: hashlib.sha256((directory/name).read_bytes()).hexdigest()
    if source['sha256'] != sha('locations.sqf') or source['inventorySha256'] != sha('objects.sqf'):
        raise ValueError('Native location provenance does not match the saved files')
    if manifest['locationFileSHA256'] != sha('locations.sqf') or manifest['locationDatasetId'] != digest(locations):
        raise ValueError('Roads were generated from a different location file')
    if locations != read('roads/locations.json'):
        raise ValueError('Road location export differs from native locations')
    ids = {s['id'] for s in locations}
    if len(ids) != len(locations) or set(runtime['locations']) != ids:
        raise ValueError('Duplicate or missing runtime locations')
    if any(s['world'].lower() != manifest['world'].lower() for s in locations):
        raise ValueError('Mixed terrain locations')
    if manifest['runtimeDatasetId'] != digest(runtime):
        raise ValueError('Runtime content identity mismatch')
    for key in ['roadDatasetId','locationDatasetId','attachmentDatasetId','preprocessingDatasetId']:
        if manifest[key] != runtime['dependencies'][key]:
            raise ValueError('Stale runtime dependency: '+key)
    for name in ['locations.sqf','catalog.sqf','objects.sqf']:
        if b'\n' in (directory/name).read_bytes().replace(b'\r\n',b''):
            raise ValueError('SQF must use CRLF: '+name)
    for name, key in [('attachments','locationId'),('routing-anchors','locationId'),('accessibility','locationId')]:
        if any(r[key] not in ids for r in read('roads/'+name+'.json')):
            raise ValueError('Unknown location reference: '+name)
    if any(c[k] not in ids for c in read('roads/objective-connections.json') for k in ['fromLocationId','toLocationId']):
        raise ValueError('Unknown location in baseline connection')
    text = (directory/'viewer/data.js').read_text(encoding='utf-8')
    viewer = json.loads(text.removeprefix('window.ROAD_DATA = ').strip().removesuffix(';'))
    if viewer['manifest'] != manifest:
        raise ValueError('Viewer contains a different build')
    return {'schemaVersion':1,'status':'complete','world':manifest['world'],
            'generatedAtUTC':datetime.now(timezone.utc).isoformat(),
            'locationIndexVersion':locations[0]['indexVersion'],
            'locationVariant':locations[0]['indexVariant'],
            'roadManifest':'roads/manifest.json','runtime':'roads/runtime.json',
            'summary':manifest['summary'],
            'datasets':{key:manifest[key] for key in ['roadDatasetId','locationDatasetId','attachmentDatasetId','preprocessingDatasetId','runtimeDatasetId']},
            'files':{str(f.relative_to(directory)).replace('\\','/'):hashlib.sha256(f.read_bytes()).hexdigest()
                     for f in sorted(directory.rglob('*')) if f.is_file() and f.name != 'index.json'}}


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory',type=Path,required=True)
    args=parser.parse_args()
    report=validate(args.directory)
    (args.directory/'index.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Validated complete map index: '+str(args.directory))
