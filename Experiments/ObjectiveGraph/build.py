"""Build a display projection from the existing Altis runtime strategic index."""
import json, hashlib, shutil
from shortest import build_routes, MAX_GAP, MAX_ROUTE
from pathlib import Path
from proximity import links as proximity_links, closest
ROOT=Path(__file__).resolve().parent
SOURCE=ROOT.parent/'RoadNetwork'
def build():
    p=SOURCE/'output/altis'
    read=lambda n:json.loads((p/(n+'.json')).read_text())
    r=read('runtime'); assert r['schemaVersion']==2
    locations={s['id']:s for s in read('locations')}
    places=[s for s in read('capture')['places'] if s[1] and s[3] in {'NameVillage','NameCity','NameCityCapital'}]
    sites=[]
    for i,name in enumerate(r['locations']):
        s=locations[name]; near=min(places,key=lambda v:sum((v[2][j]-s['position'][j])**2 for j in range(2)))
        town=near[1]; kind=s['type']; roles=s.get('types',[kind])
        title=('Airfield' if 'air' in roles else kind.title())+' / '+town
        entries=[r['attachments'][a] for a in r['attachmentsByLocation'][i]]
        access='inlet' if any(a[3]=='boundary-inlet' for a in entries) else 'strong' if any(a[4]=='strong' for a in entries) else 'secondary' if entries else 'none'
        sites.append(dict(id=name,label=title,type=kind,roles=roles,position=s['position'][:2],size=s['size'],footprint=s['footprint'],access=access,attachments=len(entries),gap=min((a[5] for a in entries),default=None),degree=0))
    pairs={}
    for ci,c in enumerate(r['connections']):
        a,b=r['attachments'][c[0]],r['attachments'][c[1]]
        if a[1]==b[1]:continue
        key=tuple(sorted((a[1],b[1])))
        cost=c[2]+a[5]+b[5]+a[6]+b[6]
        pair=pairs.setdefault(key,dict(a=key[0],b=key[1],count=0,cost=cost,connection=ci))
        pair['count']+=1
        if cost<pair['cost']:pair.update(cost=cost,connection=ci)
    for (a,b),pair in pairs.items():
        sites[a]['degree']+=1;sites[b]['degree']+=1
        pair['gapM']=closest(sites[a]['footprint'],sites[b]['footprint'])[0]
    nearby=proximity_links(sites)
    strategic=build_routes(r,sites)
    envelope=dict(maximumGapM=MAX_GAP,maximumRouteM=MAX_ROUTE)
    geometry={e['id']:e['geometryASL'] for e in read('routing-graph')['edges']}
    data=dict(strategicLinks=strategic,strategicEnvelope=envelope,runtime=r,sites=sites,links=list(pairs.values()),proximityLinks=nearby,proximityMaximumM=2000,geometry=[geometry[e] for e in r['edgeIds']],basemap=read('manifest')['basemap'])
    v=ROOT/'viewer'
    (v/'data.js').write_text('window.OBJECTIVE_DATA='+json.dumps(data,separators=(',',':'))+';',encoding='utf-8')
    shutil.copytree(SOURCE/'viewer/vendor',v/'vendor',dirs_exist_ok=True)
    shutil.copyfile(SOURCE/'viewer/altis-overview.png',v/'altis-overview.png')
    report=dict(strategicRouteCandidates=len(strategic),strategicEnvelope=envelope,proximityCandidates=len(nearby),defaultProximityM=1000,objectives=len(sites),objectiveLinks=len(pairs),attachments=len(r['attachments']),runtimeSHA256=hashlib.sha256((p/'runtime.json').read_bytes()).hexdigest(),dependencies=r['dependencies'],accessCounts={k:sum(s['access']==k for s in sites) for k in ['inlet','strong','secondary','none']})
    (ROOT/'output/objective-graph.json').write_text(json.dumps(dict(schemaVersion=3,strategicLinks=strategic,strategicEnvelope=envelope,proximityLinks=nearby,proximityMaximumM=2000,dependencies=r['dependencies'],nodes=sites,links=list(pairs.values()),semantics='Undirected display projection of sparse baseline connections; route on attachment graph, never transit through objective nodes'),separators=(',',':')))
    (ROOT/'output/graph-summary.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    return data
if __name__=='__main__':build()
