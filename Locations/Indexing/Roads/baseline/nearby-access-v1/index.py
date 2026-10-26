"""Offline road topology and access indexing. Python 3.9+, standard library only."""
import argparse
from collections import Counter, defaultdict, deque
import hashlib
import json
import math
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
VERSION = "road-prototype-1"
SETTINGS = {"connectivity": "ordinary-undirected", "accessRangeM": 150,
            "accessSeparationM": 65, "accessSectors": 12, "maximumAccessCandidates": 12}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, separators=(",", ":"), ensure_ascii=True, allow_nan=False) + "\n", encoding="utf-8")


def distance(a, b, dimensions=2):
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(dimensions)))


def capture(path):
    rows = defaultdict(list)
    buffers = defaultdict(str)
    source = path.read_text(errors="replace")
    if "[IVCS TASK TEST] DONE passed=1 failed=0" not in source:
        raise ValueError("Incomplete native extraction")
    if re.search(r"Error in expression|Error Undefined variable|Error Missing|Error Type", source):
        raise ValueError("Native extraction contains a script error")
    for line in source.splitlines():
        match = re.search(r"IVCS_RN_(META|ROAD|PLACE)_(PART|END)(?: (.*))?$", line)
        if not match:
            continue
        kind, state, part = match.groups()
        if state == "PART":
            buffers[kind] += part
        else:
            rows[kind].append(json.loads(buffers.pop(kind).replace("\\", "\\\\")))
    if any(buffers.values()) or len(rows["META"]) != 1:
        raise ValueError("Truncated or ambiguous extraction")
    if rows["META"][0][-1]:
        raise ValueError("Probe captures cannot be promoted as complete road data")
    return {"meta": rows["META"][0], "roads": rows["ROAD"], "places": rows["PLACE"]}


def load_locations(path):
    result = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"_locations pushBack \(createHashMapFromArray (.*)\);", line)
        if match:
            result.append(dict(json.loads(match[1].replace("\\", "\\\\"))))
    if not result:
        raise ValueError("No saved location records")
    return result


def normalize(raw):
    def key(row):
        info = row[3]
        return (tuple(row[2]), tuple(info[6]), tuple(info[7]), info[0], row[1])
    ordered = sorted(raw, key=key)
    ids = {int(row[0]): f"r{i:06d}" for i, row in enumerate(ordered)}
    if len(ids) != len(raw):
        raise ValueError("Duplicate capture IDs")
    result = []
    for row in ordered:
        n, descriptor, pos, info, ordinary, extended = row
        if len(info) < 9:
            raise ValueError("Unsupported getRoadInfo result")
        for point in [pos, info[6], info[7]]:
            if len(point) != 3 or not all(isinstance(v, (int, float)) and math.isfinite(v) for v in point):
                raise ValueError("Invalid ASL geometry")
        bridge = bool(info[8])
        valid_geometry = distance(info[6], info[7], 3) > 0.01
        centre = [(info[6][i]+info[7][i])/2 for i in range(3)] if valid_geometry else pos
        section = {"id": ids[int(n)], "sourceRef": descriptor, "positionASL": centre, "sourcePositionASL": pos,
                   "geometryStatus": "endpoints-observed" if valid_geometry else "unavailable",
                   "beginASL": info[6] if valid_geometry else pos, "endASL": info[7] if valid_geometry else pos, "type": info[0], "bridge": bridge,
                   "ordinary": sorted({ids[int(x)] for x in ordinary if int(x) != int(n)}),
                   "extended": sorted({ids[int(x)] for x in extended if int(x) != int(n)}),
                   "length2dM": distance(info[6], info[7]), "length3dM": distance(info[6], info[7], 3),
                   "attributeStatus": "limited-bridge-metadata" if bridge else "engine-observed"}
        if not bridge:
            if info[1] > 0:
                section["widthM"] = info[1]
            section["pedestrian"] = bool(info[2])
        result.append(section)
    return result


