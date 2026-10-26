"""Summarize complete per-frame samples from the native combat benchmark RPT."""
import argparse
import ast
import csv
import json
import math
import re
import statistics
from collections import defaultdict
from pathlib import Path

from timing_guard import assert_benchmark_idle
assert_benchmark_idle()


COLUMNS = ['relative_seconds', 'frame', 'ivcs_ms', 'frame_interval_ms', 'steps',
           'combat_ms', 'ammo_queue_ms', 'entities_ms', 'spawner_ms']

def payload(line, marker):
    raw = line.split(marker, 1)[1].strip()
    if raw.endswith('"'):
        raw = raw[:-1]
    raw = raw.replace('""', '"')
    raw = re.sub(r'\btrue\b', 'True', raw)
    raw = re.sub(r'\bfalse\b', 'False', raw)
    return ast.literal_eval(raw)

def percentile(values, q):
    values = sorted(values)
    position = (len(values) - 1) * q
    lower = math.floor(position)
    upper = math.ceil(position)
    return values[lower] + (values[upper] - values[lower]) * (position - lower)

def distribution(values):
    if not values:
        return None
    return dict(count=len(values), total_ms=sum(values), mean_ms=statistics.fmean(values),
                p50_ms=percentile(values,.50),p90_ms=percentile(values,.90),
                p95_ms=percentile(values,.95),p99_ms=percentile(values,.99),max_ms=max(values),
                over_1ms=sum(v>1 for v in values), over_5ms=sum(v>5 for v in values),
                over_10ms=sum(v>10 for v in values),over_16_67ms=sum(v>1000/60 for v in values))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rpt',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--label',default='native')
    parser.add_argument('--diagnostic',action='store_true',help='Retain failed/lagging complete runs for attribution, explicitly excluded from performance comparisons')
    args=parser.parse_args()
    phases=[]; current=None; config=None; done=None; progress={}; sharing_work={}
    log_text=args.rpt.read_text(errors='replace')
    if re.search(r'Error in expression|Error Undefined variable|Error Missing|Error Type',log_text):
        raise ValueError('Benchmark contains script errors')
    for line in log_text.splitlines():
        if '[IVCS PERF] CONFIG ' in line:
            config=payload(line,'[IVCS PERF] CONFIG ')
        elif '[IVCS PERF] PROGRESS ' in line:
            measured=payload(line,'[IVCS PERF] PROGRESS ')
            progress[tuple(measured[:3])]=dict(min_seconds=measured[3],max_seconds=measured[4],
                simulation_seconds=measured[5],wall_seconds=measured[7] if len(measured)>7 else measured[5],
                step_seconds=measured[6] if len(measured)>6 else 0.5)
        elif '[IVCS PERF] SHARING_WORK ' in line:
            measured=payload(line,'[IVCS PERF] SHARING_WORK ')
            sharing_work[tuple(measured[:3])]=dict(pending_searches=measured[3],pending_requests=measured[4],transfers=measured[5],forced_unresolved=measured[6] if len(measured)>6 else None)
        elif '[IVCS PERF] PHASE ' in line:
            metadata=payload(line,'[IVCS PERF] PHASE ')
            current=dict(trial=metadata[0],mode=metadata[1],groups=metadata[2],
                         expected_frames=metadata[3],seconds=metadata[4],start_units=metadata[5],
                         end_units=metadata[6],shots=metadata[7],hits=metadata[8],
                         ammo_transfers=metadata[9],rows=[])
            phases.append(current)
        elif '[IVCS PERF] ROWS ' in line:
            if current is None:
                raise ValueError('Frame samples appeared without phase metadata')
            try:
                current['rows'].extend(payload(line,'[IVCS PERF] ROWS '))
            except (SyntaxError,ValueError) as error:
                raise ValueError('Invalid/truncated frame log; reduce SQF dump batch size') from error
        elif '[IVCS TASK TEST] DONE ' in line:
            done=re.search(r'passed=(\d+) failed=(\d+)',line).groups()
    if done is None or (int(done[1]) != 0 and not args.diagnostic):
        raise ValueError('Benchmark did not complete with passing validity checks')
    failure_labels=[x.rstrip('\"').strip() for x in re.findall(r'\[IVCS TASK TEST\] FAIL ([^\r\n]+)',log_text)]
    if args.diagnostic and int(done[1]) and (len(failure_labels)!=int(done[1]) or any(x not in ('frame budget keeps combat within one second of real-time progress','frame budget keeps combat within one resolution interval plus scheduling slack') for x in failure_labels)):
        raise ValueError('Diagnostic attribution only permits progress-check failures')
    for phase in phases:
        measured=progress.get((phase['trial'],phase['mode'],phase['groups']))
        if measured is not None:
            phase['combat_progress']=measured
            phase['progress_valid'] = measured['min_seconds'] >= measured['simulation_seconds'] - (measured['step_seconds'] + 0.5)
            if not phase['progress_valid'] and not args.diagnostic:
                raise ValueError('Combat fell behind simulation-clock progress')
        work=sharing_work.get((phase['trial'],phase['mode'],phase['groups']))
        if work is not None:
            phase['sharing_work']=work
            unresolved=work['forced_unresolved'] if work['forced_unresolved'] is not None else work['pending_searches']
            maximum=math.floor(.1*phase['groups']) if work['forced_unresolved'] is not None else 0
            phase['sharing_valid'] = unresolved<=maximum and work['transfers']>=math.floor(.9*phase['groups'])
            if not phase['sharing_valid']:
                raise ValueError('Forced sharing work did not complete in the benchmark window')
        if len(phase['rows']) != phase['expected_frames']:
            raise ValueError('Frame count mismatch in '+str(phase))
        if any(len(row)!=len(COLUMNS) for row in phase['rows']):
            raise ValueError('Unexpected frame sample schema')
        if (phase['mode'] in ('combat','ammo-pressure') or phase['mode'].startswith('vehicle-')) and (phase['shots']<=0 or not any(row[4]>0 for row in phase['rows'])):
            raise ValueError('Combat counters did not advance')
        if phase['mode']=='ammo-pressure' and phase['ammo_transfers']<=0:
            raise ValueError('Ammo-pressure scenario completed no transfers')
    grouped=defaultdict(list)
    for phase in phases:
        grouped[(phase['mode'],phase['groups'])].append(phase)
    results=[]
    for (mode,groups),members in sorted(grouped.items(),key=lambda x:(x[0][1],x[0][0])):
        rows=[row for member in members for row in member['rows']]
        metrics={column:distribution([row[i] for row in rows]) for i,column in enumerate(COLUMNS) if column.endswith('_ms')}
        metrics['ivcs_busy_ms']=distribution([row[2] for row in rows if row[4]>0])
        metrics['combat_busy_ms']=distribution([row[5] for row in rows if row[4]>0])
        entry=dict(mode=mode,groups=groups,engagements=groups if mode.startswith('vehicle-') else (groups//2 if mode in ('combat','ammo-pressure') else 0),
                   frames=len(rows),trial_count=len(members),units_at_window_start=[m['start_units'] for m in members],
                   units_at_window_end=[m['end_units'] for m in members],shots=sum(m['shots'] for m in members),
                   hits=sum(m['hits'] for m in members),ammo_transfers=sum(m['ammo_transfers'] for m in members),
                   steps=sum(row[4] for row in rows),step_frames=sum(row[4]>0 for row in rows),
                   measured_fps=len(rows)/sum(m['seconds'] for m in members),metrics=metrics,
                   trials=[{k:v for k,v in member.items() if k!='rows'} for member in members])
        results.append(entry)
    args.output.mkdir(parents=True,exist_ok=True)
    instrumented=bool(re.search(r'\[IVCS PERF\] (?:(?:RESOLUTION|EXCHANGE)_SCOPES|CLOCK_CANARIES) installed',log_text))
    report=dict(rpt=str(args.rpt.resolve()),label=args.label,config=config,diagnostic=args.diagnostic or instrumented,
                eligible_for_performance_comparison=not (args.diagnostic or instrumented) and int(done[1])==0,
                validity_checks=dict(passed=int(done[0]),failed=int(done[1])),failure_labels=failure_labels,results=results)
    (args.output/(args.label+'-summary.json')).write_text(json.dumps(report,indent=2)+'\n')
    with (args.output/(args.label+'-frames.csv')).open('w',newline='') as handle:
        writer=csv.writer(handle); writer.writerow(['trial','mode','groups']+COLUMNS)
        for phase in phases:
            writer.writerows([phase['trial'],phase['mode'],phase['groups']]+row for row in phase['rows'])
    for entry in results:
        cost=entry['metrics']['ivcs_ms']; combat=entry['metrics']['combat_ms']
        print('{mode:6} groups={groups:3} frames={frames:5} fps={fps:.1f} IVCS mean={mean:.3f} p95={p95:.3f} p99={p99:.3f} max={maximum:.3f} combat mean={combat:.3f}'.format(
            **entry,fps=entry['measured_fps'],mean=cost['mean_ms'],p95=cost['p95_ms'],p99=cost['p99_ms'],maximum=cost['max_ms'],combat=combat['mean_ms']))

if __name__=='__main__':
    main()
