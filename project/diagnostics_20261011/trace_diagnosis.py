"""Posthoc, zero-objective-evaluation diagnosis of saved formal traces."""
from pathlib import Path
import csv, hashlib, json
import numpy as np
from scipy.io import loadmat

ROOT=Path(__file__).resolve().parents[1]
OUT=Path(__file__).resolve().parent
EPS=1e-10

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(name,rows):
    with (OUT/name).open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

def main():
    manifest=json.loads((ROOT/'provenance/formal_manifest.json').read_text(encoding='utf-8'))
    for row in manifest['files']: assert sha(ROOT/row['path'])==row['sha256']
    with (ROOT/'analysis_formal/raw_hashes.csv').open(encoding='utf-8-sig') as f: hashes=list(csv.DictReader(f))
    assert len(hashes)==420
    rows=[]; events=[]
    for item in hashes:
        path=ROOT/item['file'];assert sha(path)==item['sha256']
        r=loadmat(path,simplify_cells=True)['result'];tr=np.asarray(r['trace'])
        assert tr.shape==(501,7) and np.all(np.isfinite(tr))
        h=tr[:,2];drops=np.maximum(-np.diff(h),0.);dd=np.maximum.accumulate(h)-h
        peak=int(np.argmax(h));counts={f'drops_above_{x:.0e}':int(np.sum(drops>x)) for x in [1e-10,1e-8,1e-6,1e-4]}
        row=dict(method=r['method'],cycle_limit_s=float(r['cycle_limit_s']),seed=int(r['seed']),final_HV=float(h[-1]),peak_HV=float(h[peak]),peak_generation=peak,peak_minus_final=float(h[peak]-h[-1]),max_running_drawdown=float(dd.max()),largest_one_step_drop=float(drops.max()),sum_one_step_drops=float(drops.sum()),ear_calls=int(r['ear_calls']),ear_fallbacks=int(r['ear_fallbacks']),final_population_catalogues=int(tr[-1,5]),final_guide_catalogues=int(tr[-1,6]),**counts)
        rows.append(row)
        for j in np.flatnonzero(drops>EPS):
            events.append(dict(method=r['method'],cycle_limit_s=float(r['cycle_limit_s']),seed=int(r['seed']),generation=int(j+1),before_HV=float(h[j]),after_HV=float(h[j+1]),drop=float(drops[j])))
    summary=[]
    for c in [2.5,3.,3.5]:
        for name in ['MODE-CD-G','MODE-EAR-G','MODE-CD-S','MODE-EAR-S','MV-NSGA-II','MV-SPEA2','CAT-QMC']:
            rr=[r for r in rows if r['cycle_limit_s']==c and r['method']==name];assert len(rr)==20
            s=dict(cycle_limit_s=c,method=name,runs=20,runs_with_drop=sum(r['drops_above_1e-10']>0 for r in rr),runs_with_final_below_peak=sum(r['peak_minus_final']>EPS for r in rr),median_drop_generations=float(np.median([r['drops_above_1e-10'] for r in rr])),median_peak_minus_final=float(np.median([r['peak_minus_final'] for r in rr])),max_peak_minus_final=max(r['peak_minus_final'] for r in rr),median_max_running_drawdown=float(np.median([r['max_running_drawdown'] for r in rr])),max_one_step_drop=max(r['largest_one_step_drop'] for r in rr),total_ear_calls=sum(r['ear_calls'] for r in rr),total_ear_fallbacks=sum(r['ear_fallbacks'] for r in rr))
            summary.append(s)
    write('trace_by_run.csv',rows);write('trace_drop_events.csv',events);write('trace_summary.csv',summary)
    result=dict(status='PASS',date='2026-10-11',raw_hashes_verified=420,frozen_inputs_verified=len(manifest['files']),new_objective_evaluations=0,trace_transition_count=420*500,HV_drop_tolerance=EPS,source_hash_list_sha256=sha(ROOT/'analysis_formal/raw_hashes.csv'),script_sha256=sha(Path(__file__)),scope='Posthoc saved-trace arithmetic only. Peak-final gap is not the gap to the union of all ever-evaluated points; sum of drops is not net lost HV. No new significance tests.')
    (OUT/'trace_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))
    for r in summary:
        if r['method'] in ['MODE-CD-G','MODE-EAR-G','MODE-EAR-S']:print(json.dumps(r))
    print('largest final gap',json.dumps(max(rows,key=lambda r:r['peak_minus_final'])))

if __name__=='__main__':main()
