from pathlib import Path
import csv,json,hashlib,datetime
import numpy as np
from scipy import stats
root=Path(__file__).resolve().parents[1]; out=root/'analysis/results'
def rows(name): return list(csv.DictReader((out/name).open(encoding='utf-8-sig')))
r=rows('median_igdplus.csv'); names=list(r[0])[1:]; problems=[list(q.values())[0] for q in r]
y=np.array([[float(q[a]) for a in names] for q in r]); target=names.index('G111')
res=stats.friedmanchisquare(*y.T)
context=json.loads((out/'statistical_context.json').read_text(encoding='utf-8'))
assert abs(res.pvalue-context['friedmanP'])<1e-10
rank=stats.rankdata(y,axis=1).mean(0)
for q in rows('friedman_ranks.csv'): assert abs(rank[names.index(q['Algorithm'])]-float(q['AverageRank']))<1e-10
pair=rows('g111_pairwise_holm.csv'); ps=[]
for q in pair:
 d=y[:,target]-y[:,names.index(q['Comparator'])]
 p=1.0 if np.all(d==0) else stats.wilcoxon(d,method='exact').pvalue
 assert abs(p-float(q['P']))<1e-10,(q,p)
 ps.append(p)
order=np.argsort(ps); adj=np.minimum(1,np.maximum.accumulate(np.array(ps)[order]*np.arange(len(ps),0,-1))); h=np.zeros(len(ps)); h[order]=adj
for i,q in enumerate(pair): assert abs(h[i]-float(q['HolmP']))<1e-10
# Independent cube differencing, compared at every problem-seed factor row.
allruns=rows('verified_runs.csv'); lookup={(q['Problem'],int(q['Seed']),q['Algorithm']):float(q['IGDplus']) for q in allruns}
terms={'A':(0,),'B':(1,),'C':(2,),'AB':(0,1),'AC':(0,2),'BC':(1,2),'ABC':(0,1,2)}
error=0.
for q in rows('factorial_seed_effects.csv'):
 cube=np.array([lookup[q['Problem'],int(q['Seed']),f'G{k:03b}'] for k in range(8)]).reshape(2,2,2)
 for ax in terms[q['Effect']]: cube=np.diff(cube,axis=ax)
 e=abs(cube.mean()-float(q['Contrast'])); error=max(error,e); assert e<1e-10
report={'status':'PASS','friedman_p':float(res.pvalue),'primary_pairwise_comparisons':len(pair),'factorial_seed_contrasts':1120,'max_factorial_error':error,'exact_wilcoxon_min_p_for_8_problems':2/2**8,'holm_12_min_first_step':12*2/2**8,'holm_7_min_first_step':7*2/2**8,'limitations':'With 8 problems, these exact-Wilcoxon Holm families cannot achieve 0.05. Do not infer equivalence or absence of effect. Descriptive bootstrap CIs are not adjusted simultaneous intervals.','checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(out/'statistical_crosscheck.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
files=list((root/'analysis').glob('*.m'))+[Path(__file__),root/'scripts/audit_results.py']
(out/'analysis_code_manifest.json').write_text(json.dumps([{'path':p.relative_to(root).as_posix(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files],indent=2),encoding='utf-8')
print(json.dumps(report))
