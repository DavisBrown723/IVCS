"""Correlate strict IVCS frames, post-frame fixed-work probes and host PDH samples."""
import argparse,bisect,collections,csv,datetime,importlib.util,json,math,re,statistics
from pathlib import Path

from timing_guard import assert_benchmark_idle
assert_benchmark_idle()


def read_events(path):
    with path.open(encoding='utf-8-sig',newline='') as f:
        return [dict(name=x['name'],start=int(x['ns_since_start']),duration=int(x['exec_time_ns'])) for x in csv.DictReader(f)]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('operations',type=Path);p.add_argument('--clock-events',type=Path,required=True)
    p.add_argument('--messages',type=Path,required=True);p.add_argument('--host-csv',type=Path)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    report=json.loads(a.operations.read_text(encoding='utf-8'))
    spec=importlib.util.spec_from_file_location('stats',Path(__file__).with_name('analyze-performance.py'))
    stats=importlib.util.module_from_spec(spec);spec.loader.exec_module(stats)
    clock=read_events(a.clock_events)
    sync=[]
    for line in a.messages.read_text(encoding='utf-8-sig').splitlines()[1:]:
        if not line:continue
        name,ns=line.rsplit(',',1)
        if name.startswith('IVCS CLOCK SYNC '):
            frame,utc=stats.payload(name,'IVCS CLOCK SYNC ')
            epoch=datetime.datetime(*utc[:6],microsecond=utc[6]*1000,tzinfo=datetime.timezone.utc).timestamp()
            sync.append((int(ns),epoch*1e9))
    assert sync,'Missing clock synchronization'
    offset=statistics.median(utc-ns for ns,utc in sync)
    residuals=[(utc-ns-offset)/1e6 for ns,utc in sync]
    host=[];rejected_process_samples=0;previous_ids={}
    if a.host_csv:
        with a.host_csv.open(encoding='utf-8-sig',newline='') as f:
            reader=csv.reader(f);header=next(reader)
            minutes=int(re.search(r'\((-?\d+)\)$',header[0])[1])
            columns=[x.replace('\\\\','\\').lower() for x in header]
            logical_processors=sum('processor information(' in n and '_total)' not in n and n.endswith('\\% processor performance') for n in columns)
            for row in reader:
                dt=datetime.datetime.strptime(row[0],'%m/%d/%Y %H:%M:%S.%f')
                utc=(dt+datetime.timedelta(minutes=minutes)).replace(tzinfo=datetime.timezone.utc).timestamp()*1e9
                values={}
                for name,value in zip(columns[1:],row[1:]):
                    try:
                        value=float(value)
                        if math.isfinite(value):values[name]=value
                    except ValueError:pass
                current_ids={n[:-len('\\id process')]:int(v) for n,v in values.items() if '\\process(' in n and n.endswith('\\id process')}
                for name,value in list(values.items()):
                    if '\\process(' in name and name.endswith('\\% processor time'):
                        prefix=name[:-len('\\% processor time')]
                        pid=current_ids.get(prefix)
                        if pid is None or previous_ids.get(prefix)!=pid or value<0 or value>100*max(1,logical_processors):
                            values.pop(name);rejected_process_samples+=1
                previous_ids=current_ids
                host.append((utc,values))
    times=[t for t,_ in host]
    def host_at(utc):
        # PDH cooked samples cover the preceding interval; join to its end.
        i=bisect.bisect_left(times,utc)
        if i>=len(host) or host[i][0]-utc>1.5e9:return {}
        values=host[i][1]
        def total(suffix):
            return next((v for n,v in values.items() if n.endswith(suffix)),None)
        cores=[v for n,v in values.items() if 'processor information(' in n and '_total)' not in n and n.endswith('\\% processor performance')]
        return dict(cpu_performance_mean=statistics.mean(cores) if cores else None,
                    cpu_performance_min=min(cores) if cores else None,
                    cpu_utility=total('processor information(_total)\\% processor utility'),
                    queue_length=total('system\\processor queue length'),
                    process_cpu={n.split('process(',1)[1].split(')',1)[0]:v for n,v in values.items() if '\\process(' in n and n.endswith('\\% processor time')})
    phases=[];all_rows=[]
    for phase in report['phases']:
        frames=phase['frame_attribution'];starts=[f['start_ns'] for f in frames]
        assigned=[collections.defaultdict(list) for f in frames]
        for e in clock:
            if not(phase['begin_ns']<=e['start'] and e['start']+e['duration']<=phase['end_ns']):continue
            i=bisect.bisect_right(starts,e['start'])-1
            assert i>=0
            assert e['start']>=starts[i]+frames[i]['costs_ms']['full']*1e6-2,'Probe overlaps measured frame'
            assigned[i][e['name']].append(e['duration']/1e6)
        rows=[]
        for f,probes in zip(frames,assigned):
            assert len(probes['IVCS_CLOCK_Arithmetic'])==len(probes['IVCS_CLOCK_Allocation'])==1,'Missing or duplicate fixed-work probe'
            utc=f['start_ns']+offset
            h=host_at(utc)
            row=dict(trial=phase['trial'],mode=phase['mode'],utc_ns=int(utc),
                     offset_seconds=(f['start_ns']-phase['begin_ns'])/1e9,
                     full_ms=f['costs_ms']['full'],combat_ms=f['costs_ms']['combat'],
                     entity_ms=f['costs_ms']['IVCS_PERF_Entities_Frame'],steps=f['steps'],
                     arithmetic_ms=probes['IVCS_CLOCK_Arithmetic'][0],allocation_ms=probes['IVCS_CLOCK_Allocation'][0],
                     **{k:v for k,v in h.items() if k!='process_cpu'})
            rows.append(row);all_rows.append(row)
        metrics={k:stats.distribution([r[k] for r in rows]) for k in ['full_ms','combat_ms','entity_ms','arithmetic_ms','allocation_ms']}
        bins=[]
        for second in range(math.ceil((phase['end_ns']-phase['begin_ns'])/1e9)):
            selected=[r for r in rows if second<=r['offset_seconds']<second+1]
            if not selected:continue
            b=dict(second=second,frames=len(selected))
            for key in ['full_ms','combat_ms','entity_ms','arithmetic_ms','allocation_ms']:
                b[key]=statistics.median(r[key] for r in selected)
            for key in ['cpu_performance_mean','cpu_performance_min','cpu_utility','queue_length']:
                v=[r[key] for r in selected if r.get(key) is not None];b[key]=statistics.median(v) if v else None
            bins.append(b)
        phase_host=[values for utc,values in host if phase['begin_ns']+offset<=utc<=phase['end_ns']+offset]
        processes=collections.defaultdict(list)
        for values in phase_host:
            for name,value in values.items():
                if '\\process(' in name and name.endswith('\\% processor time') and not any(x in name for x in ['process(_total)','process(idle)']):
                    processes[name.split('process(',1)[1].split(')',1)[0]].append(value)
        host_metrics={}
        for key in ['cpu_performance_mean','cpu_performance_min','cpu_utility','queue_length']:
            v=[r[key] for r in rows if r.get(key) is not None]
            host_metrics[key]=dict(count=len(v),mean=statistics.mean(v),min=min(v),max=max(v)) if v else None
        phases.append(dict(trial=phase['trial'],mode=phase['mode'],frames=len(rows),metrics=metrics,
                           host=host_metrics,top_process_cpu=[dict(process=n,mean_one_core_percent=statistics.mean(v),max_one_core_percent=max(v)) for n,v in sorted(processes.items(),key=lambda x:statistics.mean(x[1]),reverse=True)[:12]],
                           second_bins=bins))
    fields=list(dict.fromkeys(k for r in all_rows for k in r))
    samples=a.output.with_suffix('.csv')
    with samples.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(all_rows)
    result=dict(trace=report['trace'],validity_checks=report['validity_checks'],identical_code_control=True,
                diagnostic_only=True,samples=str(samples),host_process_samples_rejected=rejected_process_samples,clock_sync=dict(samples=len(sync),offset_ns=offset,max_abs_residual_ms=max(map(abs,residuals))),
                note='Probe time is outside the measured IVCS root. CPU counters are 1 Hz interval samples; they cannot establish the cause of an individual preemption.',phases=phases)
    a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    for phase in phases:
        print('Trial',phase['trial'],'frames',phase['frames'])
        for n,m in phase['metrics'].items():print(n,round(m['mean_ms'],6),round(m['p99_ms'],6))
        print('Host',phase['host']);print('Top processes',phase['top_process_cpu'][:5])

if __name__=='__main__':main()
