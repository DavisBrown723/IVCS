"""Correlate detailed helicopter scopes with buffered motion and grid context."""
import argparse,bisect,collections,csv,importlib.util,json
from pathlib import Path

from timing_guard import assert_benchmark_idle
assert_benchmark_idle()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('operations',type=Path);p.add_argument('messages',type=Path);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();o=json.loads(a.operations.read_text(encoding='utf-8'))
    spec=importlib.util.spec_from_file_location('base',Path(__file__).with_name('analyze-performance.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
    frames=sorted((f for phase in o['phases'] for f in phase['frame_attribution']),key=lambda f:f['start_ns'])
    starts=[f['start_ns'] for f in frames];contexts=collections.defaultdict(list)
    for line in a.messages.read_text(encoding='utf-8-sig').splitlines()[1:]:
        if not line:continue
        name,stamp=line.rsplit(',',1)
        if not name.startswith('IVCS FLIGHT WORK '):continue
        ns=int(stamp);i=bisect.bisect_right(starts,ns)-1
        if i>=0 and ns-starts[i]<100_000_000:
            contexts[starts[i]].extend(base.payload(name,'IVCS FLIGHT WORK '))
    events=[]
    for source in o['event_sources']:
        with Path(source).open(encoding='utf-8-sig',newline='') as f:
            events.extend(dict(name=v['name'],start=int(v['ns_since_start']),duration=int(v['exec_time_ns']),thread=v['thread']) for v in csv.DictReader(f))
    events.sort(key=lambda e:e["start"])
    event_starts=[e["start"] for e in events]
    calls=[];unmatched=0
    for frame in frames:
        start=frame['start_ns'];end=start+round(frame['costs_ms']['full']*1e6)
        inner=[e for e in events[bisect.bisect_left(event_starts,start):bisect.bisect_right(event_starts,end)] if e['start']+e['duration']<=end]
        helicopters=sorted((e for e in inner if e['name']=='IVCS_HELI_IVCS_Combat_updateHelicopter'),key=lambda e:e['start'])
        moves=[row for row in contexts[start] if row[0]=='move']
        if len(moves)!=len(helicopters):unmatched+=1
        for index,call in enumerate(helicopters):
            parts=collections.defaultdict(float)
            for e in inner:
                if e is not call and e['thread']==call['thread'] and call['start']<=e['start'] and e['start']+e['duration']<=call['start']+call['duration']:
                    parts[e['name']]+=e['duration']/1e6
            calls.append(dict(start_ns=call['start'],frame_start_ns=start,total_ms=call['duration']/1e6,operations_ms=dict(parts),motion=moves[index] if len(moves)==len(helicopters) else None))
    moves=[row for rows in contexts.values() for row in rows if row[0]=='move']
    grids=[row for rows in contexts.values() for row in rows if row[0]=='grid']
    if not calls or not moves:raise ValueError('No flight diagnostics matched')
    names=sorted({name for row in calls for name in row['operations_ms']})
    stage_totals={name:sum(row['operations_ms'].get(name,0) for row in calls) for name in names}
    disjoint=['IVCS_FLIGHT_Health','IVCS_ENTITY_IVCS_Combat_getHelicopterPolicy','IVCS_ENTITY_IVCS_Combat_getHelicopterAttackArea','IVCS_FLIGHT_Evasion','IVCS_FLIGHT_AreaCheck','IVCS_HELI_IVCS_Combat_getHelicopterPass','IVCS_FLIGHT_Destination','IVCS_FLIGHT_Leash','IVCS_FLIGHT_Integrate','IVCS_ENTITY_IVCS_VirtualSpace_setEntityPosition']
    for row in calls:
        row['other_ms']=row['total_ms']-sum(row['operations_ms'].get(name,0) for name in disjoint)
        if row['other_ms'] < -0.000001:raise ValueError('Selected helicopter stages overlap')
    report=dict(trace=o['trace'],diagnostic_only=True,stage_totals_ms=stage_totals,other=base.distribution([row['other_ms'] for row in calls]),disjoint_stage_names=disjoint,note='Nested helper totals overlap. Other subtracts only the listed disjoint stages.',frames=len(frames),unmatched_frames=unmatched,helicopter_calls=len(calls),motion_rows=len(moves),
        stationary_calls=sum(row[8] for row in moves),hold_calls=sum(row[9] for row in moves),evading_calls=sum(row[10] for row in moves),
        grid_rows=len(grids),grid_cells=dict(count=len(grids),mean_entries=sum(row[2] for row in grids)/len(grids),p50_entries=base.percentile([row[2] for row in grids],.5),p95_entries=base.percentile([row[2] for row in grids],.95),max_entries=max(row[2] for row in grids)),grid_find_misses=sum(row[3]<0 for row in grids),
        total=base.distribution([row['total_ms'] for row in calls]),worst_helicopter_calls=sorted(calls,key=lambda x:x['total_ms'],reverse=True)[:15])
    a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Calls',len(calls),'stationary',report['stationary_calls'],'grid visits',len(grids),'unmatched',unmatched)
    for row in report['worst_helicopter_calls'][:4]:print(json.dumps(row))
if __name__=='__main__':main()
