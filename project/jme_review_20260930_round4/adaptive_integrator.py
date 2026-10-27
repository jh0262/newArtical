from pathlib import Path
import sys,time,json,hashlib,argparse,traceback,inspect
R=Path(__file__).resolve().parent;B=R.parent;REV=B/'revision_v2_20260929'
sys.path.insert(0,str(REV))
from run_revision import load,JointNet,dump,write_csv
from numerical_refinement import FrozenRHS
import numpy as np,torch,core
from scipy.integrate import RK45,solve_ivp

def algorithm_signature():
 text='\n'.join(inspect.getsource(f) for f in [advance,robot_rollout,FrozenRHS])
 text+=json.dumps({k:getattr(RK45,k).tolist() for k in ['A','B','C','E']},sort_keys=True)
 text+=str(torch.__version__)+str(torch.get_default_dtype())
 for name in ['core.py','networks.py'] :text+=(B/name).read_text(encoding='utf-8')
 return hashlib.sha256(text.encode()).hexdigest()

def advance(fn,x,dt,scale,rtol,atol_factor,guess=None):
 n=len(x);x=x.clone();t=torch.zeros(n);h=torch.full((n,),dt) if guess is None else torch.minimum(guess,torch.full((n,),dt))
 accepted=torch.zeros(n,dtype=torch.int64);rejected=accepted.clone();calls=0;minimum=dt
 for iteration in range(4096):
  ids=torch.where(t < dt-1e-15)[0]
  if not len(ids):break
  y=x[ids];tt=t[ids];hh=torch.minimum(h[ids],dt-tt);minimum=min(minimum,float(hh.min()))
  if (hh<1e-10).any():raise RuntimeError('Minimum adaptive step reached')
  ks=[]
  for j in range(6):
   v=y if j==0 else y+hh[:,None]*sum(float(RK45.A[j,l])*ks[l] for l in range(j))
   ks.append(fn(v,tt+float(RK45.C[j])*hh,ids));calls+=1
  yn=y+hh[:,None]*sum(float(RK45.B[j])*ks[j] for j in range(6))
  ks.append(fn(yn,tt+hh,ids));calls+=1
  err=hh[:,None]*sum(float(RK45.E[j])*ks[j] for j in range(7))
  tol=atol_factor*scale[None,:]+rtol*torch.maximum(y.abs(),yn.abs())
  ratio=(err.abs()/tol).amax(1)
  if not torch.isfinite(ratio).all() or not torch.isfinite(yn).all():raise RuntimeError('Nonfinite adaptive state/error')
  ok=ratio<=1;yes=ids[ok];no=ids[~ok]
  x[yes]=yn[ok];t[yes]=tt[ok]+hh[ok];accepted[yes]+=1;rejected[no]+=1
  factor=torch.clamp(.9*torch.clamp(ratio,min=1e-16).pow(-.2),min=.2,max=10.)
  factor[~ok]=torch.clamp(factor[~ok],max=1.)
  h[ids]=hh*factor
 else:raise RuntimeError('Adaptive interval iteration budget exceeded')
 return x,h,dict(accepted=accepted,rejected=rejected,rhs_batch_calls=calls,min_step_s=minimum)

def robot_rollout(rhs,d,cfg,starts,scale,rtol,atol_factor,progress=True):
 idx=torch.tensor(starts);x=torch.cat([d['q'][idx],d['v'][idx]],1);hist=d['v'][idx[:,None]-torch.arange(33)[None,:]]
 out=[];acc=torch.zeros(len(idx),dtype=torch.int64);rej=acc.clone();h=None;calls=0;minimum=cfg['dt'];st=time.time()
 with torch.no_grad():
  for k in range(cfg['horizon']):
   uu=d['u'][idx+k]
   def fn(y,t,ids):
    dy,info=rhs(y,uu[ids],hist[ids],(t/cfg['dt'])[:,None])
    if info.any():raise RuntimeError('Nonpositive inertia in adaptive stage')
    return dy
   x,h,stat=advance(fn,x,cfg['dt'],scale,rtol,atol_factor,h)
   acc+=stat['accepted'];rej+=stat['rejected'];calls+=stat['rhs_batch_calls'];minimum=min(minimum,stat['min_step_s'])
   hist=torch.cat([x[:,None,6:],hist[:,:-1,:]],1);out.append(x.clone())
   if progress and (k+1)%25==0:print('output_step',k+1,'seconds',round(time.time()-st,1),'accepted_mean',float(acc.double().mean()),flush=True)
 return torch.stack(out,1).numpy(),dict(accepted_steps=acc.tolist(),rejected_steps=rej.tolist(),rhs_batch_calls=calls,min_step_s=minimum,seconds=time.time()-st)

