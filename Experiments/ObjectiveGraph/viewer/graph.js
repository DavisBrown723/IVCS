/* Pure runtime queries. Display-level objective links never participate in routing. */
(function(root){
function search(r,site,policy){
 const n=r.nodes.length,d=Array(n).fill(Infinity),parent=Array(n).fill(null),origin=Array(n).fill(-1),done=new Uint8Array(n),roadMode=policy==='road',gapWeight=roadMode?3:1;
 for(const ai of r.attachmentsByLocation[site]){const a=r.attachments[ai],cost=a[5]*gapWeight+a[6];if(cost<d[a[2]]){d[a[2]]=cost;origin[a[2]]=ai;}}
 // A bounded dense Dijkstra on ~5k nodes; sufficient for this interactive prototype.
 for(let step=0;step<n;step++){let at=-1,best=Infinity;for(let j=0;j<n;j++)if(!done[j]&&d[j]<best){at=j;best=d[j];}if(at<0)break;done[at]=1;
  for(const [next,eid] of r.adjacency[at]){const e=r.edges[eid],types=r.attributes[e[4]].roadTypes;const w=roadMode?Math.max(...types.map(t=>({'MAIN ROAD':1,ROAD:1.2,TRACK:1.8,TRAIL:2.5})[t]||2)):1;let cost=best+e[2]*w;if(cost<d[next]){d[next]=cost;parent[next]=[at,eid];origin[next]=origin[at];}}
 }
 const targets=r.attachmentsByLocation.map(list=>{let best={cost:Infinity,attachment:-1};for(const ai of list){const a=r.attachments[ai],cost=d[a[2]]+a[5]*gapWeight+a[6];if(cost<best.cost)best={cost,attachment:ai};}return best;});
 return {d,parent,origin,targets,site,policy};
}
function route(r,s,target){const t=s.targets[target];if(t.attachment<0)return null;let at=r.attachments[t.attachment][2],source=s.origin[at],path=[];while(s.parent[at]){const [prev,eid]=s.parent[at],e=r.edges[eid];path.push([eid,e[0]===prev?1:-1]);at=prev;}path.reverse();let inside={};for(const [eid] of path)for(const ri of r.corridorsByEdge[eid]){const row=r.corridors[ri];for(const [lo,hi] of row[4])inside[row[0]]=(inside[row[0]]||0)+hi-lo;}
 return {source,target:t.attachment,path,cost:t.cost,road:path.reduce((sum,[i])=>sum+r.edges[i][2],0),inside};}
const api={search,route};if(typeof module!=='undefined')module.exports=api;root.ObjectiveGraph=api;
})(typeof window!=='undefined'?window:globalThis);
