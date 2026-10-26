"""Attribute named Tracy operation scopes to complete IVCS benchmark windows."""
import argparse
import bisect
import importlib.util
import json
import math
import re
from collections import defaultdict
from pathlib import Path

# These scopes do not overlap each other. Their inner helper scopes are diagnostic only.
BLOCKS = ('ShotPreparation', 'DamageApplication', 'CasualtyCleanup',
          'AmmoNeedsScan', 'PendingRequests', 'DonorSlice')
FRAME = 'IVCS_PERF_VirtualSpace_Frame'
COMBAT = 'IVCS_PERF_Combat_Frame'
COMPONENTS = ('IVCS_PERF_AmmoQueue_Frame', 'IVCS_PERF_Entities_Frame',
              'IVCS_PERF_Spawner_Frame')


def stats(values, reader):
    if not values:
        return None
    return dict(count=len(values), total_ms=sum(values)/1e6,
                mean_ms=sum(values)/len(values)/1e6,
                **{f'p{int(q*100)}_ms': reader.percentile(values,q)/1e6
                   for q in (.5,.9,.95,.99)}, max_ms=max(values)/1e6,
                over_1ms=sum(v>1e6 for v in values),
                over_5ms=sum(v>5e6 for v in values),
                over_10ms=sum(v>1e7 for v in values))


def end(event):
    return event['ns_since_start'] + event['exec_time_ns']


def contains(parent, child):
    return parent['thread']==child['thread'] and parent['ns_since_start'] <= child['ns_since_start'] and end(child) <= end(parent)