def checks(cfg,data,params,s):
 dest=R/'adaptive';dest.mkdir(exist_ok=True);rows=[]
 with torch.no_grad():
  for typ in ['decay','oscillation','linear_forcing']:
   n=3;y=torch.ones(n,2);scale=torch.ones(2);h=None
   rates=torch.tensor([1.,10.,1000.])
   if typ=='decay':fn=lambda x,t,ids:-rates[ids,None]*x;truth=torch.exp(-rates[:,None]*.04).repeat(1,2)
   elif typ=='oscillation':
    rates=torch.tensor([1.,10.,30.]);y[:,1]=0
    fn=lambda x,t,ids:torch.stack([rates[ids]*x[:,1],-rates[ids]*x[:,0]],1)
    truth=torch.stack([torch.cos(rates*.04),-torch.sin(rates*.04)],1)
   else:
    fn=lambda x,t,ids:-2*x+(1+3*t[:,None]);truth=torch.full((n,2),1.25*np.exp(-2*.04)+1.5*.04-.25)
   for k in range(10):
    f=lambda x,t,ids:fn(x,t+k*.004,ids)
    y,h,st=advance(f,y,.004,scale,1e-9,1e-11,h)
   err=float((y-truth).abs().max());assert err<1e-7,(typ,err)
   rows.append(dict(problem=typ,max_absolute_error=err,threshold=1e-7))
 # Robot benchmark independent method: 3 fixed origins, two output intervals, both current/history inputs.
 selected=json.loads((REV/'results/selected.json').read_text());robot=[];d=data['test'];scale=torch.cat([s['qstd'],s['vstd']]);starts=np.array([32,7432,14832])
 for model in ['capacity_control','history']:
  r=next(r for r in selected if r['model']==model and r['seed']==9)
  net=JointNet(7);net.load_state_dict(torch.load(REV/r['path']/'best.pt',weights_only=True));rhs=FrozenRHS(net,model,params,s,cfg).eval()
  out,_=robot_rollout(rhs,d,dict(cfg,horizon=2),starts,scale,1e-9,1e-11,False);others=[]
  for start in starts:
   x=torch.cat([d['q'][start],d['v'][start]]).numpy();hist=d['v'][int(start)-torch.arange(33)][None,:,:].clone();part=[]
   for k in range(2):
    u=d['u'][int(start)+k][None,:]
    def fun(t,y):
     with torch.no_grad():return rhs(torch.tensor(y)[None,:],u,hist,torch.tensor(t/.004))[0][0].numpy()
    sol=solve_ivp(fun,(0,.004),x,method='Radau',rtol=1e-10,atol=scale.numpy()*1e-12)
    assert sol.success,sol.message
    x=sol.y[:,-1];part.append(x.copy());hist=torch.cat([torch.tensor(x[6:])[None,None,:],hist[:,:-1]],1)
   others.append(part)
  ref=np.array(others);err=float(np.max(abs((out-ref)/scale.numpy())));assert err<1e-6,(model,err)
  robot.append(dict(model=model,seed=9,origins=starts.tolist(),horizon_steps=2,max_normalized_state_difference=err,threshold=1e-6,comparison='independent SciPy Radau'))
 dump(dest/'implementation_checks.json',dict(status='pass',analytical=rows,robot=robot,algorithm_signature=algorithm_signature(),tested_script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()));print('CHECKS',rows,robot,flush=True)

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--stage',choices=['check','run'],required=True);ap.add_argument('--seed',type=int,default=9);args=ap.parse_args()
 cfg,data,cache,params,s=load();torch.set_num_threads(1)
 if args.stage=='check':checks(cfg,data,params,s);return
 dest=R/'adaptive';verified=json.loads((dest/'implementation_checks.json').read_text());assert verified['status']=='pass'
 assert verified['algorithm_signature']==algorithm_signature(),'Numerical kernels changed since verification'
 selected=json.loads((REV/'results/selected.json').read_text());scale=torch.cat([s['qstd'],s['vstd']]);rows=[];t0=time.time();seed=args.seed
 paths=[Path(__file__),R/'numerical_refinement.py',R/'adaptive_protocol.md',B/'core.py',B/'networks.py',B/'preflight/prepared.npz',B/'physics_run/best.pt']+[REV/r['path']/'best.pt' for r in selected]
 hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
 manifest=dest/f'inputs_seed{seed}.json'
 if manifest.exists():assert json.loads(manifest.read_text())==hashes,'Existing adaptive results use different inputs/code'
 else:dump(manifest,hashes)
 for label in ['capacity_control','history','history_removed']:
  source='history' if label=='history_removed' else label;r=next(r for r in selected if r['model']==source and r['seed']==seed)
  net=JointNet(7);net.load_state_dict(torch.load(REV/r['path']/'best.pt',weights_only=True));rhs=FrozenRHS(net,'history' if label=='history' else 'capacity_control',params,s,cfg).eval()
  z=np.load(REV/f'evaluations/{label}_{seed}/predictions.npz');prev=None
  for tol_name,rtol,af in [('loose',1e-6,1e-8),('tight',1e-8,1e-10)]:
   path=dest/f'{label}_{seed}_{tol_name}.npz';log=dest/f'{label}_{seed}_{tol_name}_stats.json'
   print('start',label,seed,tol_name,flush=True)
   if path.exists():pred=np.load(path)['prediction'];stat=json.loads(log.read_text())
   else:
    pred,stat=robot_rollout(rhs,data['test'],cfg,z['starts'],scale,rtol,af)
    dump(log,stat);np.savez_compressed(path,prediction=pred,starts=z['starts'])
   mx=None if prev is None else float(np.max(abs((pred[:,:,:6]-prev[:,:,:6])/s['qstd'].numpy())))
   for reg,mask in [('all',None),('low_speed',z['low_speed_mask']),('reversal',z['reversal_mask'])]:
    met=core.metric(pred[:,:,:6],z['reference'][:,:,:6],s['qstd'].numpy(),mask)
    delta=None if prev is None else core.metric(pred[:,:,:6],prev[:,:,:6],s['qstd'].numpy(),mask)['nrmse']
    rows.append(dict(model=label,seed=seed,tolerance=tol_name,rtol=rtol,absolute_scale_factor=af,regime=reg,nrmse=met['nrmse'],rmse_rad=met['rmse_rad'],tolerance_prediction_difference_nrmse=delta,max_tolerance_normalized_position_difference=mx,consistency_pass=None if delta is None else delta<=1e-4 and mx<=1e-3,seconds=stat['seconds']))
   write_csv(dest/f'metrics_seed{seed}.csv',rows);print('DONE',label,seed,tol_name,rows[-3],flush=True);prev=pred
 for p,h in hashes.items():assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h,p
 dump(dest/f'completion_seed{seed}.json',dict(status='complete',rows=len(rows),seconds=time.time()-t0,input_hashes_unchanged=True))

if __name__=='__main__':
 try:main()
 except Exception:
  d=R/'adaptive';d.mkdir(exist_ok=True);(d/f'failure_{sys.argv[-1]}.txt').write_text(traceback.format_exc(),encoding='utf-8');raise
