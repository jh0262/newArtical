"""Independent NumPy recomputation of saved predictions, never calls a model."""
from pathlib import Path
import json,sys
from train_controlled import R,B,sha,dump
import numpy as np,torch
def main():
 from check_active_evaluation import main as guard
 guard('result_audit')
 O=R/'pointwise';s=torch.load(R/'training/seed9/scalers.pt',weights_only=True);std=s['astd'].numpy();vstd=s['vstd'].numpy();mean=s['amean'].numpy();orig=np.load(B/'preflight/prepared.npz');metrics=json.loads((O/'metrics.json').read_text());pm=json.loads((O/'permutation_metrics.json').read_text());n=0;maxerr=0.;gaps=[]
 def close(actual,expected):
  nonlocal n,maxerr
  a=np.asarray(actual);b=np.asarray(expected);er=float(np.max(abs(a-b)));assert np.allclose(a,b,rtol=2e-12,atol=2e-12),(er,a,b);n+=a.size;maxerr=max(maxerr,er)
 for label in ['train','validation','test']+[f'peer_{i:02d}' for i in range(1,34)]:
  if label.startswith('peer'):z=np.load(B/'jme_review_20260930_round4/external_validation'/f'prepared_{label[-2:]}.npz');a=z['a'][32:];v=z['v'][32:]
  else:a=orig[label+'_a'][32:];v=orig[label+'_v'][32:]
  out=np.load(O/f'{label}_predictions.npz')
  for m in [r for r in metrics if r['record']==label]:
   pred=np.broadcast_to(mean,a.shape) if m['model']=='training_mean' else out[f"{m['model']}_{m['seed']}_{m['checkpoint']}"]
   mse=np.mean((pred-a)**2,0);close(mse/std**2,m['joint_nmse']);close(np.sqrt(mse),m['rmse_rad_s2']);close(np.mean(mse/std**2),m['nmse'])
  dz=np.load(O/f'{label}_donors.npz');maps=dz['donor_active_index'];valid=dz['valid'];assert np.array_equal(valid,(maps>=0).all(2))
  for rep in range(3):
   ii=np.where(valid[rep])[0];don=maps[rep,ii];assert (abs(don-ii[:,None])>32).all();diff=np.column_stack([abs(v[don[:,j],j]-v[ii,j])/vstd[j] for j in range(6)]);assert (diff<=.05+1e-14).all();gaps.append(float(diff.max()))
   for seed in [9,19,29]:
    row=next(m for m in pm if (m['record'],m['rep'],m['seed'])==(label,rep,seed));p=np.load(O/f'{label}_permuted_{seed}_{rep}.npy');truth=out[f'Hdelta_{seed}_best'][ii]
    close(np.mean(((p-a[ii])/std)**2),row['permuted_nmse']);close(np.mean(((truth-a[ii])/std)**2),row['true_nmse']);close(np.sqrt(np.mean((p-truth)**2,0)),row['prediction_change_rmse_rad_s2'])
 # All completed case artifacts retain the hashes written at execution end.
 completed=[]
 for p in [R/'training'/f'seed{s}'/'completion.json' for s in [9,19,29]]+[O/'completion.json']+list((R/'rollout').glob('*/completion.json')):
  c=json.loads(p.read_text());assert c['status']=='complete'
  for name,h in c['outputs'].items():assert sha(p.parent/name)==h,p.parent/name
  completed.append(str(p))
 out=R/'analysis';out.mkdir(exist_ok=True);dump(out/'independent_numeric_audit.json',dict(status='pass',checked_scalar_values=n,max_absolute_recomputation_difference=maxerr,max_scaled_donor_velocity_gap=max(gaps),completed_manifests_verified=completed,scope='Pointwise, donor diagnostics and completed artifact hashes; no model execution or independent physical validation',script_sha256=sha(__file__)))
 print('NUMERIC AUDIT PASS',n,'values',maxerr)
if __name__=='__main__':main()
