"""Post-hoc diagnostics using existing results only. No new optimizer evaluations.
Case feasibility differs only in the cycle ceiling; objectives are unchanged.
The pooled reference uses a larger total search budget, so it is NOT another
equal-budget algorithm comparator or a certified Pareto front.
"""
from pathlib import Path
import csv,json
import numpy as np
from analyze_formal import hv_rectangles,write_csv,CYCLES,NAMES

ROOT=Path(__file__).resolve().parents[1]
OUT=Path(__file__).resolve().parent

def nd(F):
    order=np.lexsort((F[:,1],F[:,0])); keep=[]; best=np.inf
    for i in order:
        if F[i,1]<best: keep.append(i); best=F[i,1]
    return np.array(keep,dtype=int)

def crowding_subset(F,k):
    if len(F)<=k: return np.arange(len(F))
    cd=np.zeros(len(F))
    for j in range(2):
        o=np.argsort(F[:,j],kind='stable'); x=F[o,j]; cd[o[[0,-1]]]=np.inf
        if x[-1]>x[0]: cd[o[1:-1]]+=(x[2:]-x[:-2])/(x[-1]-x[0])
    return np.argsort(-cd,kind='stable')[:k]

def main():
    rows=list(csv.DictReader((OUT/'all_final_designs.csv').open(encoding='utf-8-sig')))
    feasible=[r for r in rows if float(r['CV'])==0.]
    summary=[]; selected=[]
    for target in CYCLES:
        eligible=[r for r in feasible if float(r['cycle_limit_s'])<=target]
        F=np.array([[float(r['T_s']),float(r['residual_um'])] for r in eligible])
        ix=nd(F); z=F[ix]; sub=crowding_subset(z,64)
        h_full,_=hv_rectangles(z); h64,_=hv_rectangles(z[sub])
        summary.append(dict(target_cycle_limit_s=target,pooled_feasible_candidates=len(F),pooled_nondominated_points=len(z),
            retained_points=len(sub),pooled_HV=h_full,compressed_reference_HV=h64,
            source_cycle_limits=';'.join(str(x) for x in CYCLES if x<=target)))
        for k in sub:
            r=dict(eligible[ix[k]]); r={'target_cycle_limit_s':target,**r}; selected.append(r)
    write_csv('nested_reference_summary.csv',summary); write_csv('nested_reference_designs.csv',selected)
    diagnostics={'purpose':'post-hoc model/solver sanity check, not an equal-budget baseline',
                 'logic':'Increasing cycle_limit_s changes only G_cycle and enlarges the feasible set; the exact attainable HV cannot decrease.',
                 'optimization_evaluations_added':0,'reference_is_exact_Pareto_front':False,'summaries':summary}
    (OUT/'nested_reference_diagnostic.json').write_text(json.dumps(diagnostics,indent=2),encoding='utf-8')
    print(json.dumps(diagnostics,indent=2))

if __name__=='__main__': main()