def frame_breakdown(frame, events):
    costs = defaultdict(int)
    combat = next(e for e in events if e['name']==COMBAT)
    costs['full'] = frame['exec_time_ns']
    costs['combat'] = combat['exec_time_ns']
    for name in COMPONENTS:
        costs[name] = sum(e['exec_time_ns'] for e in events if e['name']==name)
    for name in BLOCKS:
        costs[name] = sum(e['exec_time_ns'] for e in events
                          if e['name']=='IVCS_OP_'+name and contains(combat,e))
    costs['combat_other'] = costs['combat'] - sum(costs[name] for name in BLOCKS)
    costs['frame_other'] = costs['full'] - costs['combat'] - sum(costs[name] for name in COMPONENTS)
    if min(costs.values()) < 0:
        raise ValueError('Overlapping/inconsistent scope attribution')
    steps = [e for e in events if e['name']=='IVCS_PERF_Combat_Step']
    return dict(start_ns=frame['ns_since_start'], costs_ms={k:v/1e6 for k,v in costs.items()},
                steps=len(steps), largest_exchange_ms=max((e['exec_time_ns']/1e6 for e in steps), default=0),
                largest_donor_slice_ms=max((e['exec_time_ns']/1e6 for e in events if e['name']=='IVCS_OP_DonorSlice'), default=0))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('trace',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--label',default='operation-timings')
    parser.add_argument('--trials',type=int,nargs='+',help='Select complete trials explicitly; unselected capture windows are excluded and recorded')
    parser.add_argument('--diagnostic',action='store_true',help='Attribute a complete diagnostic run without claiming passing performance validity')
    parser.add_argument('--extra-prefix',action='append',default=[],help='Additional named scopes to attribute to benchmark frames')
    parser.add_argument('--events-output',type=Path,help='Raw event directory; defaults to the trace directory')
    parser.add_argument('--benchmark-summary',type=Path,required=True)
    parser.add_argument('--reader',type=Path,default=Path.home()/'.codex/skills/read-tracy/scripts/read_tracy.py')
    args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('ivcs_tracy_reader',args.reader)
    reader=importlib.util.module_from_spec(spec); spec.loader.exec_module(reader)
    exporter=reader.resolve_exporter(None)
    events=[]
    event_sources=[]
    events_output=args.events_output or args.trace.parent
    events_output.mkdir(parents=True,exist_ok=True)
    for prefix in dict.fromkeys(('IVCS_PERF_','IVCS_OP_','IVCS_CASE_')+tuple(args.extra_prefix)):
        raw=reader.run_exporter(exporter,args.trace,'-u','-f',prefix)
        event_path=events_output/(args.trace.stem+'-'+args.label+'-'+prefix.lower().strip('_')+'-events.csv')
        event_path.write_text(raw,encoding='utf-8')
        event_sources.append(str(event_path.resolve()))
        events.extend(reader.parse_csv(raw))
    messages=reader.parse_csv(reader.run_exporter(exporter,args.trace,'-m'))
    windows={}
    for message in messages:
        match=re.fullmatch(r'IVCS PERF (BEGIN|END) trial=(\d+) mode=([\w-]+) groups=(\d+)',message['MessageName'])
        if match:
            kind,trial,mode,groups=match.groups()
            windows.setdefault((int(trial),mode,int(groups)),{})[kind]=int(message['total_ns'])
    benchmark=json.loads(args.benchmark_summary.read_text())
    if benchmark['validity_checks']['failed'] and not args.diagnostic:
        raise ValueError('Benchmark validity checks failed')
    expected={(p['trial'],p['mode'],p['groups']):p['expected_frames']
              for result in benchmark['results'] for p in result['trials']}
    excluded=[]
    if args.trials is not None:
        selected=set(args.trials)
        if not selected or selected != {key[0] for key in expected if key[0] in selected}:
            raise ValueError('Selected trial is missing from benchmark')
        excluded=[dict(trial=k[0],mode=k[1],groups=k[2],boundaries=sorted(v)) for k,v in windows.items() if k[0] not in selected]
        windows={k:v for k,v in windows.items() if k[0] in selected}
        expected={k:v for k,v in expected.items() if k[0] in selected}
    if set(windows)!=set(expected):
        raise ValueError('Trace does not cover exactly the validated benchmark phases')
    phases=[]
    for (trial,mode,groups),window in windows.items():
        if set(window)!={'BEGIN','END'}:
            raise ValueError('Capture misses a phase boundary: '+str((trial,mode,groups)))
        measured=[e for e in events if window['BEGIN']<=e['ns_since_start'] and end(e)<=window['END']]
        frames=sorted((e for e in measured if e['name']==FRAME), key=lambda e:e['ns_since_start'])
        if len(frames)!=expected[(trial,mode,groups)]:
            raise ValueError('Trace frame count differs from benchmark RPT')
        if len(frames)<100:
            raise ValueError('Too few frames in complete phase')
        starts=[e['ns_since_start'] for e in frames]
        children=[[] for _ in frames]
        for event in measured:
            if event['name']==FRAME:
                continue
            index=bisect.bisect_right(starts,event['ns_since_start'])-1
            if index<0 or not contains(frames[index],event):
                raise ValueError('Operation outside measured frame: '+event['name'])
            children[index].append(event)
        by_name=defaultdict(list)
        for event in measured:
            by_name[event['name']].append(event['exec_time_ns'])
        steps=len(by_name.get('IVCS_PERF_Combat_Step',[]))
        if mode in ('combat','ammo-pressure'):
            if not steps or not by_name.get('IVCS_OP_GetShot'):
                raise ValueError('No measured firing work')
            for block in ('ShotPreparation','DamageApplication','CasualtyCleanup'):
                if len(by_name.get('IVCS_OP_'+block,[])) != steps:
                    raise ValueError('Exchange scope count mismatch: '+block)
        operations={name:dict(stats(values,reader), mean_per_frame_ms=sum(values)/len(frames)/1e6)
                    for name,values in sorted(by_name.items())}
        breakdown=[frame_breakdown(frame,child) for frame,child in zip(frames,children)]
        tail=sorted(breakdown,key=lambda f:f['costs_ms']['full'],reverse=True)[:math.ceil(len(frames)*.01)]
        tail_mean={name:sum(f['costs_ms'][name] for f in tail)/len(tail) for name in tail[0]['costs_ms']}
        phases.append(dict(trial=trial,mode=mode,groups=groups,begin_ns=window['BEGIN'],end_ns=window['END'],
                           frames=len(frames),operations=operations,
                           tail_frames=len(tail), tail_mean_ms=tail_mean,
                           worst_frames=tail[:5],frame_attribution=breakdown))
    args.output.mkdir(parents=True,exist_ok=True)
    report=dict(selected_trials=args.trials,excluded_trace_windows=excluded,trace=str(args.trace.resolve()),event_sources=event_sources,benchmark_summary=str(args.benchmark_summary.resolve()),
                validity_checks=benchmark['validity_checks'],diagnostic=args.diagnostic or benchmark.get('diagnostic',False),
                eligible_for_performance_comparison=not args.diagnostic and benchmark.get('eligible_for_performance_comparison',True),metadata=reader.capture_metadata(args.trace),
                note='Inclusive per-call timings; parent and child scopes overlap. Tail attribution uses disjoint combat blocks.',
                phases=phases)
    (args.output/(args.label+'-summary.json')).write_text(json.dumps(report,indent=2)+'\n')
    for phase in phases:
        print(f"{phase['mode']} {phase['groups']} groups, {phase['frames']} frames")
        for name in ('IVCS_PERF_Combat_Step',)+tuple('IVCS_OP_'+b for b in BLOCKS):
            row=phase['operations'].get(name)
            if row:
                print(f"  {name}: calls={row['count']} mean={row['mean_ms']:.4f} p99={row['p99_ms']:.4f} max={row['max_ms']:.4f} ms")
        print('  Tail mean ms:',{k:round(v,3) for k,v in phase['tail_mean_ms'].items()})


if __name__=='__main__':
    main()
