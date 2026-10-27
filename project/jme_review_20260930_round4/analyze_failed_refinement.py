"""Audit completed fine outputs against original tight outputs; never solves."""
from pathlib import Path
import argparse,json,hashlib
from adaptive_integrator import R,REV,load,np,core,dump
ap=argparse.ArgumentParser();ap.add_argument('--seed',type=int,choices=[9,19],required=True);a=ap.parse_args();O=R/'failed_window_refinement'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
for p,h in json.loads((O/f'inputs_{a.seed}.json').read_text()).items():assert sha(p)==h,p
cfg,data,cache,params,s=load();sq=s['qstd'].numpy();fp=O/f'history_{a.seed}_fine.npz';sp=O/f'history_{a.seed}_fine_stats.json';stats=json.loads(sp.read_text());fine=np.load(fp);hi=np.load(R/f'adaptive/history_{a.seed}_tight.npz');z=np.load(REV/f'evaluations/history_{a.seed}/predictions.npz');assert np.array_equal(hi['starts'],z['starts']);assert fine['prediction'].shape==(len(fine['starts']),150,12) and np.isfinite(fine['prediction']).all()
rows=[]
for i,start in enumerate(fine['starts']):
 ix=np.where(hi['starts']==start)[0];assert len(ix)==1;p=fine['prediction'][i:i+1,:,:6];q=hi['prediction'][ix,:,:6];mx=float(abs((p-q)/sq).max());ds={}
 for reg,mask in [('all',None),('low_speed',z['low_speed_mask'][ix]),('reversal',z['reversal_mask'][ix])]:ds[reg]=core.metric(p,q,sq,mask)['nrmse']
 rows.append(dict(start=int(start),max_normalized_position_difference=mx,difference_nrmse=ds,pass_original_thresholds=mx<=1e-3 and max(x for x in ds.values() if x is not None)<=1e-4))
out=dict(status='completed_fine_output_audited',seed=a.seed,checks=rows,all_pass=all(x['pass_original_thresholds'] for x in rows),input_hashes_unchanged_at_audit=True,prediction_sha256=sha(fp),stats_sha256=sha(sp),script_sha256=sha(__file__),comparison='original tight 1e-8/1e-10 against fine 1e-10/1e-12; local diagnostic, original failures retained')
dump(O/f'tight_fine_check_{a.seed}.json',out);print(json.dumps(out,ensure_ascii=False))
