from pathlib import Path
import sys, json, time, hashlib, argparse, traceback, warnings
ROOT=Path(__file__).resolve().parent
BASE=ROOT.parent
REV=BASE/'revision_v2_20260929'
OLD=BASE/'jme_review_20260929/experiments'
sys.path.insert(0,str(REV))
from run_revision import load, JointNet, write_csv, dump, refine_rollout
from networks import history_stage
import numpy as np,torch,core

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

class FrozenRHS(torch.nn.Module):
 def __init__(self,net,model,params,s,cfg):
  super().__init__();self.net=net;self.model=model;self.phy=core.load_physics();self.lags=cfg['history_lags']
  for k in ['dyn','friction']:self.register_buffer('param_'+k,params[k].detach().clone())
  for k in ['vmean','vstd','tmean','tstd']:self.register_buffer(k,s[k])
 def forward(self,x,u,hist,c):
  p=self.phy(x,u,self.param_dyn,self.param_friction,False,True)
  raw=history_stage(hist,x[:,6:],self.lags,c) if self.model=='history' else x[:,6:,None].repeat(1,1,7)
  f=(raw-self.vmean[None,:,None])/self.vstd[None,:,None]
  tau=self.net(f)*self.tstd+self.tmean
  acc=p['x_dot_result'][:,6:]+torch.bmm(p['M_inverse'],tau[:,:,None])[:,:,0]
  return torch.cat([x[:,6:],acc],1),torch.linalg.cholesky_ex(p['M'])[1]

def compiled_rhs(eager,x,u,hist):
 with warnings.catch_warnings(record=True) as ws:
  warnings.simplefilter('always')
  traced=torch.jit.trace(eager,(x,u,hist,torch.tensor(.375)),check_trace=False)
 traced=torch.jit.freeze(traced.eval())
 errors=[]
 with torch.no_grad():
  for c in [0.,.25,.5,1.]:
   for shift in [0.,1e-5]:
    args=(x+shift,u-shift,hist+shift,torch.tensor(c))
    a,ai=eager(*args);b,bi=traced(*args)
    err=float((a-b).abs().max());assert torch.equal(ai,bi)
    errors.append(err)
 assert max(errors)<1e-9,max(errors)
 return traced,dict(max_rhs_absolute_difference=max(errors),cases=len(errors),trace_warnings=sorted(set(str(w.message) for w in ws)))

