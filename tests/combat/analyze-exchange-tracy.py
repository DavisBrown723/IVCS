"""Compare complete exchanges and their nested operations without summing overlaps."""
import argparse,bisect,collections,csv,importlib.util,json
from pathlib import Path

from timing_guard import assert_benchmark_idle
assert_benchmark_idle()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('operations',type=Path);p.add_argument('--messages',type=Path)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    o=json.loads(a.operations.read_text(encoding='utf-8'))
    spec=importlib.util.spec_from_file_location('stats',Path(__file__).with_name('analyze-performance.py'))
    stats=importlib.util.module_from_spec(spec);spec.loader.exec_module(stats)
    events=[]
    for source in o['event_sources']:
        with Path(source).open(encoding='utf-8-sig',newline='') as f:
            events.extend(dict(name=r['name'],start=int(r['ns_since_start']),duration=int(r['exec_time_ns']),thread=r['thread']) for r in csv.DictReader(f))
    events.sort(key=lambda x:x['start']);starts=[x['start'] for x in events]
    frames=sorted((f for phase in o['phases'] for f in phase['frame_attribution']),key=lambda x:x['start_ns'])
    frame_starts=[f['start_ns'] for f in frames];context=collections.defaultdict(list)
    if a.messages:
        for line in a.messages.read_text(encoding='utf-8-sig').splitlines()[1:]:
            if not line:continue
            name,stamp=line.rsplit(',',1)
            if not name.startswith('IVCS RES WORK '):continue
            i=bisect.bisect_right(frame_starts,int(stamp))-1
            if i>=0 and int(stamp)-frame_starts[i]<100_000_000:
                context[frame_starts[i]].extend(stats.payload(name,'IVCS RES WORK '))
    groups=collections.defaultdict(list)
    for f,rows in context.items():
        for row in rows:
            if row[0]=='exchange':groups[f].append(dict(context=row,details=[]))
            elif groups[f]:groups[f][-1]['details'].append(row)
    phases=[];all_exchanges=[]
    for phase in o['phases']:
        steps=[e for e in events if e['name']=='IVCS_PERF_Combat_Step' and phase['begin_ns']<=e['start'] and e['start']+e['duration']<=phase['end_ns']]
        frame_index=collections.Counter();rows=[];calls=collections.defaultdict(list)
        for e in steps:
            children=[x for x in events[bisect.bisect_left(starts,e['start']):bisect.bisect_right(starts,e['start']+e['duration'])] if x is not e and x['thread']==e['thread'] and x['start']+x['duration']<=e['start']+e['duration']]
            by_name=collections.defaultdict(list)
            for x in children:by_name[x['name']].append(x['duration']/1e6);calls[x['name']].append(x['duration']/1e6)
            i=bisect.bisect_right(frame_starts,e['start'])-1;f=frame_starts[i]
            row=dict(trial=phase['trial'],mode=phase['mode'],start_ns=e['start'],offset_seconds=(e['start']-phase['begin_ns'])/1e9,ms=e['duration']/1e6,
                     operations={n:dict(count=len(v),total_ms=sum(v),max_ms=max(v)) for n,v in sorted(by_name.items())})
            if groups[f]:
                assert len(groups[f])==frames[i]['steps'], 'Context/exchange count mismatch'
                row.update(groups[f][frame_index[f]])
            frame_index[f]+=1;rows.append(row);all_exchanges.append(row)
        phases.append(dict(trial=phase['trial'],mode=phase['mode'],exchanges=stats.distribution([e['ms'] for e in rows]),
            operations={n:stats.distribution(v) for n,v in sorted(calls.items())},worst=sorted(rows,key=lambda e:e['ms'],reverse=True)[:10]))
    grouped={}
    for mode in sorted({p['mode'] for p in phases}):
        rows=[e for e in all_exchanges if e['mode']==mode]
        grouped[mode]=dict(exchanges=stats.distribution([e['ms'] for e in rows]),worst=sorted(rows,key=lambda e:e['ms'],reverse=True)[:12])
    sample_path=a.output.with_suffix('.csv')
    sample_rows=[]
    for row in all_exchanges:
        sample={key:row[key] for key in ('trial','mode','start_ns','offset_seconds','ms')}
        if 'context' in row:
            c=row['context'];after=9 if len(c)==13 else 8
            sample.update(engagement=c[2],seed_before=c[3],step_time=c[4],seed_after=c[after],shots=c[after+1]-c[5],hits=c[after+2]-c[6],vehicle_shots=c[after+3]-c[7])
            sample['factor_misses']=sum(r[0]=='factorMiss' for r in row['details'])
        for name,op in row['operations'].items():
            sample[name+'_count']=op['count'];sample[name+'_ms']=op['total_ms']
        sample_rows.append(sample)
    fields=list(dict.fromkeys(k for row in sample_rows for k in row))
    with sample_path.open('w',encoding='utf-8',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields);writer.writeheader();writer.writerows(sample_rows)
    result=dict(trace=o['trace'],diagnostic=any(e['name'].startswith(('IVCS_RES_','IVCS_EX_')) for e in events),exchange_samples=str(sample_path),note='Inclusive child scopes overlap. Exchange context retains seeds and actual shot/hit deltas; no timing samples are excluded.',phases=phases,pooled=grouped)
    a.output.write_text(json.dumps(result,indent=2)+chr(10),encoding='utf-8')
    for phase in phases:
        print('Trial',phase['trial'],phase['exchanges'])
        for name,op in sorted(phase['operations'].items(),key=lambda x:x[1]['total_ms'],reverse=True)[:18]:
            print(name,op['count'],round(op['total_ms'],3),round(op['p99_ms'],4))
if __name__=='__main__':main()
