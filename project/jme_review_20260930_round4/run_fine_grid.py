"""Further grid checks using the unchanged original eager integrator."""
from pathlib import Path
import sys,json,time,hashlib,argparse,traceback
R=Path(__file__).resolve().parent;B=R.parent;REV=B/'revision_v2_20260929';OLD=B/'jme_review_20260929/experiments'
sys.path.insert(0,str(REV))
from run_revision import load,JointNet,refine_rollout,write_csv,dump
import numpy as np,torch,core
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--seed',type=int,required=True);a=ap.parse_args()
 cfg,data,cache,params,s=load();selected=json.loads((REV/'results/selected.json').read_text());seed=a.seed
 dest=R/'fine_grid';dest.mkdir(exist_ok=True);rows=[];checks=[];t0=time.time()
 paths=[Path(__file__),REV/'run_revision.py',B/'core.py',B/'networks.py',B/'preflight/prepared.npz',B/'physics_run/best.pt',R/'README.md']+[REV/r['path']/'best.pt' for r in selected]
 hashes={str(p):sha(p) for p in paths};dump(dest/f'inputs_seed{seed}.json',hashes)
 for label in ['capacity_control','history','history_removed']:
  source='history' if label=='history_removed' else label
  r=next(r for r in selected if r['model']==source and r['seed']==seed)
  net=JointNet(7);net.load_state_dict(torch.load(REV/r['path']/'best.pt',weights_only=True));net.eval()
  z=np.load(REV/f'evaluations/{label}_{seed}/predictions.npz');starts=z['starts'];scale=s['qstd'].numpy()
  previous=np.load(OLD/f'{label}_{seed}_ss8.npz')['prediction']
  # Prior all-origin 0.5 ms result is retained; unchanged callable is checked by hash.
  for ss in [16,32,64]:
   p=dest/f'{label}_{seed}_ss{ss}.npz';t=time.time()
   if p.exists():pred=np.load(p)['prediction']
   else:
    pred=refine_rollout(net,'history' if label=='history' else 'capacity_control',data['test'],params,s,cfg,starts,ss)
    np.savez_compressed(p,prediction=pred,starts=starts)
   mx=float(np.max(abs((pred[:,:,:6]-previous[:,:,:6])/scale)))
   for regime,mask in [('all',None),('low_speed',z['low_speed_mask']),('reversal',z['reversal_mask'])]:
    met=core.metric(pred[:,:,:6],z['reference'][:,:,:6],scale,mask)
    diff=core.metric(pred[:,:,:6],previous[:,:,:6],scale,mask)['nrmse']
    rows.append(dict(model=label,seed=seed,substeps=ss,dt_ms=4/ss,origins=len(starts),regime=regime,nrmse=met['nrmse'],rmse_rad=met['rmse_rad'],masked_previous_grid_difference_nrmse=diff,max_previous_grid_normalized_position_difference=mx,grid_tolerance_pass=diff<=1e-4 and mx<=1e-3,seconds=time.time()-t))
   write_csv(dest/f'metrics_seed{seed}.csv',rows)
   print('grid',label,seed,ss,'seconds',round(time.time()-t,1),'nrmse',rows[-3]['nrmse'],'difference',rows[-3]['masked_previous_grid_difference_nrmse'],'max',mx,flush=True)
   previous=pred
 for p,h in hashes.items():assert sha(p)==h,p
 dump(dest/f'completion_seed{seed}.json',dict(status='complete',seconds=time.time()-t0,rows=len(rows),input_hashes_unchanged=True,backend='unchanged original eager refine_rollout',seed=seed))
if __name__=='__main__':
 try:main()
 except Exception:
  p=R/'fine_grid';p.mkdir(exist_ok=True);(p/f'failure_{sys.argv[-1]}.txt').write_text(traceback.format_exc(),encoding='utf-8');raise