def rollout(rhs,d,cfg,starts,ss):
 idx=torch.tensor(starts);x=torch.cat([d['q'][idx],d['v'][idx]],1)
 hist=d['v'][idx[:,None]-torch.arange(33)[None,:]];out=[];h=cfg['dt']/ss
 def call(x,u,c):
  dx,info=rhs(x,u,hist,torch.tensor(c))
  if info.any():raise ValueError('Nonpositive inertia during integration')
  return dx
 with torch.no_grad():
  for k in range(cfg['horizon']):
   u=d['u'][idx+k]
   for j in range(ss):
    c=j/ss;dc=1/ss
    a=call(x,u,c);b=call(x+h*a/2,u,c+dc/2);cc=call(x+h*b/2,u,c+dc/2);dd=call(x+h*cc,u,c+dc)
    x=x+h*(a+2*b+2*cc+dd)/6
    if not torch.isfinite(x).all() or x.abs().max()>1e6:raise ValueError('Nonfinite/divergent integration')
   hist=torch.cat([x[:,None,6:],hist[:,:-1,:]],1);out.append(x.clone())
 return torch.stack(out,1).numpy()

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--stage',choices=['preflight','run'],default='preflight');args=ap.parse_args()
 cfg,data,cache,params,s=load();selected=json.loads((REV/'results/selected.json').read_text())
 dest=ROOT/'numerics';dest.mkdir(exist_ok=True)
 paths=[ROOT/'README.md',Path(__file__),BASE/'preflight/prepared.npz',BASE/'physics_run/best.pt']+[REV/r['path']/'best.pt' for r in selected]
 hashes={str(p):sha(p) for p in paths};dump(dest/f'input_manifest_{args.stage}.json',hashes)
 rows=[];checks=[];t0=time.time()
 for label in ['capacity_control','history','history_removed']:
  for seed in [9,19,29]:
   if args.stage=='preflight' and (seed!=9 or label=='history_removed'):continue
   source='history' if label=='history_removed' else label
   row=next(r for r in selected if r['model']==source and r['seed']==seed)
   net=JointNet(7);net.load_state_dict(torch.load(REV/row['path']/'best.pt',weights_only=True));net.eval()
   z=np.load(REV/f'evaluations/{label}_{seed}/predictions.npz');starts=z['starts'];idx=torch.tensor(starts);d=data['test']
   x=torch.cat([d['q'][idx],d['v'][idx]],1);hist=d['v'][idx[:,None]-torch.arange(33)[None,:]]
   eager=FrozenRHS(net,'history' if label=='history' else 'capacity_control',params,s,cfg).eval()
   t=time.time();rhs,check=compiled_rhs(eager,x,d['u'][idx],hist)
   print('traced',label,seed,'seconds',round(time.time()-t,2),'rhs_difference',check['max_rhs_absolute_difference'],flush=True)
   previous=np.load(OLD/f'{label}_{seed}_ss8.npz')['prediction']
   test=rollout(rhs,d,cfg,starts,8)
   check.update(model=label,seed=seed,baseline_max_state_difference=float(np.max(abs(test-previous))))
   scale=s['qstd'].numpy();check['baseline_position_difference_nrmse']=core.metric(test[:,:,:6],previous[:,:,:6],scale)['nrmse']
   check['passed']=check['baseline_max_state_difference']<1e-8
   checks.append(check);dump(dest/f'implementation_checks_{args.stage}.json',checks)
   print('equivalence',label,seed,check['baseline_max_state_difference'],'elapsed',round(time.time()-t0),flush=True)
   if not check['passed']:raise ValueError('Frozen graph baseline does not reproduce previous 0.5 ms result')
   if args.stage=='preflight':continue
   for ss in [16,32,64]:
    path=dest/f'{label}_{seed}_ss{ss}.npz';t=time.time()
    if path.exists():pred=np.load(path)['prediction']
    else:
     pred=rollout(rhs,d,cfg,starts,ss);np.savez_compressed(path,prediction=pred,starts=starts)
    mx=float(np.max(abs((pred[:,:,:6]-previous[:,:,:6])/scale)))
    for regime,mask in [('all',None),('low_speed',z['low_speed_mask']),('reversal',z['reversal_mask'])]:
     met=core.metric(pred[:,:,:6],z['reference'][:,:,:6],scale,mask)
     diff=core.metric(pred[:,:,:6],previous[:,:,:6],scale,mask)['nrmse']
     rows.append(dict(model=label,seed=seed,substeps=ss,dt_ms=4/ss,origins=len(starts),regime=regime,nrmse=met['nrmse'],rmse_rad=met['rmse_rad'],masked_previous_grid_difference_nrmse=diff,max_previous_grid_normalized_position_difference=mx,grid_tolerance_pass=diff<=1e-4 and mx<=1e-3,seconds=time.time()-t))
    write_csv(dest/'metrics.csv',rows);print('grid',label,seed,ss,'seconds',round(time.time()-t,2),'error',rows[-3]['nrmse'],'grid_delta',rows[-3]['masked_previous_grid_difference_nrmse'],'max_delta',mx,flush=True)
    previous=pred
 for p,h in hashes.items():assert sha(p)==h,p
 dump(dest/f'completion_{args.stage}.json',dict(status='complete',elapsed_seconds=time.time()-t0,inputs_unchanged=True,rows=len(rows),checks=len(checks)))

if __name__=='__main__':
 try:main()
 except Exception:
  (ROOT/'numerics').mkdir(exist_ok=True);(ROOT/'numerics/failure.txt').write_text(traceback.format_exc(),encoding='utf-8');raise
