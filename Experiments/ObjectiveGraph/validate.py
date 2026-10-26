"""Independent reference validation of browser multi-origin routing against heap Dijkstra."""
import json,heapq,math,random,subprocess,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parent
p=ROOT.parent/'RoadNetwork/output/altis'
r=json.loads((p/'runtime.json').read_text())
script="""const fs=require('fs'),vm=require('vm');const c={window:{}};vm.runInNewContext(fs.readFileSync(process.argv[1],'utf8'),c);const d=c.window.OBJECTIVE_DATA;const api=require(process.argv[2]);const origins=JSON.parse(process.argv[3]);let out=[];for(const policy of ['distance','road'])for(const i of origins){let s=api.search(d.runtime,i,policy);out.push({i,policy,costs:s.targets.map(t=>Number.isFinite(t.cost)?t.cost:null),routes:s.targets.map((t,j)=>Number.isFinite(t.cost)&&j%13===0?{j,result:api.route(d.runtime,s,j)}:null).filter(Boolean)});}console.log(JSON.stringify(out));"""
origins=random.Random(71).sample(range(len(r['locations'])),10)
rows=json.loads(subprocess.check_output([shutil.which('node'),'-e',script,str(ROOT/'viewer/data.js'),str(ROOT/'viewer/graph.js'),json.dumps(origins)],text=True))
checks=0;route_checks=0
for row in rows:
 weight={'MAIN ROAD':1,'ROAD':1.2,'TRACK':1.8,'TRAIL':2.5};prefer=row['policy']=='road';gw=3 if prefer else 1
 d=[math.inf]*len(r['nodes']);queue=[]
 for i in r['attachmentsByLocation'][row['i']]:
  a=r['attachments'][i];cost=a[5]*gw+a[6]
  if cost<d[a[2]]:d[a[2]]=cost;heapq.heappush(queue,(cost,a[2]))
 while queue:
  cost,at=heapq.heappop(queue)
  if cost!=d[at]:continue
  for nxt,ei in r['adjacency'][at]:
   e=r['edges'][ei];w=max((weight.get(t,2) for t in r['attributes'][e[4]]['roadTypes']),default=1) if prefer else 1
   value=cost+e[2]*w
   if value<d[nxt]:d[nxt]=value;heapq.heappush(queue,(value,nxt))
 for j,actual in enumerate(row['costs']):
  expected=min((d[r['attachments'][a][2]]+r['attachments'][a][5]*gw+r['attachments'][a][6] for a in r['attachmentsByLocation'][j]),default=math.inf)
  assert actual is None if math.isinf(expected) else abs(actual-expected)<1e-7,(row['i'],j,actual,expected)
  checks+=1
 for entry in row['routes']:
  route=entry['result'];a=r['attachments'][route['source']];b=r['attachments'][route['target']]
  assert a[1]==row['i'] and b[1]==entry['j']
  at=a[2];distance=0;inside={}
  for eid,direction in route['path']:
   e=r['edges'][eid];assert at==(e[0] if direction==1 else e[1]);at=e[1] if direction==1 else e[0];distance+=e[2]
   for ci in r['corridorsByEdge'][eid]:
    c=r['corridors'][ci]
    for lo,hi in c[4]:inside[str(c[0])]=inside.get(str(c[0]),0)+hi-lo
  assert at==b[2] and abs(distance-route['road'])<1e-7
  assert inside==route['inside'];route_checks+=1
summary=json.loads((ROOT/'output/graph-summary.json').read_text())
assert summary['objectives']==len(r['locations'])
assert sum(summary['accessCounts'].values())==len(r['locations'])
report=dict(status='passed',objectivePolicyCostsCompared=checks,pathsAndFootprintOverlapsChecked=route_checks,origins=10,policies=2,sourceRuntimeSHA256=summary['runtimeSHA256'])
(ROOT/'output/validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
