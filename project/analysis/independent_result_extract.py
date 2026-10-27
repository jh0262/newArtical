"""Read completed CSV/JSON outputs only; no optimiser, MAT mutation or fitting."""
from pathlib import Path
import csv,json,math,statistics,collections,hashlib
root=Path(__file__).resolve().parents[1]
results=root/'results'
def read(name):
    with (results/name).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def number(x):return float(x) if x not in ('','NaN') else float('nan')
summary=read('summary.csv'); comparisons=read('comparisons.csv'); runs=read('runs.csv')
engineering=read('engineering_runs.csv')
index={(r['problem_id'],r['variant_id']):r for r in summary}
assert len(runs)==5640 and len(comparisons)==136 and all(r['complete']=='1' for r in comparisons)
assert sum(int(r['FE']) for r in runs)==194577300
family_tables={}
for family in dict.fromkeys(r['family_id'] for r in comparisons):
    selected=[r for r in comparisons if r['family_id']==family]
    details=[]
    for r in selected:
        a=index[(r['problem_id'],r['a_id'])];b=index[(r['problem_id'],r['b_id'])]
        af,bf=number(a['mean_f']),number(b['mean_f'])
        details.append({**r,'a_mean':af,'b_mean':bf,'a_std':number(a['std_f']),
                        'b_std':number(b['std_f']),'mean_a_minus_b':af-bf,
                        'relative_mean_a_minus_b':(af-bf)/abs(bf) if bf else None})
    family_tables[family]=details
full=[r for r in runs if r['variant_id']==('G2P1J1' if r['problem_id']=='PV' else 'G2P1J0')]
assert len(full)==780
events=[c for c in runs[0] if c.startswith('event_')]
activity={p:{k:sum(number(r[k]) for r in full if r['problem_id']==p) for k in events}
          for p in dict.fromkeys(r['problem_id'] for r in full)}
eng_groups=collections.defaultdict(list)
for r in engineering:eng_groups[(r['problem_id'],r['variant_id'])].append(r)
engineering_summary=[]
for key,rows in eng_groups.items():
    feasible=[r for r in rows if number(r['best_cv'])==0]
    costs=[number(r['best_f']) for r in feasible]
    anchor=costs[0] if costs else float('nan')
    shifted=[x-anchor for x in costs]
    engineering_summary.append({'problem':key[0],'variant':key[1],'role':rows[0]['role'],
        'n':len(rows),'n_feasible':len(feasible),
        'mean':anchor+statistics.mean(shifted) if shifted else None,
        'std':statistics.stdev(shifted) if len(shifted)>1 else 0,
        'best':min(costs) if costs else None,'worst':max(costs) if costs else None,
        'median':statistics.median(costs) if costs else None,
        'n_distinct_f':len(set(costs)),
        'n_exact_best':sum(x==min(costs) for x in costs) if costs else 0,
        'branches':dict(collections.Counter(f"{r['x1']};{r['x2']}" for r in rows)) if key[0]=='PV' else None})
engineering_payload=json.loads((results/'engineering_best.json').read_text('utf-8-sig'))
extract={'n_runs':len(runs),'n_tests':len(comparisons),'full_runs':len(full),
    'family_totals':read('family_totals.csv'),'family_details':family_tables,
    'full_events_total':{k:sum(number(r[k]) for r in full) for k in events},
    'full_activity_by_problem':activity,
    'full_nonzero_pulse_runs':sum(number(r['event_pulse_trials'])>0 for r in full),
    'engineering_summary_stable':engineering_summary,
    'engineering_recheck':{k:v for k,v in engineering_payload.items() if k not in ('best_designs','summaries')},
    'source_sha256':{f:hashlib.sha256((results/f).read_bytes()).hexdigest() for f in
      ['comparisons.csv','family_totals.csv','summary.csv','engineering_runs.csv','engineering_best.json']}}
(root/'analysis/independent_result_extract.json').write_text(json.dumps(extract,ensure_ascii=False,indent=2),encoding='utf-8')
print('SIGNIFICANT COMPARISONS')
for family,details in family_tables.items():
    significant=[r for r in details if r['decision']!='not_significant']
    print(family,json.dumps(significant,ensure_ascii=False))
print('ENGINEERING',json.dumps([r for r in engineering_summary if r['role']!='ablation'],ensure_ascii=False))
print('PV TESTS',json.dumps([r for r in comparisons if r['problem_id']=='PV'],ensure_ascii=False))
print('FULL EVENT TOTALS',json.dumps(extract['full_events_total']))
print('PULSE ACTIVE RUNS',extract['full_nonzero_pulse_runs'])
print('ACTIVITY BY PROBLEM',json.dumps({p:a for p,a in activity.items() if a['event_pulse_trials'] or p in ['WB','CB','PV']},ensure_ascii=False))
