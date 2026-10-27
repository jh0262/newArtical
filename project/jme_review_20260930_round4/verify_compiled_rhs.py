"""Verify a separately versioned, frozen graph implementation; do not fit weights."""
from pathlib import Path
import json,time,hashlib,warnings,traceback,io
import adaptive_integrator as ai
from adaptive_integrator import np,torch,load,JointNet,FrozenRHS,robot_rollout,dump,R,REV
D=R/'compiled_execution';D.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 cfg,data,cache,params,s=load();torch.set_num_threads(1)
 selected=json.loads((REV/'results/selected.json').read_text());d=data['test'];scale=torch.cat([s['qstd'],s['vstd']])
 starts=np.load(REV/'evaluations/history_9/predictions.npz')['starts'];idx=torch.tensor(starts)
 x=torch.cat([d['q'][idx],d['v'][idx]],1);u=d['u'][idx];hist=d['v'][idx[:,None]-torch.arange(33)[None,:]]
 paths=[Path(__file__),R/'adaptive_integrator.py',R/'numerical_refinement.py',R/'external_validation/semantic_dependencies.json']
 deps=json.loads((R/'external_validation/semantic_dependencies.json').read_text());paths += [Path(p) for p in deps['hashes']]
 hashes={str(p):sha(p) for p in paths};dump(D/'verification_inputs.json',hashes)
 checks=[];adaptive=[];models=[];t0=time.time()
 for label in ['capacity_control','history','history_removed']:
  for seed in [9,19,29]:
   source='history' if label=='history_removed' else label;r=next(r for r in selected if r['model']==source and r['seed']==seed);weight=REV/r['path']/'best.pt'
   net=JointNet(7);net.load_state_dict(torch.load(weight,weights_only=True));eager=FrozenRHS(net,'history' if label=='history' else 'capacity_control',params,s,cfg).eval()
   with torch.no_grad(),warnings.catch_warnings(record=True) as ws:
    warnings.simplefilter('always');compiled=torch.jit.freeze(torch.jit.trace(eager,(x[:9],u[:9],hist[:9],torch.linspace(0,1,9)[:,None]),check_trace=False).eval())
   errors=[]
   with torch.no_grad():
    for ids in [np.array([478]),np.arange(9),np.arange(297),np.arange(593),np.array([32,411,12,587,2]),np.array([477,478])]:
     for case in ['normal','low_velocity','zero_velocity','shifted']:
      xx=x[ids].clone();uu=u[ids].clone();hh=hist[ids].clone()
      if case=='zero_velocity':xx[:,6:]=0;hh[:]=0
      if case=='low_velocity':xx[:,6:]*=1e-5;hh*=1e-5
      if case=='shifted':xx+=1e-5;uu-=.1;hh+=2e-5
      c=torch.linspace(0,1,len(ids))[:,None];a,ia=eager(xx,uu,hh,c);b,ib=compiled(xx,uu,hh,c)
      error=float((a-b).abs().max());assert torch.equal(ia,ib);assert error<1e-10,(label,seed,case,error)
      errors.append(dict(batch=len(ids),case=case,max_absolute_rhs_difference=error,inertia_flags_equal=True))
   path=D/f'{label}_{seed}.pt';buffer=io.BytesIO();torch.jit.save(compiled,buffer);path.write_bytes(buffer.getvalue());models.append(dict(model=label,seed=seed,path=str(path),sha256=sha(path),weight_sha256=sha(weight)))
   checks.append(dict(model=label,seed=seed,cases=errors,warnings=sorted(set(str(w.message) for w in ws))))
   # Changing active subsets and row-specific time values exercise rejected steps.
   for name,rtol,af in [('loose',1e-6,1e-8),('tight',1e-8,1e-10)]:
    subset=starts[[0,13,88,187,300,411,478,555,592]]
    a,sa=robot_rollout(eager,d,dict(cfg,horizon=2),subset,scale,rtol,af,False)
    b,sb=robot_rollout(compiled,d,dict(cfg,horizon=2),subset,scale,rtol,af,False)
    error=float(np.max(abs((a-b)/scale.numpy())));equal=all(sa[k]==sb[k] for k in ['accepted_steps','rejected_steps','rhs_batch_calls','min_step_s'])
    assert equal and error<1e-10,(label,seed,name,error,equal)
    adaptive.append(dict(model=label,seed=seed,tolerance=name,horizon=2,origins=subset.tolist(),max_normalized_state_difference=error,step_counts_equal=equal,eager=sa,compiled=sb))
   dump(D/'verification_progress.json',dict(rhs=checks,short_adaptive=adaptive,models=models))
   print('VERIFIED',label,seed,'rhs',max(v['max_absolute_rhs_difference'] for v in errors),'seconds',round(time.time()-t0,1),flush=True)
 # Complete difficult 0.6 s window against already retained eager tight output.
 compiled=torch.jit.load(io.BytesIO((D/'history_9.pt').read_bytes())).eval();lo=np.load(R/'adaptive/history_9_loose.npz');hi=np.load(R/'adaptive/history_9_tight.npz');assert np.array_equal(lo['starts'],hi['starts'])
 at=int(np.where(hi['starts']==11982)[0][0]);out,stats=robot_rollout(compiled,d,cfg,np.array([11982]),scale,1e-8,1e-10)
 ref=hi['prediction'][at:at+1];error=float(np.max(abs((out-ref)/scale.numpy())));assert error<1e-8,error
 np.savez_compressed(D/'difficult_origin_compiled.npz',prediction=out,starts=np.array([11982]))
 hard=dict(origin=11982,horizon=150,comparison='compiled single-origin against retained eager 593-origin result',rtol=1e-8,atol_factor=1e-10,max_normalized_state_difference=error,threshold=1e-8,stats=stats,reference_sha256=sha(R/'adaptive/history_9_tight.npz'))
 assert any(sum(r['eager']['rejected_steps'])>0 for r in adaptive)
 for p,h in hashes.items():assert sha(p)==h,p
 dump(D/'verification.json',dict(status='pass',algorithm_signature=ai.algorithm_signature(),models=models,rhs=checks,short_adaptive=adaptive,difficult_origin=hard,input_hashes_unchanged=True,seconds=time.time()-t0))
 print('COMPILED VERIFICATION PASS',hard,flush=True)
if __name__=='__main__':
 try:main()
 except Exception:
  (D/'failure.txt').write_text(traceback.format_exc(),encoding='utf-8');raise
