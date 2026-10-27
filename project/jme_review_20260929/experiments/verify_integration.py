from pathlib import Path
import sys,json,time,hashlib,traceback
ROOT=Path(__file__).resolve().parent
REV=ROOT.parent.parent/'revision_v2_20260929'
sys.path.insert(0,str(REV))
from run_revision import load,refine_rollout,write_csv,dump,JointNet
import numpy as np, torch, core

def main():
 cfg,data,cache,params,s=load(); selected=json.loads((REV/'results/selected.json').read_text())
 paths=[ROOT/'protocol.md',ROOT/'verify_integration.py',REV.parent/'preflight/prepared.npz',REV.parent/'physics_run/best.pt']
 paths += [REV/r['path']/'best.pt' for r in selected]
 hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
 dump(ROOT/'input_manifest.json',hashes)
 rows=[];jrows=[];checks=[];t0=time.time()
 # A fixed model order, independent of the resulting performance.
 for label in ['capacity_control','history','history_removed']:
  model='history' if label=='history' else 'capacity_control'
  for seed in [9,19,29]:
   r=next(r for r in selected if r['model']==('history' if label=='history_removed' else label) and r['seed']==seed)
   net=JointNet(7);net.load_state_dict(torch.load(REV/r['path']/'best.pt',weights_only=True));net.eval()
   z=np.load(REV/'evaluations'/f'{label}_{seed}'/'predictions.npz');starts=z['starts'];ref=z['reference'];base=z['prediction'];scale=s['qstd'].numpy()
   same=refine_rollout(net,model,data['test'],params,s,cfg,starts,1)
   err=float(np.max(abs(same-base)))
   checks.append(dict(model=label,seed=seed,baseline_max_state_error=err,origins_checked=len(starts),passed=err<1e-9))
   dump(ROOT/'implementation_checks.json',checks)
   assert err<1e-9,(label,seed,err)
   prev=None
   for ss in [1,2,4,8]:
    dest=ROOT/f'{label}_{seed}_ss{ss}.npz';st=time.time()
    if ss==1:pred=base
    elif dest.exists():pred=np.load(dest)['prediction']
    else:
     pred=refine_rollout(net,model,data['test'],params,s,cfg,starts,ss)
     np.savez_compressed(dest,prediction=pred,starts=starts)
    delta=None if prev is None else core.metric(pred[:,:,:6],prev[:,:,:6],scale)['nrmse']
    for regime,mask in [('all',None),('low_speed',z['low_speed_mask']),('reversal',z['reversal_mask'])]:
     m=core.metric(pred[:,:,:6],ref[:,:,:6],scale,mask)
     rows.append(dict(model=label,seed=seed,substeps=ss,dt_ms=4/ss,origins=len(starts),regime=regime,nrmse=m['nrmse'],rmse_rad=m['rmse_rad'],previous_grid_prediction_difference_nrmse=delta))
    e=pred[:,:,:6]-ref[:,:,:6]
    for j in range(6):
     jrows.append(dict(model=label,seed=seed,substeps=ss,joint=j+1,rmse_rad=float(np.sqrt(np.mean(e[:,:,j]**2))),nrmse=float(np.sqrt(np.mean((e[:,:,j]/scale[j])**2)))))
    write_csv(ROOT/'integration_metrics.csv',rows);write_csv(ROOT/'joint_metrics.csv',jrows);dump(ROOT/'implementation_checks.json',checks)
    print(label,seed,ss,'seconds',round(time.time()-st,2),'nrmse',rows[-3]['nrmse'],flush=True)
    prev=pred
 for p,h in hashes.items():assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h,p
 dump(ROOT/'completion.json',dict(status='complete',seconds=time.time()-t0,models=3,seeds=3,origins=593,grids=4,input_hashes_unchanged=True))
if __name__=='__main__':
 try:main()
 except Exception:
  (ROOT/'failure.txt').write_text(traceback.format_exc(),encoding='utf-8');raise
