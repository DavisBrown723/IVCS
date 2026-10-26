"""Attribute diagnostic helper costs only to entity-update scopes."""
import argparse,bisect,csv,json,importlib.util
from collections import defaultdict
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('operations',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
r=json.loads(a.operations.read_text());events=[]
for path in r['event_sources']:
    with Path(path).open(encoding='utf-8-sig',newline='') as f:
        events.extend(dict(name=x['name'],start=int(x['ns_since_start']),duration=int(x['exec_time_ns']),thread=x['thread']) for x in csv.DictReader(f))
spec=importlib.util.spec_from_file_location('stats',Path(__file__).with_name('analyze-performance.py'));stats=importlib.util.module_from_spec(spec);spec.loader.exec_module(stats)
result=[]
for phase in r['phases']:
    measured=[e for e in events if phase['begin_ns']<=e['start'] and e['start']+e['duration']<=phase['end_ns']]
    parents=sorted((e for e in measured if e['name']=='IVCS_PERF_Entities_Frame'),key=lambda e:e['start']);starts=[e['start'] for e in parents];rows=[defaultdict(list) for e in parents];calls=defaultdict(list)
    for e in measured:
        if e['name']=='IVCS_PERF_Entities_Frame':continue
        i=bisect.bisect_right(starts,e['start'])-1
        if i>=0 and e['thread']==parents[i]['thread'] and e['start']+e['duration']<=parents[i]['start']+parents[i]['duration']:
            calls[e['name']].append(e['duration']/1e6);rows[i][e['name']].append(e['duration']/1e6)
    worst=[]
    for i in sorted(range(len(parents)),key=lambda i:parents[i]['duration'],reverse=True)[:10]:
        worst.append(dict(start_ns=parents[i]['start'],entity_ms=parents[i]['duration']/1e6,operations={n:dict(calls=len(v),total_ms=sum(v),max_ms=max(v)) for n,v in sorted(rows[i].items())}))
    result.append(dict(trial=phase['trial'],mode=phase['mode'],frames=len(parents),entity=stats.distribution([e['duration']/1e6 for e in parents]),operations={n:stats.distribution(v) for n,v in sorted(calls.items())},worst_entity_frames=worst))
a.output.write_text(json.dumps(dict(trace=r['trace'],note='Inclusive nested costs; helper metrics are restricted to entity frames and must not be summed with parents.',results=result),indent=2)+'\n')
for row in result:
    print('Trial',row['trial'],'entities',row['entity'])
    for name,op in sorted(row['operations'].items(),key=lambda x:x[1]['mean_ms']*x[1]['count'],reverse=True)[:14]: print(name,op['count'],round(op['mean_ms']*op['count'],3),'ms total',round(op['p99_ms'],4),'p99')
    print('Worst',json.dumps(row['worst_entity_frames'][0]))
