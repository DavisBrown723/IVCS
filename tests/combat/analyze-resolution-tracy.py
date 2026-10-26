"""Attribute combat-resolution scopes and buffered shot/damage work to exact windows."""
import argparse
import bisect
import collections
import csv
import importlib.util
import json
from pathlib import Path

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('operations',type=Path);p.add_argument('messages',type=Path);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();o=json.loads(a.operations.read_text(encoding='utf-8'))
    spec=importlib.util.spec_from_file_location('base',Path(__file__).with_name('analyze-performance.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
    events=[]
    for source in o['event_sources']:
        with Path(source).open(encoding='utf-8-sig',newline='') as f:
            events.extend(dict(name=x['name'],start=int(x['ns_since_start']),duration=int(x['exec_time_ns']),thread=x['thread']) for x in csv.DictReader(f))
    events.sort(key=lambda x:x['start']);starts=[x['start'] for x in events]
    def inside(parent,child):
        return parent['thread']==child['thread'] and parent['start']<=child['start'] and child['start']+child['duration']<=parent['start']+parent['duration']
    frames=sorted((f for phase in o['phases'] for f in phase['frame_attribution']),key=lambda x:x['start_ns'])
    frame_starts=[f['start_ns'] for f in frames];context=collections.defaultdict(list)
    for line in a.messages.read_text(encoding='utf-8-sig').splitlines()[1:]:
        if not line:continue
        name,stamp=line.rsplit(',',1)
        if name.startswith('IVCS RES WORK '):
            stamp=int(stamp);i=bisect.bisect_right(frame_starts,stamp)-1
            if i>=0 and stamp-frame_starts[i]<100_000_000:
                context[frame_starts[i]].extend(base.payload(name,'IVCS RES WORK '))
    combat_events=[]
    for phase in o['phases']:
        measured=[e for e in events if phase['begin_ns']<=e['start'] and e['start']+e['duration']<=phase['end_ns']]
        parents=[e for e in measured if e['name']=='IVCS_PERF_Combat_Frame'];parent_starts=[e['start'] for e in parents]
        for e in measured:
            i=bisect.bisect_right(parent_starts,e['start'])-1
            if i>=0 and e['name']!='IVCS_PERF_Combat_Frame' and inside(parents[i],e):combat_events.append(e)
    operations=collections.defaultdict(list)
    for e in combat_events:operations[e['name']].append(e['duration']/1e6)
    steps=[e for e in combat_events if e['name']=='IVCS_PERF_Combat_Step']
    update_name='IVCS_RES_IVCS_Combat_update' if any(e['name']=='IVCS_RES_IVCS_Combat_update' for e in combat_events) else 'IVCS_HELI_IVCS_Combat_update'
    updates=[e for e in combat_events if e['name']==update_name]
    due=[];no_step=[];outside=[]
    for e in updates:
        nested=[s for s in steps if inside(e,s)]
        (due if nested else no_step).append(e['duration']/1e6)
        if nested:outside.append((e['duration']-sum(s['duration'] for s in nested))/1e6)
    worst=[]
    for step in sorted(steps,key=lambda x:x['duration'],reverse=True)[:10]:
        children=[e for e in events[bisect.bisect_left(starts,step['start']):bisect.bisect_right(starts,step['start']+step['duration'])] if e is not step and inside(step,e)]
        sums=collections.defaultdict(list)
        for e in children:sums[e['name']].append(e['duration']/1e6)
        i=bisect.bisect_right(frame_starts,step['start'])-1
        worst.append(dict(start_ns=step['start'],ms=step['duration']/1e6,frame=frames[i],operations={n:dict(calls=len(v),total_ms=sum(v),max_ms=max(v)) for n,v in sorted(sums.items())},whole_frame_context=context[frame_starts[i]]))
    rows=[x for v in context.values() for x in v];shots=[x for x in rows if x[0]=='shot'];damages=[x for x in rows if x[0]=='damage']
    damage_counts=collections.Counter((x[2],x[3]) for x in damages)
    selected=collections.Counter(tuple(x[9]) for x in shots if x[9])
    phase_updates=[]
    for phase in o['phases']:
        phase_calls=[e for e in updates if phase['begin_ns']<=e['start'] and e['start']+e['duration']<=phase['end_ns']]
        idle=[];due_overhead=[]
        for e in phase_calls:
            nested=[s for s in steps if inside(e,s)]
            if nested:due_overhead.append((e['duration']-sum(s['duration'] for s in nested))/1e6)
            else:idle.append(e['duration']/1e6)
        phase_updates.append(dict(trial=phase['trial'],mode=phase['mode'],updates_without_steps=base.distribution(idle),outside_step_in_due_updates=base.distribution(due_overhead)))
    result=dict(trace=o['trace'],diagnostic_only=bool(rows) or o.get('diagnostic',False),frames=len(frames),phase_updates=phase_updates,note='Named inclusive helpers overlap. Context is for the entire frame, which may contain multiple exchanges.',
        combat_operations={n:base.distribution(v) for n,v in sorted(operations.items())},
        updates_with_steps=base.distribution(due),updates_without_steps=base.distribution(no_step),outside_step_in_due_updates=base.distribution(outside),
        turret_selection=dict(calls=len(shots),weapons=sum(x[5] for x in shots),records=sum(x[6] for x in shots),preparation_misses=sum(x[7] for x in shots),negative_records=sum(x[8] for x in shots),selected=[dict(weapon=k[0],magazine=k[1],calls=v) for k,v in sorted(selected.items())]),
        vehicle_damage=[dict(vehicle=k[0],ammo=k[1],calls=v) for k,v in sorted(damage_counts.items())],worst_exchanges=worst)
    a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print('No-step updates',result['updates_without_steps'])
    print('Due updates outside exchange',result['outside_step_in_due_updates'])
    print('Shot work',result['turret_selection'])
    for n,v in sorted(result['combat_operations'].items(),key=lambda t:t[1]['total_ms'],reverse=True)[:18]:print(n,v['count'],round(v['total_ms'],3),round(v['p99_ms'],3))
if __name__=='__main__':main()
