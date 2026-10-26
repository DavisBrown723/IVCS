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
    parser.add_argument('--before',type=Path,default=ROOT/'baseline/containment-before/roads/locations.json')
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
    a=report['airport']
    lines=['# Altis containment and support review','',
           'Compatible cores merge when every member is contained in the consolidated host core footprint, without requiring individual-object proximity. A core overlapping the boundary can also merge when its nearest original member is within 100 m and every member remains within the existing 100 m footprint margin. Disjoint nearby sites retain the 100 m nearest-member and 250 m whole-core bounds. Typed support is reserved without attaching it, cores consolidate, and support is then reassessed against surviving consolidated cores. Rejected support remains independent when it meets its category minimum. Core footprints refit after core merges and passes repeat until stable. Typed support cannot expand eligibility; object-distance checks retain original host members. No object-count cap or count ratio is used.','',

           f"Locations: **{len(before)} → {len(after)}**. {len(report['removedLocationIds'])} previous site records were absorbed; {len(report['addedLocationIds'])} site IDs appeared. Every previous primary source cluster remains represented in the new index.",'',
           '## Central airport','',f"`altis_airfield_169`: {int(a['before']['objectCount'])} → {int(a['after']['objectCount'])} objects. Shape: {a['after']['footprint'][0]}. Roles: {', '.join(a['after']['types'])}.",'']
    for sid,owner in a['formerBaseOwners'].items():lines.append(f'- `{sid}` now belongs to `{owner}`.')
    old_north=next(s for s in before if s['id']=='altis_base_132')
    owners={c[0]:s['id'] for s in after for c in components(s)}
    report['airport']['northernComponentOwners']={c[0]:owners.get(c[0]) for c in components(old_north)}
    lines+=['','The northern military core is evaluated independently of its previous support. Its buildings extend about 175 m beyond the initial airport core rectangle, compared with about 59 m beyond the previously displayed rectangle. Containment now follows consolidated core geometry, excluding typed support. The northern military core still reaches about 128 m outside the consolidated core footprint, beyond the 100 m overlap margin, so it remains independent. Five of its fourteen recorded military buildings lie outside even the final displayed airport rectangle (maximum gap about 62 m). Its support attachments are no longer the deciding factor. The containment regression uses genuinely contained sparse-core fixtures; this real base is a partial-overlap case.','', 'Previous northern-base components after reassessment:','']
    for component,owner in report['airport']['northernComponentOwners'].items():
        lines.append(f'- `{component}`: `{owner}`.' if owner else f'- `{component}`: unassigned evidence retained in the inventory (below standalone category minimum).')
    (folder/'containment-merging.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    lines+=['','Object counts include secondary-role annotations. Overlapping annotation evidence is deduplicated when sites merge. Original source components remain traceable.','',
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
    (folder/'containment-merging.md').write_text('\n'.join(lines),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ['changes','airport']},indent=2))
    print('Airport:',a['before']['objectCount'],'->',a['after']['objectCount'],a['formerBaseOwners'])

if __name__=='__main__':main()
