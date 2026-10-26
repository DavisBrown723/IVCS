"""Find every road crossing of a site's saved footprint.

Interface: attachments(normalized_roads, saved_sites, graph_connections) returns
boundary inlets and per-site coverage. It neither changes roads nor clusters.
Only ordinary engine links can bridge gaps between observed section chords.
"""
from collections import defaultdict
import math

ACCESS_VERSION = "boundary-inlets-1"
ACCESS_SETTINGS = {"method": ACCESS_VERSION, "nearbySearchM": 150,
                   "contactMergeM": 0.05, "contactHeightM": 0.5}

def distance(a,b,dimensions=2):
    return math.sqrt(sum((a[i]-b[i])**2 for i in range(dimensions)))

def footprint(site):
    return site.get("footprint", ["circle",site["position"],[site["size"]]*2,0])


def to_local(shape, point):
    _, c, _, angle = shape
    cosine, sine = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    dx, dy = point[0]-c[0],point[1]-c[1]
    return dx*cosine-dy*sine, dx*sine+dy*cosine


def from_local(shape, point):
    _, c, _, angle = shape
    cosine, sine = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    return [c[0]+point[0]*cosine+point[1]*sine,c[1]-point[0]*sine+point[1]*cosine]


def nearest_in_shape(shape, point):
    if shape[0] == "circle":
        gap = distance(shape[1], point)
        if gap <= shape[2][0]: return list(point[:2])
        fraction = shape[2][0]/gap
        return [shape[1][i]+(point[i]-shape[1][i])*fraction for i in range(2)]
    u,v = to_local(shape,point); hx,hy = shape[2]
    return from_local(shape,[max(-hx,min(hx,u)),max(-hy,min(hy,v))])


def road_candidate(shape, road):
    a,b = road["beginASL"],road["endASL"]
    dx,dy = b[0]-a[0],b[1]-a[1]; denom=dx*dx+dy*dy
    t = 0 if denom == 0 else max(0,min(1,((shape[1][0]-a[0])*dx+(shape[1][1]-a[1])*dy)/denom))
    samples = {0.0,1.0,t}
    if shape[0] == "rectangle":
        u,v = to_local(shape,a); u2,v2 = to_local(shape,b)
        for value,delta,extent in [(u,u2-u,shape[2][0]),(v,v2-v,shape[2][1])]:
            if abs(delta)>1e-9:
                for side in [-extent,extent]:
                    at=(side-value)/delta
                    if 0<=at<=1: samples.add(at)
        for cu in [-shape[2][0],shape[2][0]]:
            for cv in [-shape[2][1],shape[2][1]]:
                corner=from_local(shape,[cu,cv])
                if denom: samples.add(max(0,min(1,((corner[0]-a[0])*dx+(corner[1]-a[1])*dy)/denom)))
    choices=[]
    for t in sorted(samples):
        pos=[a[i]+(b[i]-a[i])*t for i in range(3)]
        target=nearest_in_shape(shape,pos)
        choices.append((distance(pos,target),distance(pos,shape[1]),pos,target))
    return min(choices)



def _interpolate(a,b,t):
    return [a[i]+(b[i]-a[i])*t for i in range(3)]


def _side(shape,p):
    if shape[0]=='circle':
        value=distance(shape[1],p)-shape[2][0]
    else:
        x,y=to_local(shape,p)
        value=max(abs(x)-shape[2][0],abs(y)-shape[2][1])
    return 1 if value < -1e-6 else -1 if value > 1e-6 else 0


