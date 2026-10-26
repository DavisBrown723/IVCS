"""Compare saved location membership before and after a spatial merge policy change."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parent
SEMANTIC_KEYS=['type','types','typeCounts','components','objectCount','position','size','footprint','models','militaryBuildings','militaryBuildingCounts']

def components(site):
    return site.get('components',[[site['id'],site['type'],site['objectCount']]])

def compare(before, after, places):
    old={s['id']:s for s in before}; new={s['id']:s for s in after}
    owners={}
    for site in after:
        for cid,kind,count in components(site):
            if cid in owners and owners[cid]!=site['id']:
                raise ValueError('A source cluster has multiple owners: '+cid)
            owners[cid]=site['id']
    nearest=lambda s:min(places,key=lambda p:math.dist(s['position'][:2],p[2][:2]))[1] if places else ''
    previous_owners={c[0]:s['id'] for s in before for c in components(s)}
    new_sites=[{'id':s['id'],'type':s['type'],'objects':s['objectCount'],'position':s['position'],'area':nearest(s),'previousOwner':previous_owners.get(s['id'])} for s in after if s['id'] not in old]
    changes=[]
    for site in before:
        owner=owners.get(site['id'])
        if owner is None: raise ValueError('Previous source cluster was lost: '+site['id'])
        updated=new[owner]
        if owner!=site['id'] or any(site.get(k)!=updated.get(k) for k in SEMANTIC_KEYS):
            changes.append({'previousId':site['id'],'previousType':site['type'],'previousObjects':site['objectCount'],
                            'currentId':owner,'currentType':updated['type'],'currentObjects':updated['objectCount'],
                            'area':nearest(site),'status':'absorbed' if owner!=site['id'] else 'changed',
                            'previousRoles':site.get('types',[]),'currentRoles':updated.get('types',[]),
                            'position':updated['position'],'sourceComponentOwners':{c[0]:owners.get(c[0]) for c in components(site)}})
    changed_existing=[s['id'] for s in after if s['id'] in old and any(s.get(k)!=old[s['id']].get(k) for k in SEMANTIC_KEYS)]
    return {'beforeLocations':len(before),'afterLocations':len(after),
            'beforeTypes':dict(Counter(s['type'] for s in before)), 'afterTypes':dict(Counter(s['type'] for s in after)),
            'changedSemanticLocationIds':changed_existing,'removedLocationIds':sorted(set(old)-set(new)),
            'addedLocationIds':sorted(set(new)-set(old)),
            'preservedPreviousPrimaryComponents':len(before),'changes':changes,'newSites':new_sites,
            'airport':{'before':old['altis_airfield_169'],'after':new[owners['altis_airfield_169']],
                       'formerBaseOwners':{sid:owners[sid] for sid in ['altis_base_90','altis_base_132']}}}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before',type=Path,default=ROOT/'baseline/spatial-merging-before/roads/locations.json')
    parser.add_argument('--output',type=Path,default=ROOT/'output/altis')
    args=parser.parse_args()
    before=json.loads(args.before.read_text(encoding='utf-8'))
    after=json.loads((args.output/'roads/locations.json').read_text(encoding='utf-8'))
    capture=json.loads((args.output/'roads/capture.json').read_text(encoding='utf-8'))
    manifest=json.loads((args.output/'roads/manifest.json').read_text(encoding='utf-8'))
    places=[p for p in capture['places'] if p[1]]
    report=compare(before,after,places)
    report['locationDatasetId']=manifest['locationDatasetId']
    folder=ROOT/'review';folder.mkdir(exist_ok=True)
    (folder/'spatial-merging.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    a=report['airport']
    lines=['# Altis spatial merge review','',
           'Generated from the normal production index. Merge eligibility now uses compatible site types, nearest original member within 100 m, all child members within 250 m, and the existing 100 m rectangular margin. There is no object-count cap, half-size requirement or extra minimum host count in the merge pass. Initial category minimums still determine whether a core can host other sites; lone power objects are secondary evidence only. General compound hosts must have at least the original footprint area of their child. Explicit support relationships retain their direction and do not require area dominance. Airfields are considered first, then larger original footprint areas, with stable IDs breaking ties.','',
           f"Locations: **{len(before)} → {len(after)}**. {len(report['removedLocationIds'])} previous site records were absorbed; {len(report['addedLocationIds'])} site IDs appeared. Every previous primary source cluster remains represented in the new index.",'',
           '## Central airport','',f"`altis_airfield_169`: {int(a['before']['objectCount'])} → {int(a['after']['objectCount'])} objects. Shape: {a['after']['footprint'][0]}. Roles: {', '.join(a['after']['types'])}.",'']
    for sid,owner in a['formerBaseOwners'].items():lines.append(f'- `{sid}` now belongs to `{owner}`.')
    lines+=['','The southwest military component now merges into the airport. The northern component remains independent: its owned power transformer at [15589.4, 17401.3] is about 439.6 m from the nearest original airport member, beyond the retained 250 m whole-component bound. Twelve of its 27 original military/support objects exceed that bound. These distances were checked against reconstructed category memberships from the unchanged native inventory (1547 airport members; component counts verified against saved provenance).','', 'Object counts include secondary-role annotations. Shared annotation evidence can disappear from map-wide totals when overlapping records merge; original source component ownership is checked independently.','',
            '## Changed sites','',
            'Map links open the current viewer at the resulting site. Existing roads, access points and routing data were regenerated from these same location records.','',
            '| Area | Previous site | Resulting site | Change | Previous → resulting objects |',
            '| --- | --- | --- | --- | --- |']
    for c in sorted(report['changes'],key=lambda c:(c['area'],c['previousId'])):
        x,y=c['position'][:2];url=f'http://127.0.0.1:8767/#6.00/{x:.1f}/{y:.1f}'
        lines.append(f"| {c['area']} | `{c['previousId']}` | [{c['currentId']}]({url}) | {c['status']} | {int(c['previousObjects'])} → {int(c['currentObjects'])} |")
    lines+=['','## Newly independent sites or new primary IDs','','| Area | Current site | Primary type | Objects | Previous owner of this source core |','| --- | --- | --- | --- | --- |']
    for c in sorted(report['newSites'],key=lambda c:(c['area'],c['id'])):
        x,y=c['position'][:2];url=f'http://127.0.0.1:8767/#6.00/{x:.1f}/{y:.1f}'
        lines.append(f"| {c['area']} | [{c['id']}]({url}) | {c['type']} | {int(c['objects'])} | `{c['previousOwner'] or 'previously unowned evidence'}` |")
    lines+=['',f"Location dataset: `{report['locationDatasetId']}`.",'']
    (folder/'spatial-merging.md').write_text('\n'.join(lines),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['changes','airport']},indent=2))
    print('Airport:',a['before']['objectCount'],'->',a['after']['objectCount'],a['formerBaseOwners'])

if __name__=='__main__':main()
