"""Join buffered SQF context to precise Tracy operation events in validated windows."""
import argparse
import ast
import bisect
import csv
import io
import importlib.util
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

SCHEMA = {
    'Scheduler': ['engagement_queue','search_queue','budget_ms','search_first'],
    'ShotPreparation': ['engagement','units_a','units_b','elapsed','range','shots','hits','factor_misses'],
    'AmmoNeedsScan': ['group','units','requests','native','needy_recipients'],
    'UnitAmmoNeed': ['unit','class','native','weapon_magazine_counts','cargo_count','fallbacks','needed_weapons','group'],
    'DonorSlice': ['group','origin','limit','recipient_index','weapon_index','donor_before','donor_count','donor_after','requests_before','new_requests'],
    'DonorInventory': ['group','unit','class','weapons','cargo_count','compatible_classes'],
    'PendingRequest': ['group','recipient','phase','native','waiting','initially_valid','arrival_in_seconds','collection_in_seconds'],
    'Surplus': ['weapons','magazines','available'],
    'ExchangeVisit': ['engagement','mode','pending','dt','deadline_remaining_ms','elapsed_before','elapsed_advance']
}

def decode(text, prefix):
    value=text[len(prefix):]
    value=re.sub(r'\btrue\b','True',value); value=re.sub(r'\bfalse\b','False',value)
    return ast.literal_eval(value)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operations',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--label',default='context-situations')
    parser.add_argument('--threshold-ms',type=float,default=3)
    parser.add_argument('--allow-partial-context',action='store_true',help='Retain explicitly reported gaps from older thresholded captures')
    parser.add_argument('--reader',type=Path,default=Path.home()/'.codex/skills/read-tracy/scripts/read_tracy.py')
    args=parser.parse_args()
    operations=json.loads(args.operations.read_text(encoding='utf-8'))
    spec=importlib.util.spec_from_file_location('ivcs_read_tracy',args.reader)
    reader=importlib.util.module_from_spec(spec); spec.loader.exec_module(reader)
    spec=importlib.util.spec_from_file_location('ivcs_operations',Path(__file__).with_name('analyze-operations.py'))
    analysis=importlib.util.module_from_spec(spec); spec.loader.exec_module(analysis)
    events=[]
    for source in operations['event_sources']:
        events.extend(reader.parse_csv(Path(source).read_text(encoding='utf-8')))
    roots=sorted((e for e in events if e['name']==analysis.FRAME),key=lambda e:e['ns_since_start'])
    ends=[analysis.end(e) for e in roots]
    # The exporter does not quote commas in message payloads; use a tab separator.
    raw_messages=reader.run_exporter(reader.resolve_exporter(None),Path(operations['trace']),'-m','-s','\t')
    messages=list(csv.DictReader(io.StringIO(raw_messages),delimiter='\t'))
    flush_events=reader.parse_csv(reader.run_exporter(reader.resolve_exporter(None),Path(operations['trace']),'-u','-f','IVCS_DIAG_ContextFlush'))
    contexts={}; frames={}
    for m in messages:
        text=m['MessageName']
        if text.startswith('IVCS CTX FRAME '):
            frame,cost=decode(text,'IVCS CTX FRAME ')
            i=bisect.bisect_right(ends,int(m['total_ns']))-1
            if i<0 or i+1<len(roots) and int(m['total_ns'])>=roots[i+1]['ns_since_start']:
                raise ValueError('Frame context is outside a root frame interval')
            start=roots[i]['ns_since_start']
            if frame in frames or start in contexts:
                raise ValueError('Duplicate frame context')
            frames[frame]=start; contexts[start]=dict(frame=frame,coarse_ms=cost,rows=[])
        elif text.startswith('IVCS CTX ROWS '):
            frame,rows=decode(text,'IVCS CTX ROWS ')
            if frame not in frames:
                raise ValueError('Rows lack a frame context')
            contexts[frames[frame]]['rows'].extend(rows)
    reports=[]
    for phase in operations['phases']:
        measured=sorted((e for e in events if phase['begin_ns']<=e['ns_since_start'] and analysis.end(e)<=phase['end_ns']), key=lambda e:e['ns_since_start'])
        phase_roots=[e for e in measured if e['name']==analysis.FRAME]
        starts=[r['ns_since_start'] for r in phase_roots]; children=[[] for _ in starts]
        for e in measured:
            if e['name']==analysis.FRAME: continue
            i=bisect.bisect_right(starts,e['ns_since_start'])-1
            if i<0 or not analysis.contains(phase_roots[i],e): raise ValueError('Operation without frame')
            children[i].append(e)
        attribution={x['start_ns']:x for x in phase['frame_attribution']}
        cases=defaultdict(list); frame_cases=defaultdict(list); request_stages=defaultdict(lambda: defaultdict(list)); enriched=[]; calls=[]; missing=0; uncovered=[]
        for root,child in zip(phase_roots,children):
            if root['ns_since_start'] not in contexts: raise ValueError('Missing frame context')
            ctx=contexts[root['ns_since_start']]
            rows=ctx['rows']; detail=bool(rows)
            if not detail:
                if root['exec_time_ns']/1e6>=args.threshold_ms:
                    missing+=1
                    uncovered.append(dict(frame=ctx['frame'],start_ns=root['ns_since_start'],ms=root['exec_time_ns']/1e6,coarse_ms=ctx['coarse_ms'],relative_seconds=(root['ns_since_start']-phase['begin_ns'])/1e9,
                                          operation_timings={n:analysis.stats([e['exec_time_ns'] for e in child if e['name']==n],reader) for n in sorted(set(e['name'] for e in child if e['name'].startswith('IVCS_OP_')))}))
                continue
            by_name=defaultdict(list)
            for e in child: by_name[e['name']].append(e)
            offsets=Counter(); joined=[]; scheduler=None
            for name,data in rows:
                if name not in SCHEMA or len(data)!=len(SCHEMA[name]): raise ValueError('Context schema mismatch: '+name)
                values=dict(zip(SCHEMA[name],data))
                if name=='Scheduler':
                    scheduler=values; continue
                zone='IVCS_OP_'+name
                index=offsets[zone]; offsets[zone]+=1
                if index>=len(by_name[zone]): raise ValueError('More contexts than operation scopes: '+zone)
                event=by_name[zone][index]
                item=dict(operation=name,start_ns=event['ns_since_start'],ms=event['exec_time_ns']/1e6,context=values)
                if name=='ShotPreparation':
                    kind='no_shots' if values['shots']==0 else 'all_units_fire' if values['shots']==values['units_a']+values['units_b'] else 'partial_firing'
                elif name=='AmmoNeedsScan': kind='needy' if values['needy_recipients'] else 'supplied'
                elif name=='UnitAmmoNeed':
                    kind='fallback' if values['fallbacks'] else 'own_records'
                    stage_names=('IVCS_CASE_NeedOwnRecords','IVCS_CASE_NeedFallback','IVCS_CASE_WeaponProfileHit','IVCS_CASE_WeaponProfileMiss')
                    item['stages']={n:dict(count=len(v),total_ms=sum(x['exec_time_ns'] for x in v)/1e6,max_ms=max((x['exec_time_ns']/1e6 for x in v),default=0)) for n in stage_names for v in [[x for x in child if x['name']==n and analysis.contains(event,x)]]}
                elif name=='DonorSlice':
                    winner=sum(1 for e in child if e['name']=='IVCS_OP_WinnerRevalidation' and analysis.contains(event,e))
                    inventory=sum(1 for e in child if e['name']=='IVCS_OP_DonorInventory' and analysis.contains(event,e))
                    item['winner_revalidations']=winner; item['inventory_inspections']=inventory
                    kind=values['origin']+('_winner' if winner else '_scan')
                elif name=='PendingRequest':
                    kind=values['phase']+('_waiting' if values['waiting'] else '_ready')
                    stage_names=('IVCS_OP_InventorySnapshot','IVCS_OP_Surplus','IVCS_OP_ReservedMagazine','IVCS_OP_UnitAmmoNeed','IVCS_OP_Transfer')
                    item['stages']={}
                    for n in stage_names:
                        v=[x for x in child if x['name']==n and analysis.contains(event,x)]
                        total=sum(x['exec_time_ns'] for x in v)
                        item['stages'][n]=dict(count=len(v),total_ms=total/1e6)
                        request_stages[kind][n].append(total)
                elif name=='ExchangeVisit': kind='due' if values['elapsed_advance'] else 'poll'
                else: kind='all'
                item['case']=kind; cases[name+':'+kind].append(event['exec_time_ns'])
                joined.append(item); calls.append(item)
            if scheduler is None: raise ValueError('Missing scheduler context')
            for zone,count in offsets.items():
                if count!=len(by_name[zone]): raise ValueError('Missing operation contexts: '+zone)
            # Some operations may have zero calls; require complete metadata for every existing context-bearing scope.
            for name in SCHEMA:
                if name!='Scheduler' and len(by_name['IVCS_OP_'+name])!=offsets['IVCS_OP_'+name]:
                    raise ValueError('Unmatched operation context: '+name)
            visits=[x for x in joined if x['operation']=='ExchangeVisit']
            shots=[x for x in joined if x['operation']=='ShotPreparation']
            donors=[x for x in joined if x['operation']=='DonorSlice']
            needs=[x for x in joined if x['operation']=='AmmoNeedsScan']
            kind='sharing' if donors else 'firing' if sum(x['context']['shots'] for x in shots)>0 else 'scans_or_polls'
            frame_cases[kind].append(root['exec_time_ns'])
            entry=dict(frame=ctx['frame'],start_ns=root['ns_since_start'],relative_seconds=(root['ns_since_start']-phase['begin_ns'])/1e9,
                       ms=root['exec_time_ns']/1e6,coarse_ms=ctx['coarse_ms'],scheduler=scheduler,
                       outside_component_scopes_ms=attribution[root['ns_since_start']]['costs_ms']['frame_other'],
                       visits=len(visits),exchanges=len(shots),shots=sum(x['context']['shots'] for x in shots),
                       all_units_fire_exchanges=sum(x['case']=='all_units_fire' for x in shots),
                       inline_donor_slices=sum(x['context']['origin']=='inline' for x in donors),
                       queued_donor_slices=sum(x['context']['origin']=='queued' for x in donors),
                       donor_ms=sum(x['ms'] for x in donors),inline_donor_ms=sum(x['ms'] for x in donors if x['context']['origin']=='inline'),
                       queued_donor_ms=sum(x['ms'] for x in donors if x['context']['origin']=='queued'),
                       needs_scans=len(needs),first_visit_at_or_after_deadline=bool(visits and visits[0]['context']['deadline_remaining_ms']<=0),
                       visits_at_or_after_deadline=sum(x['context']['deadline_remaining_ms']<=0 for x in visits),
                       operations=joined)
            enriched.append(entry)
        if missing and not args.allow_partial_context: raise ValueError(f'{missing} multi-ms frames lack detailed context')
        slow=[x for x in enriched if x['ms']>=args.threshold_ms]
        report=dict(trial=phase['trial'],mode=phase['mode'],groups=phase['groups'],frames=phase['frames'],detailed_frames=len(enriched),
                    slow_frames=len(slow)+missing,slow_frames_with_context=len(slow),threshold_ms=args.threshold_ms,slow_frames_without_context=missing,uncovered_frames=uncovered,
                    slow_frame_case_counts=dict(Counter('sharing' if x['inline_donor_slices']+x['queued_donor_slices'] else 'firing' if x['shots'] else 'scans_or_polls' for x in slow)),
                    slow_first_visit_at_or_after_deadline=sum(x['first_visit_at_or_after_deadline'] for x in slow),
                    case_timings={name:analysis.stats(values,reader) for name,values in sorted(cases.items())},
                    request_stage_timings={kind:{name:analysis.stats(values,reader) for name,values in sorted(stages.items())} for kind,stages in sorted(request_stages.items())},
                    sampled_frame_case_timings={name:analysis.stats(values,reader) for name,values in sorted(frame_cases.items())},
                    worst_frames=sorted(enriched,key=lambda x:x['ms'],reverse=True)[:8],
                    largest_calls=sorted(calls,key=lambda x:x['ms'],reverse=True)[:15],
                    frame_situations=[{k:v for k,v in x.items() if k!='operations'} for x in enriched])
        flushes=[e['exec_time_ns'] for e in flush_events if phase['begin_ns']<=e['ns_since_start'] and analysis.end(e)<=phase['end_ns']]
        report['context_flush_timings']=analysis.stats(flushes,reader)
        reports.append(report)
        print(f"trial={phase['trial']} {phase['mode']} groups={phase['groups']} >=3ms={len(slow)} first visit at/after deadline={report['slow_first_visit_at_or_after_deadline']}")
        for x in report['worst_frames'][:3]: print(' ',round(x['ms'],3),'ms',round(x['relative_seconds'],3),'s', 'shots',x['shots'],'steps',x['exchanges'],'donors inline/queued',x['inline_donor_slices'],x['queued_donor_slices'])
    args.output.mkdir(parents=True,exist_ok=True)
    result=dict(trace=operations['trace'],source_operations=str(args.operations.resolve()),
                validity_checks=operations['validity_checks'],diagnostic=operations.get('diagnostic',False),
                eligible_for_performance_comparison=operations.get('eligible_for_performance_comparison',True),
                sampling='Case distributions describe frames that emitted context. Precise slow-frame coverage is checked and any allowed gaps are listed explicitly.',
                partial_context_allowed=args.allow_partial_context,
                schema=SCHEMA,phases=reports)
    (args.output/(args.label+'-summary.json')).write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':
    main()
