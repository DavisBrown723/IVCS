"""Estimate 20-group p99 uncertainty using whole one-second blocks, retaining every frame."""
import argparse,collections,hashlib,importlib.util,json,random,statistics
from pathlib import Path
from timing_guard import assert_benchmark_idle
assert_benchmark_idle()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('operations',type=Path,nargs='+');p.add_argument('--output',type=Path,required=True)
    p.add_argument('--repetitions',type=int,default=2000);a=p.parse_args()
    spec=importlib.util.spec_from_file_location('stats',Path(__file__).with_name('analyze-performance.py'))
    stats=importlib.util.module_from_spec(spec);spec.loader.exec_module(stats)
    rng=random.Random(20261026)
    def quantile(values,q):
        v=sorted(values);x=(len(v)-1)*q;i=int(x)
        return v[i]+(v[min(i+1,len(v)-1)]-v[i])*(x-i)
    ci=lambda v:[quantile(v,.025),quantile(v,.975)]
    def blocks(phase):
        result=collections.defaultdict(list)
        for f in phase['frame_attribution']:
            second=int((f['start_ns']-phase['begin_ns'])/1e9)
            result[second].append(f['costs_ms']['full'])
        values=list(result.values())
        if len(values)>1 and len(values[-1])<statistics.median(map(len,values))*.5:
            values[-2].extend(values.pop())
        assert sum(map(len,values))==phase['frames']
        return values
    all_phases=[];runs=[];all_values=[]
    for path in sorted(a.operations,key=lambda p:p.name):
        report=json.loads(path.read_text(encoding='utf-8'))
        session_path=path.with_name(path.name.removesuffix('-operations-summary.json')+'-session.json')
        session=json.loads(session_path.read_text(encoding='utf-8-sig'))
        assert session.get('identical_code_control') and session.get('control_source_sha256'), 'Requires a verified identical-code capture'
        identity=report['trace'].replace('\\','/').split('/')[-1]
        run_seed=20261026 ^ int.from_bytes(hashlib.sha256(identity.encode()).digest()[:8],'big')
        rng=random.Random(run_seed)
        assert report['eligible_for_performance_comparison'] and not report['diagnostic']
        assert not report['excluded_trace_windows'] and report['validity_checks']['failed']==0
        phases=report['phases'];grouped=[blocks(p) for p in phases]
        values=[v for bs in grouped for b in bs for v in b];all_values.extend(values)
        boot=[]
        for _ in range(a.repetitions):
            sample=[v for bs in grouped for _ in bs for v in rng.choice(bs)]
            boot.append(quantile(sample,.99))
        phase_rows=[]
        for phase,bs in zip(phases,grouped):
            frames=phase['frame_attribution']
            phase_rows.append(dict(trial=phase['trial'],mode=phase['mode'],frames=len(frames),blocks=len(bs),
                full=stats.distribution([f['costs_ms']['full'] for f in frames]),
                entity=stats.distribution([f['costs_ms']['IVCS_PERF_Entities_Frame'] for f in frames])))
        by_trial={p['trial']:(p,bs) for p,bs in zip(phases,grouped)}
        differences=[]
        if set(by_trial)=={1,2,3,4}:
            for _ in range(a.repetitions):
                before=[];after=[]
                for first,second in [(1,2),(3,4)]:
                    btrial=first if by_trial[first][0]['mode'].startswith('before-') else second
                    atrial=second if btrial==first else first
                    bbs=by_trial[btrial][1];abs_=by_trial[atrial][1]
                    assert len(bbs)==len(abs_)
                    for _ in bbs:
                        i=rng.randrange(len(bbs));before.extend(bbs[i]);after.extend(abs_[i])
                differences.append(quantile(after,.99)-quantile(before,.99))
        entity_means=[p['entity']['mean_ms'] for p in phase_rows]
        runs.append(dict(operations=str(path),trace=report['trace'],control_source_sha256=session['control_source_sha256'],bootstrap_seed=run_seed,frames=len(values),full=stats.distribution(values),
            p99_block_bootstrap_95ci_ms=ci(boot),phases=phase_rows,unchanged_entity_mean_ratio=max(entity_means)/min(entity_means),
            aa_p99_difference_95ci_ms=ci(differences) if differences else None,
            stationarity_gate_passed=max(entity_means)/min(entity_means)<=1.10))
        all_phases.extend(grouped)
    rng=random.Random(20261026)
    boot=[]
    for _ in range(a.repetitions):
        sample=[v for bs in all_phases for _ in bs for v in rng.choice(bs)]
        boot.append(quantile(sample,.99))
    result=dict(method='Stratified one-second block bootstrap; tiny final partial blocks merge into the preceding block. All frame samples retained. Paired A/A differences share selected block indices within each seed pair.',
        repetitions=a.repetitions,seed=20261026,production_changes=False,runs=runs,
        pooled=dict(frames=len(all_values),full=stats.distribution(all_values),p99_block_bootstrap_95ci_ms=ci(boot)),
        stationarity_gate=dict(maximum_unchanged_stage_mean_ratio=1.10,passed=all(r['stationarity_gate_passed'] for r in runs)),
        note='Confidence intervals quantify sampled-run uncertainty, not a universal gameplay bound. A/A differences should not be mistaken for optimization effects.')
    a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    for r in runs:print(r['trace'],r['full'],'CI',r['p99_block_bootstrap_95ci_ms'],'A/A difference CI',r['aa_p99_difference_95ci_ms'],'stationarity',r['unchanged_entity_mean_ratio'])
    print('Pooled',result['pooled'])

if __name__=='__main__':main()
