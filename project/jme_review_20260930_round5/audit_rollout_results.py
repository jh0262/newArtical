from pathlib import Path
import json
from train_controlled import R,sha,dump
import numpy as np,torch
def main():
 from check_active_evaluation import main as guard
 guard('final_all_outputs')
 S=json.loads((R/'analysis/summary.json').read_text());assert len(S['numerical_checks'])==6
 raw=json.loads((R/'analysis/rollout_metrics.json').read_text());z=np.load(R/'rollout/prepared.npz');scale=torch.load(R/'training/seed9/scalers.pt',weights_only=True)['qstd'].numpy();ref=z['reference'][:,:,:6];n=0;mx=0.;nr=0
 def metric(a,b,mask):
  mask=np.ones_like(a,dtype=bool) if mask is None else mask;count=mask.sum((0,1));valid=count>0
  return float(np.sqrt(np.mean(np.sum(((a-b)/scale)**2*mask,axis=(0,1))[valid]/count[valid]))) if valid.any() else None
 for model in ['Cdelta','Hdelta']:
  for seed in [9,19,29]:
   p=R/'rollout'/f'{model}_{seed}';done=json.loads((p/'completion.json').read_text());assert done['status']=='complete'
   for name,h in done['outputs'].items():assert sha(p/name)==h,p/name
   lo=np.load(p/'loose.npz')['prediction'][:,:,:6];hi=np.load(p/'tight.npz')['prediction'][:,:,:6];checks=json.loads((p/'per_window_tolerance_checks.json').read_text())
   for rec in range(34):
    ids=z['origin_record']==rec
    for regime in ['all','low_speed','reversal']:
     mask=None if regime=='all' else z[regime+'_mask'][ids];a=metric(hi[ids],ref[ids],mask);b=next(r['nrmse'] for r in raw if (r['record'],r['model'],r['seed'],r['regime'])==(rec,model,seed,regime));assert (a is None)==(b is None)
     if a is not None:assert abs(a-b)<2e-12;mx=max(mx,abs(a-b));n+=1
   for i,row in enumerate(checks):
    passed=bool(np.max(abs((hi[i]-lo[i])/scale))<=1e-3)
    for regime in ['all','low_speed','reversal']:
     mask=None if regime=='all' else z[regime+'_mask'][i:i+1];a=metric(hi[i:i+1],lo[i:i+1],mask);b=row['nrmse_difference'][regime];assert (a is None)==(b is None)
     if a is not None:assert abs(a-b)<2e-12;passed &=a<=1e-4;n+=1
    assert row['pass_check']==passed;nr+=1
 dump(R/'analysis/rollout_numeric_audit.json',dict(status='pass',independently_checked_metrics=n,window_checks=nr,max_reference_metric_difference=mx,source_hashes={str(R/'analysis/rollout_metrics.json'):sha(R/'analysis/rollout_metrics.json')},script_sha256=sha(__file__),scope='Numerical recomputation of all new model/record/regime metrics and original two-tolerance window decisions; not physical validation'))
 print('ROLLOUT NUMERIC AUDIT PASS',n,nr,mx)
if __name__=='__main__':main()
