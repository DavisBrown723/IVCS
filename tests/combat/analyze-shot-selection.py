"""Correlate test-only shot-selection counters with exact benchmark frame scopes."""
import argparse,bisect,collections,csv,importlib.util,json
from pathlib import Path

from timing_guard import assert_benchmark_idle
assert_benchmark_idle()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('operations',type=Path);p.add_argument('messages',type=Path);p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();o=json.loads(args.operations.read_text(encoding='utf-8'))
    spec=importlib.util.spec_from_file_location('base',Path(__file__).with_name('analyze-performance.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
    # The native exporter does not quote commas inside message names. Split at the final comma.
    messages=[line.rsplit(',',1) for line in args.messages.read_text(encoding='utf-8-sig').splitlines()[1:] if line]
    frames=sorted([f for phase in o['phases'] for f in phase['frame_attribution']],key=lambda f:f['start_ns'])
    starts=[f['start_ns'] for f in frames];contexts=collections.defaultdict(list)
    for name,stamp in messages:
        if name.startswith('IVCS SHOT WORK '):
            ns=int(stamp);i=bisect.bisect_right(starts,ns)-1
            if i>=0 and ns-starts[i]<100000000:contexts[starts[i]].extend(base.payload(name,'IVCS SHOT WORK '))
    by_class={};resets=0;fires=0
    for rows in contexts.values():
        for row in rows:
            if row[0]=='reset':resets+=1
            elif row[0]=='fire':fires+=1
            elif row[0]=='select':
                key=row[2]+(' support' if row[4] else ' primary')
                a=by_class.setdefault(key,dict(calls=0,weapons=0,records=0,prepare_misses=0,prepare_hits=0,negative_hits=0,selected=0))
                a['calls']+=1
                for k,v in zip(('weapons','records','prepare_misses','prepare_hits','negative_hits'),row[5:10]):a[k]+=v
                a['selected']+=bool(row[11])
    if not by_class:raise ValueError('No shot contexts matched measured frames')
    events=[]
    for source in o['event_sources']:
        with Path(source).open(encoding='utf-8-sig',newline='') as f:
            events.extend(dict(name=v['name'],start=int(v['ns_since_start']),duration=int(v['exec_time_ns'])) for v in csv.DictReader(f))
    def detail(frame):
        start=frame['start_ns'];end=start+round(frame['costs_ms']['full']*1e6);ops=collections.defaultdict(float)
        for e in events:
            if start<=e['start'] and e['start']+e['duration']<=end:ops[e['name']]+=e['duration']/1e6
        return dict(frame=frame,operation_ms=dict(ops),work=contexts[start])
    report=dict(trace=o['trace'],diagnostic_only=True,frames=len(frames),resets=resets,firing_loops=fires,selection_by_class=by_class,
        worst_frames=[detail(f) for f in sorted(frames,key=lambda f:f['costs_ms']['full'],reverse=True)[:5]],
        worst_exchanges=[detail(f) for f in sorted(frames,key=lambda f:f['largest_exchange_ms'],reverse=True)[:5]])
    args.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('Resets',resets,'firing loops',fires,'selection calls',sum(x['calls'] for x in by_class.values()))
    print(json.dumps(by_class,indent=2))
    for w in report['worst_exchanges'][:2]:
        print('Exchange',w['frame']['largest_exchange_ms'],'ms; record scan',w['operation_ms'].get('IVCS_SHOT_RecordScan',0),'ms')
        print('Work',w['work'])

if __name__=='__main__':main()