def _boundary_parameters(shape,a,b):
    """Finite-segment boundary intersections; preserve both ends of through roads."""
    roots=[]
    if shape[0]=='circle':
        dx,dy=b[0]-a[0],b[1]-a[1];x,y=a[0]-shape[1][0],a[1]-shape[1][1]
        aa=dx*dx+dy*dy;bb=2*(x*dx+y*dy);cc=x*x+y*y-shape[2][0]**2
        if aa<1e-16:return []
        disc=bb*bb-4*aa*cc
        if disc>=0:
            root=math.sqrt(disc)
            roots=[(-bb-root)/(2*aa),(-bb+root)/(2*aa)]
    else:
        x,y=to_local(shape,a);u,v=to_local(shape,b);dx,dy=u-x,v-y;hx,hy=shape[2]
        for start,delta,extent,other,other_delta,other_extent in [
            (x,dx,hx,y,dy,hy),(y,dy,hy,x,dx,hx)]:
            if abs(delta)>1e-12:
                for bound in [-extent,extent]:
                    t=(bound-start)/delta
                    if abs(other+other_delta*t)<=other_extent+1e-7:roots.append(t)
        # Collinear boundary sections can contribute endpoint contacts, not interior.
        if _side(shape,a)==0:roots.append(0)
        if _side(shape,b)==0:roots.append(1)
    valid=sorted(max(0.0,min(1.0,t)) for t in roots if -1e-9<=t<=1+1e-9)
    return [t for i,t in enumerate(valid) if i==0 or abs(t-valid[i-1])>1e-9]


def _contacts(shape,segment):
    a,b=segment['a'],segment['b'];roots=_boundary_parameters(shape,a,b)
    contacts=[];length=distance(a,b)
    for i,t in enumerate(roots):
        inside=[];outside=[]
        for limit in [roots[i-1] if i else 0,roots[i+1] if i+1<len(roots) else 1]:
            if abs(limit-t)<1e-10:continue
            sample=t+math.copysign(min(abs(limit-t)/2,30/max(length,1e-9)),limit-t)
            pos=_interpolate(a,b,sample);side=_side(shape,pos)
            if side==1:inside.append(pos)
            elif side==-1:outside.append(pos)
        if inside or outside:
            contacts.append({'position':_interpolate(a,b,t),'inside':inside,'outside':outside,
                             'roadIds':set(segment['roadIds']),'segmentId':segment['id'],
                             'kind':segment['kind'],'parameter':t})
    return contacts


def _closest_points(a,b,c,d):
    """Closest points between finite 3D chords, including endpoints and intersections."""
    u=[b[i]-a[i] for i in range(3)];v=[d[i]-c[i] for i in range(3)];w=[a[i]-c[i] for i in range(3)]
    dot=lambda x,y:sum(m*n for m,n in zip(x,y))
    aa,bb,cc,dd,ee=dot(u,u),dot(u,v),dot(v,v),dot(u,w),dot(v,w)
    clamp=lambda t:max(0.0,min(1.0,t))
    choices=[]
    for s in [0.0,1.0]:choices.append((s,clamp((ee+bb*s)/cc) if cc else 0))
    for t in [0.0,1.0]:choices.append((clamp((bb*t-dd)/aa) if aa else 0,t))
    denominator=aa*cc-bb*bb
    if denominator>1e-12:
        s,t=(bb*ee-cc*dd)/denominator,(aa*ee-bb*dd)/denominator
        if 0<=s<=1 and 0<=t<=1:choices.append((s,t))
    s,t=min(choices,key=lambda st:distance(_interpolate(a,b,st[0]),_interpolate(c,d,st[1]),3))
    return _interpolate(a,b,s),_interpolate(c,d,t)


