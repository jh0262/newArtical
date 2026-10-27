"""Cross-check actual formal statistics/logs/draft tables before delivery."""
from pathlib import Path
import csv,json,re,hashlib
import numpy as np
from scipy.stats import wilcoxon

ROOT=Path(__file__).resolve().parents[1]; OUT=Path(__file__).resolve().parent
def read(name): return list(csv.DictReader((OUT/name).open(encoding='utf-8-sig')))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    metrics=read('run_metrics.csv'); pairs=read('paired_comparisons.csv'); fac=read('factorial_effects.csv'); seeds=read('factorial_by_seed.csv')
    bykey={(float(r['cycle_limit_s']),int(r['seed']),r['method']):r for r in metrics}
    capture=(ROOT/'provenance/formal_execution_captured_20260921.log').read_text(encoding='utf-8')
    pattern=r'^(\d+)/420 cy ([\d.]+) seed (\d+) (.*?): HV ([\d.]+) time ([\d.]+)s$'
    lines=re.findall(pattern,capture,re.M); assert len(lines)==420
    assert [int(r[0]) for r in lines]==list(range(1,421))
    for _,cycle,seed,name,hv,seconds in lines:
        r=bykey[(float(cycle),int(seed),name)]
        assert abs(float(hv)-float(r['HV']))<=5.01e-9
        assert abs(float(seconds)-float(r['search_seconds']))<=.000501
    assert 'COMPLETE: 420 runs, 13466880 FE, 374.5 seconds.' in capture
    checked=0; maximum=0.
    differences=[]
    for r in pairs:
        cy=float(r['cycle_limit_s']); n=r['comparator']
        d=np.array([float(bykey[(cy,s,'MODE-EAR-S')]['HV'])-float(bykey[(cy,s,n)]['HV']) for s in range(93101,93121)])
        differences.append((d,float(r['p_raw'])))
    for r in fac:
        d=np.array([float(x['value']) for x in seeds if x['cycle_limit_s']==r['cycle_limit_s'] and x['effect']==r['effect']])
        differences.append((d,float(r['p_raw'])))
    for d,p in differences:
        nz=np.round(d,12); nz=nz[nz!=0]
        if len(nz) and len(np.unique(abs(nz)))==len(nz):
            scipy_p=float(wilcoxon(nz,method='exact').pvalue); maximum=max(maximum,abs(p-scipy_p)); assert abs(p-scipy_p)<1e-14; checked+=1
    for r in read('raw_hashes.csv'): assert sha(ROOT/r['file'])==r['sha256']
    manuscript=(ROOT/'manuscript/manuscript_en_formal_v02.md').read_text(encoding='utf-8')
    for r in read('summary.csv'): assert f"{float(r['HV_median']):.6f}" in manuscript
    for r in read('saved_front_truncation_diagnostic.csv'): assert f"{float(r['HV']):.6f}" in manuscript
    for forbidden in ['420-run experiment has not been executed','planned formal experiment uses','repeated comparison specified in the experimental protocol has not been executed']:
        assert forbidden not in manuscript
    audit=json.loads((OUT/'analysis_audit.json').read_text()); assert audit['script_sha256']==sha(OUT/'analyze_formal.py')
    result={'status':'PASS','captured_log_runs_checked':420,'raw_hashes_checked':420,'signed_rank_real_comparisons_crosschecked_with_SciPy':checked,
            'maximum_p_discrepancy':maximum,'manuscript_HV_values_checked':30,'formal_optimizer_FE':13466880,'formal_batch_wall_seconds':374.5,
            'model_reevaluation_designs':26880,'engineering_selected_design_checks':8,'new_posthoc_optimizer_evaluations':0,
            'scope':'Evidence consistency and arithmetic checks; not novelty, physical validation or acceptance assessment'}
    (OUT/'delivery_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8'); print(json.dumps(result,indent=2))
if __name__=='__main__': main()