def network(roads):
    by_id = {r["id"]: r for r in roads}
    normal = {(r["id"], n) for r in roads for n in r["ordinary"]}
    extended = {(r["id"], n) for r in roads for n in r["extended"]}
    pairs = sorted({tuple(sorted(pair)) for pair in normal | extended})
    adjacency = {r["id"]: set() for r in roads if r["geometryStatus"] != "unavailable"}
    links = []
    uncertain_roads = set()
    for a, b in pairs:
        reciprocal = (a, b) in normal and (b, a) in normal
        observed = (a, b) in normal or (b, a) in normal
        valid_geometry = a in adjacency and b in adjacency
        accepted = observed and valid_geometry
        evidence = ("ordinary-reciprocal" if reciprocal else "ordinary-one-sided" if observed else "extended-only") if valid_geometry else "unavailable-geometry"
        links.append({"a": a, "b": b, "evidence": evidence, "accepted": accepted,
                      "ordinaryDirections": [(x, y) for x, y in [(a,b),(b,a)] if (x,y) in normal],
                      "extendedDirections": [(x, y) for x, y in [(a,b),(b,a)] if (x,y) in extended],
                      "length2dM": distance(by_id[a]["positionASL"], by_id[b]["positionASL"]),
                      "length3dM": distance(by_id[a]["positionASL"], by_id[b]["positionASL"], 3)})
        if accepted:
            adjacency[a].add(b); adjacency[b].add(a)
        if evidence != "ordinary-reciprocal":
            uncertain_roads.update([a, b])
    components = []
    component_of = {}
    for first in sorted(adjacency):
        if first in component_of:
            continue
        cid = f"c{len(components):05d}"
        pending = [first]; members = []
        component_of[first] = cid
        while pending:
            at = pending.pop(); members.append(at)
            for nxt in sorted(adjacency[at]):
                if nxt not in component_of:
                    component_of[nxt] = cid; pending.append(nxt)
        components.append({"id": cid, "roadIds": sorted(members), "roadCount": len(members)})
    def attributes(rid):
        r = by_id[rid]
        return r["type"], r.get("widthM"), r.get("pedestrian"), r["bridge"]
    retained = set()
    reasons = {}
    for rid, neighbours in adjacency.items():
        why = []
        if len(neighbours) == 0: why.append("isolated")
        elif len(neighbours) == 1: why.append("dead-end")
        elif len(neighbours) > 2: why.append("junction")
        if rid in uncertain_roads: why.append("connection-evidence")
        if by_id[rid]["bridge"]: why.append("bridge")
        if any(attributes(n) != attributes(rid) for n in neighbours): why.append("attribute-change")
        if why: retained.add(rid); reasons[rid] = why
    # A ring with no junction retains two anchors and two parallel edges.
    for group in components:
        if not any(r in retained for r in group["roadIds"]):
            members = group["roadIds"]
            for rid in {members[0], members[len(members)//2]}:
                retained.add(rid); reasons[rid] = ["loop-anchor"]
    nodes = [{"id": "n-"+rid, "roadId": rid, "positionASL": by_id[rid]["positionASL"],
              "componentId": component_of[rid], "degree": len(adjacency[rid]), "reasons": reasons[rid]}
             for rid in sorted(retained)]
    visited = set(); edges = []; references = defaultdict(list)
    for start in sorted(retained):
        for nxt in sorted(adjacency[start]):
            pair = tuple(sorted([start, nxt]))
            if pair in visited: continue
            path = [start, nxt]; visited.add(pair)
            while path[-1] not in retained:
                options = adjacency[path[-1]] - {path[-2]}
                if len(options) != 1: raise AssertionError("Unsafe chain compression")
                n = next(iter(options)); visited.add(tuple(sorted([path[-1], n]))); path.append(n)
            coords = [by_id[r]["positionASL"] for r in path]
            offsets = [0.0]
            for a,b in zip(coords,coords[1:]): offsets.append(offsets[-1] + distance(a,b,3))
            eid = f"e{len(edges):06d}"
            edge = {"id": eid, "from": "n-"+start, "to": "n-"+path[-1], "roadIds": path,
                    "geometryASL": coords, "sourceOffsetsM": offsets,
                    "length3dM": offsets[-1], "length2dM": sum(distance(a,b) for a,b in zip(coords,coords[1:])),
                    "componentId": component_of[start], "type": by_id[path[len(path)//2]]["type"],
                    "geometryMethod": "road-section-centres; approximate strategic connector"}
            edges.append(edge)
            for rid, offset in zip(path, offsets): references[rid].append({"edgeId": eid, "offsetM": offset})
    assert len(visited) == sum(len(ns) for ns in adjacency.values()) // 2
    for r in roads:
        r["componentId"] = component_of.get(r["id"], "unmapped")
        r["degree"] = len(adjacency.get(r["id"], []))
        r["graphRefs"] = references[r["id"]]
        if r["id"] in retained: r["nodeId"] = "n-"+r["id"]
    return {"nodes": nodes, "edges": edges, "connections": links, "components": components}


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


def attachments(roads, sites):
    buckets=defaultdict(list); tile=500
    for road in roads:
        if road["geometryStatus"] == "unavailable": continue
        a,b=road["beginASL"],road["endASL"]
        for x in range(math.floor(min(a[0],b[0])/tile),math.floor(max(a[0],b[0])/tile)+1):
            for y in range(math.floor(min(a[1],b[1])/tile),math.floor(max(a[1],b[1])/tile)+1): buckets[x,y].append(road)
    results=[]; coverage=[]
    for site in sites:
        shape=footprint(site); c=shape[1]
        radius=(shape[2][0] if shape[0]=='circle' else math.hypot(*shape[2]))+SETTINGS['accessRangeM']
        possible={}
        for x in range(math.floor((c[0]-radius)/tile),math.floor((c[0]+radius)/tile)+1):
            for y in range(math.floor((c[1]-radius)/tile),math.floor((c[1]+radius)/tile)+1):
                for r in buckets[x,y]: possible[r['id']]=r
        ranked=[]
        for road in possible.values():
            gap,centredist,pos,target=road_candidate(shape,road)
            if gap>SETTINGS['accessRangeM']: continue
            sector=int((math.degrees(math.atan2(pos[0]-c[0],pos[1]-c[1]))%360)/360*SETTINGS['accessSectors'])
            group=(road['componentId'],sector)
            ranked.append((gap,road.get('pedestrian',False),road['type']=='HIDE',centredist,road['id'],group,pos,target))
        ranked.sort()
        chosen=[]; groups=set()
        for entry in ranked:
            if entry[5] in groups: continue
            if any(distance(entry[6],other[6])<SETTINGS['accessSeparationM'] for other in chosen): continue
            chosen.append(entry);groups.add(entry[5])
            if len(chosen)>=SETTINGS['maximumAccessCandidates']: break
        all_groups={r[5] for r in ranked}
        coverage.append({'locationId':site['id'],'nearbySections':len(ranked),'candidateCount':len(chosen),
                         'approachGroups':len(all_groups),'representedGroups':len(groups),
                         'unrepresentedGroups':len(all_groups-groups),'candidateCapReached':len(chosen)>=SETTINGS['maximumAccessCandidates']})
        for i,entry in enumerate(chosen):
            gap,_,_,_,rid,group,pos,target=entry;road=possible[rid]
            record={'id':site['id']+f'-access-{i:02d}','locationId':site['id'],'roadId':rid,
                    'componentId':road['componentId'],'sector':group[1],'positionASL':pos,'target2D':target,
                    'footprintGapM':gap,'straightLineDistanceM':gap,'graphRefs':road['graphRefs'],
                    'graphReferenceMethod':'road-section centre; approach offset is approximate',
                    'status':'candidate','evidence':['geometry-only'],
                    'unchecked':['water','slope','fences','entrances','vehicle-traversal']}
            if 'nodeId' in road: record['nodeId']=road['nodeId']
            results.append(record)
    return results,coverage


def build(raw, locations):
    if any(x['world'].lower()!=str(raw['meta'][0]).lower() for x in locations): raise ValueError('Location and road terrain mismatch')
    roads=normalize(raw['roads']); graph=network(roads)
    road_id=digest({'version':VERSION,'world':raw['meta'][:3],'policy':SETTINGS['connectivity'],'roads':roads})
    location_id=digest(locations)
    access,coverage=attachments(roads,locations)
    access_id=digest({'roads':road_id,'locations':location_id,'settings':SETTINGS,'access':access,'version':VERSION})
    for a in access:
        a['roadDatasetId']=road_id;a['locationDatasetId']=location_id
    summary={'roadSections':len(roads),'mappedSections':sum(r['geometryStatus']!='unavailable' for r in roads),'unavailableGeometry':sum(r['geometryStatus']=='unavailable' for r in roads),'connections':len(graph['connections']),
             'acceptedConnections':sum(c['accepted'] for c in graph['connections']),
             'connectionEvidence':dict(Counter(c['evidence'] for c in graph['connections'])),
             'nodes':len(graph['nodes']),'edges':len(graph['edges']),'components':len(graph['components']),
             'junctions':sum(r['degree']>2 for r in roads),'deadEnds':sum(r['degree']==1 for r in roads),
             'isolatedSections':sum(r['degree']==0 and r['geometryStatus']!='unavailable' for r in roads),'bridgeSections':sum(r['bridge'] for r in roads),
             'roadTypes':dict(Counter(r['type'] for r in roads)),
             'roadLength2dKm':sum(r['length2dM'] for r in roads)/1000,
             'locations':len(locations),'accessCandidates':len(access),'locationsWithAccess':sum(c['candidateCount']>0 for c in coverage),
             'locationCandidateCaps':sum(c['candidateCapReached'] for c in coverage),
             'zeroLengthSections':sum(r['length2dM']<0.01 for r in roads),
             'longOrdinaryLinks':sum(c['accepted'] and c['length2dM']>150 for c in graph['connections']),
             'ambiguousGeometries':sum(n-1 for n in Counter((tuple(r['positionASL']),tuple(r['beginASL']),tuple(r['endASL']),r['type']) for r in roads).values() if n>1)}
    manifest={'schemaVersion':1,'variant':VERSION,'world':raw['meta'][0],'worldSize':raw['meta'][1],
              'engine':raw['meta'][2],'roadDatasetId':road_id,'locationDatasetId':location_id,'attachmentDatasetId':access_id,
              'settings':SETTINGS,'coordinates':'Road points: metres ASL. Locations/targets: 2D, zero Z is not elevation.',
              'policy':'Ordinary links are undirected potential physical connections. Extended-only links are diagnostic, excluded from graph routes.',
              'lengthMethod':'Section endpoint chords for physical lengths; road-centre connectors for strategic graph lengths.',
              'validation':'Candidate road access only; no vehicle traversal or obstacle assessment.',
              'basemap':{'provider':'Arma3Map / jetelain','copyright':'Bohemia Interactive','url':'https://jetelain.github.io/Arma3Map/altis.html',
                         'tileUrl':'https://jetelain.github.io/Arma3Map/maps/altis/{z}/{x}/{y}.png',
                         'tileSize':212,'factorX':0.006839,'factorY':0.006836,'maxNativeZoom':6},'summary':summary}
    places=[{'id':p[0],'name':p[1],'position':p[2],'type':p[3]} for p in raw['places'] if p[1]]
    return {'manifest':manifest,'roads':roads,'graph':graph,'locations':locations,'attachments':access,'accessCoverage':coverage,'places':places}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--rpt',type=Path)
    parser.add_argument('--locations',type=Path,default=ROOT/'inputs/altis-locations.sqf')
    args=parser.parse_args()
    output=ROOT/'output/altis'
    if args.rpt:
        raw=capture(args.rpt);write_json(output/'capture.json',raw)
    else: raw=json.loads((output/'capture.json').read_text())
    locations=load_locations(args.locations)
    data=build(raw,locations)
    for name,value in [('roads',data['roads']),('graph',data['graph']),('locations',locations),('attachments',data['attachments']),('manifest',data['manifest']),('access-coverage',data['accessCoverage'])]: write_json(output/(name+'.json'),value)
    # The browser uses a compact projection, while full-precision exports remain reusable.
    fields={'id','type','positionASL','beginASL','endASL','geometryStatus','bridge','widthM','length2dM','componentId','degree','ordinary','extended','graphRefs'}
    viewer=dict(data)
    viewer['roads']=[{k:v for k,v in r.items() if k in fields} for r in data['roads']]
    viewer['graph']={'connections':[{'a':c['a'],'b':c['b'],'evidence':c['evidence']} for c in data['graph']['connections'] if c['evidence']=='extended-only']}
    viewer['attachments']=[{k:a[k] for k in ['id','locationId','roadId','positionASL','target2D']} for a in data['attachments']]
    def display_precision(value):
        if isinstance(value,float): return round(value,3)
        if isinstance(value,list): return [display_precision(v) for v in value]
        if isinstance(value,dict): return {k:display_precision(v) for k,v in value.items()}
        return value
    compact=display_precision(viewer)
    # Preserve full projection precision; coordinate display rounding must not affect the CRS.
    compact['manifest']=data['manifest']
    payload=json.dumps(compact,separators=(',',':'),ensure_ascii=True,allow_nan=False).replace('</','<\\/')
    (ROOT/'viewer/data.js').write_text('window.ROAD_DATA = '+payload+';\n',encoding='utf-8')
    print(json.dumps(data['manifest']['summary'],indent=2))


if __name__=='__main__': main()
