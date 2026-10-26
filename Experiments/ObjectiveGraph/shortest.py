"""Shortest objective-pair routes over full indexed topology; objectives never stop search."""
import heapq,math
from proximity import closest
MAX_GAP=5000
MAX_ROUTE=10000

def build_routes(r,sites):
    candidates={}
    for a in range(len(sites)):
        for b in range(a+1,len(sites)):
            gap=closest(sites[a]['footprint'],sites[b]['footprint'])[0]
            if gap<=MAX_GAP:candidates[a,b]=gap
    out=[]
    for a in range(len(sites)):
        targets=[b for x,b in candidates if x==a]
        if not targets:continue
        dist={};parents={};origin={};queue=[]
        for ai in r['attachmentsByLocation'][a]:
            at=r['attachments'][ai];cost=at[5]+at[6];node=at[2]
            if cost<dist.get(node,math.inf):dist[node]=cost;origin[node]=ai;heapq.heappush(queue,(cost,node))
        while queue:
            cost,node=heapq.heappop(queue)
            if cost!=dist[node]:continue
            if cost>MAX_ROUTE:break
            for nxt,eid in r['adjacency'][node]:
                value=cost+r['edges'][eid][2]
                if value<=MAX_ROUTE and value<dist.get(nxt,math.inf):
                    dist[nxt]=value;parents[nxt]=(node,eid);origin[nxt]=origin[node];heapq.heappush(queue,(value,nxt))
        for b in targets:
            choices=[(dist.get(r['attachments'][bi][2],math.inf)+r['attachments'][bi][5]+r['attachments'][bi][6],bi) for bi in r['attachmentsByLocation'][b]]
            if not choices:continue
            cost,bi=min(choices)
            if cost>MAX_ROUTE:continue
            node=r['attachments'][bi][2];ai=origin[node];path=[]
            while node in parents:
                prev,eid=parents[node];path.append([eid,1 if r['edges'][eid][0]==prev else -1]);node=prev
            path.reverse();road=sum(r['edges'][eid][2] for eid,_ in path);inside={}
            for eid,_ in path:
                for ci in r['corridorsByEdge'][eid]:
                    row=r['corridors'][ci]
                    for lo,hi in row[4]:inside[row[0]]=inside.get(row[0],0)+hi-lo
            out.append(dict(a=a,b=b,cost=cost,gapM=candidates[a,b],route=[ai,bi,road,path],overlapM=inside,viaObjectives=[i for i in sorted(inside) if i not in (a,b)],kind='shortest-physical-route'))
    return out
