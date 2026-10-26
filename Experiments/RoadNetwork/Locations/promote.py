"""Validate and promote the isolated native location rebuild into RoadNetwork inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
WORKSPACE=ROOT.parents[2]
sys.path.insert(0,str(ROOT))
from index import load_locations, digest, write_json


def promote(source, rpt):
    expected_root=(ROOT/'Locations/output').resolve()
    source=source.resolve()
    if expected_root not in source.parents:
        raise ValueError('Location source must remain in RoadNetwork/Locations/output')
    locations=load_locations(source)
    if any(s['world'].lower()!='altis' or s['indexVersion']!=7 or s['indexVariant']!='adaptive-footprints-settlement-ports-v2' for s in locations):
        raise ValueError('Unexpected location terrain/version/variant')
    if rpt is None:
        raise ValueError('A successful native rebuild RPT is required for provenance')
    log=rpt.read_text(errors='replace')
    if '[IVCS TASK TEST] DONE passed=1 failed=0' not in log:
        raise ValueError('Native location rebuild did not pass')
    if any(s in log for s in ['Error in expression','Error Undefined variable','Error Missing','Error Type']):
        raise ValueError('Native rebuild contains SQF errors')
    baseline=ROOT/'baseline/nonstopping-fallbacks-before/inputs/altis-locations.sqf'
    previous=load_locations(baseline)
    old={s['id']:s for s in previous};new={s['id']:s for s in locations}
    absorbed=[]
    for s in previous:
        if s['type']!='port' or s['id'] in new:continue
        hosts=[n for n in locations if any(c[0]==s['id'] and c[1]=='port' for c in n.get('components',[]))]
        if len(hosts)!=1 or hosts[0]['type']!='town':
            raise ValueError('Removed port lacks one settlement owner: '+s['id'])
        host=hosts[0]
        if 'port' not in host['types']:raise ValueError('Host lost its port role')
        absorbed.append({'portId':s['id'],'settlementId':host['id'],'previousPortObjectCount':s['objectCount'],
                         'portComponent':next(c for c in host['components'] if c[0]==s['id'])})
    semantic_keys=['type','types','objectCount','position','size','footprint','typeCounts','components','models','militaryBuildings','militaryBuildingCounts']
    changed=[sid for sid in sorted(set(old)&set(new)) if any(old[sid].get(k)!=new[sid].get(k) for k in semantic_keys)]
    port_count=lambda records:sum(dict(s['typeCounts']).get('port',0) for s in records)
    if port_count(previous)!=port_count(locations):raise ValueError('Port evidence counts changed unexpectedly')
    report={'beforeLocations':len(previous),'afterLocations':len(locations),'newlyAbsorbedPorts':absorbed,
            'standalonePortIds':[s['id'] for s in locations if s['type']=='port'],
            'changedSemanticLocationIds':changed,'removedLocationIds':sorted(set(old)-set(new)),
            'addedLocationIds':sorted(set(new)-set(old)),
            'portEvidenceBefore':port_count(previous),'portEvidenceAfter':port_count(locations),
            'previousLocationDatasetId':digest(previous),'locationDatasetId':digest(locations),
            'settings':'Settlement port count cap removed; existing 100 m link, 250 m whole-child and rectangle margin policies preserved.'}
    payload=source.read_bytes()
    if b'\n' in payload.replace(b'\r\n',b''):raise ValueError('Location SQF must use CRLF')
    (ROOT/'inputs/altis-locations.sqf').write_bytes(payload)
    inventory=WORKSPACE/'IVCS/Locations/Indexing/output/altis/objects.sqf'
    dependencies=list((WORKSPACE/'IVCS/Experiments/AdaptiveFootprints').glob('*.sqf'))+list((WORKSPACE/'IVCS/Experiments/AdaptiveFootprints/geometry').glob('*.sqf'))+list((ROOT/'Locations').glob('*.sqf'))
    metadata={'source':str(source.relative_to(WORKSPACE)).replace('\\','/'),'sha256':hashlib.sha256(payload).hexdigest(),
              'status':'Rebuilt isolated settlement-port variant from saved Altis object inventory',
              'variant':'adaptive-footprints-settlement-ports-v2','locationDatasetId':digest(locations),
              'inventory':str(inventory.relative_to(WORKSPACE)).replace('\\','/'),'inventorySha256':hashlib.sha256(inventory.read_bytes()).hexdigest(),
              'nativeRPT':str(rpt.resolve()),
              'sourceHashes':{str(p.relative_to(WORKSPACE)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(dependencies)}}
    write_json(ROOT/'inputs/source.json',metadata)
    write_json(ROOT/'output/altis/location-comparison.json',report)
    print(json.dumps(report,indent=2))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input',type=Path,default=ROOT/'Locations/output/altis/locations.sqf')
    parser.add_argument('--rpt',type=Path,required=True)
    args=parser.parse_args();promote(args.input,args.rpt)