def attachments(roads,sites,connections):
    valid={r['id']:r for r in roads if r['geometryStatus']!='unavailable'}
    pairs={tuple(sorted((c['a'],c['b']))) for c in connections
           if c['accepted'] and c['a'] in valid and c['b'] in valid}
    segments=[{'id':'section:'+rid,'roadIds':[rid],'a':r['beginASL'],'b':r['endASL'],
               'kind':'road-section-crossing'} for rid,r in sorted(valid.items())]
    for a,b in sorted(pairs):
        ra,rb=valid[a],valid[b]
        p,q=_closest_points(ra['beginASL'],ra['endASL'],rb['beginASL'],rb['endASL'])
        if distance(p,q)>1e-4:
            segments.append({'id':'link:'+a+':'+b,'roadIds':[a,b],'a':p,'b':q,
                             'kind':'ordinary-link-interpolation'})
    buckets=defaultdict(list);tile=500
    for segment in segments:
        a,b=segment['a'],segment['b']
        for x in range(math.floor(min(a[0],b[0])/tile),math.floor(max(a[0],b[0])/tile)+1):
            for y in range(math.floor(min(a[1],b[1])/tile),math.floor(max(a[1],b[1])/tile)+1):
                buckets[x,y].append(segment)
    results=[];coverage=[]
    for site in sorted(sites,key=lambda s:s['id']):
        shape=footprint(site);c=shape[1]
        radius=(shape[2][0] if shape[0]=='circle' else math.hypot(*shape[2]))+ACCESS_SETTINGS['nearbySearchM']
        possible={}
        for x in range(math.floor((c[0]-radius)/tile),math.floor((c[0]+radius)/tile)+1):
            for y in range(math.floor((c[1]-radius)/tile),math.floor((c[1]+radius)/tile)+1):
                for segment in buckets[x,y]:possible[segment['id']]=segment
        contacts=[];gaps=[]
        for segment in sorted(possible.values(),key=lambda s:s['id']):
            if segment['kind']=='road-section-crossing':
                gap=road_candidate(shape,valid[segment['roadIds'][0]])[0]
                if gap<=ACCESS_SETTINGS['nearbySearchM']:gaps.append(gap)
            contacts.extend(_contacts(shape,segment))
        # Join only coincident contacts supported by the SAME road or an ordinary
        # connection. Never merge entrances by compass sector or broad proximity.
        parents=list(range(len(contacts)))
        def find(i):
            while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
            return i
        for i,a in enumerate(contacts):
            for j,b in enumerate(contacts[:i]):
                if distance(a['position'],b['position'])>ACCESS_SETTINGS['contactMergeM']:continue
                if abs(a['position'][2]-b['position'][2])>ACCESS_SETTINGS['contactHeightM']:continue
                related=a['roadIds']&b['roadIds'] or any(tuple(sorted((x,y))) in pairs for x in a['roadIds'] for y in b['roadIds'])
                if related:parents[find(i)]=find(j)
        groups=defaultdict(list)
        for i,contact in enumerate(contacts):groups[find(i)].append(contact)
        inlets=[]
        for group in groups.values():
            interior=[p for g in group for p in g['inside']]
            exterior=[p for g in group for p in g['outside']]
            if not interior or not exterior:continue
            pos=group[0]['position']
            road_ids=sorted(set().union(*(g['roadIds'] for g in group)))
            primary=min(road_ids,key=lambda rid:(distance(valid[rid]['positionASL'],pos),rid))
            refs=[]
            for rid in road_ids:
                refs.extend(dict(ref,roadId=rid) for ref in valid[rid]['graphRefs'])
            bearing=math.degrees(math.atan2(pos[0]-c[0],pos[1]-c[1]))%360
            inlets.append({'locationId':site['id'],'roadId':primary,'roadIds':road_ids,
                           'componentId':valid[primary]['componentId'],'positionASL':pos,
                           'insideASL':interior[0],'outsideASL':exterior[0],
                           'insideArmsASL':interior,'outsideArmsASL':exterior,'bearingDegrees':bearing,
                           'kind':'boundary-inlet','status':'candidate','footprintGapM':0,
                           'graphRefs':refs,'graphReferenceMethod':'source road-section centres; crossing offsets not projected onto compressed graph',
                           'evidence':sorted({g['kind'] for g in group}),
                           'sources':[{'segmentId':g['segmentId'],'parameter':g['parameter']} for g in group],
                           'unchecked':['water','slope','fences','entrances','vehicle-traversal','vertical-access']})
        inlets.sort(key=lambda a:(a['bearingDegrees'],a['positionASL'],a['roadId']))
        for i,entry in enumerate(inlets):
            entry['id']=site['id']+f'-inlet-{i+1:03d}';entry['number']=i+1
        results.extend(inlets)
        intersecting=sum(g<1e-6 for g in gaps)
        status='boundary-inlets' if inlets else 'roads-without-crossing' if intersecting else 'nearby-roads-only' if gaps else 'no-nearby-roads'
        coverage.append({'locationId':site['id'],'nearbySections':len(gaps),'intersectingSections':intersecting,
                         'candidateCount':len(inlets),'inletCount':len(inlets),
                         'interpolatedInlets':sum('road-section-crossing' not in a['evidence'] for a in inlets),
                         'nearestRoadGapM':min(gaps) if gaps else None,
                         'status':status,'boundaryContacts':len(contacts),'method':ACCESS_VERSION})
    return results,coverage
