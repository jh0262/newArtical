from pathlib import Path
import sys,json,time,io,warnings,argparse,traceback,copy
from train_controlled import R,B,load,JointNet,dump,write_csv,sha,feats
OLD=B/'jme_review_20260930_round4';sys.path.insert(0,str(OLD))
import adaptive_integrator as ai
from numerical_refinement import FrozenRHS
from networks import history_stage
import torch,numpy as np,run_model as rm,core
import evaluation_provenance as ep

def prepare():
 out=R/'rollout';out.mkdir(exist_ok=True);p=out/'prepared.npz'
 if p.exists():
  saved=json.loads((out/'preparation.json').read_text());assert sha(p)==saved['output_sha256'];src=OLD/'external_validation/rollout_inputs.npz';assert sha(src)==saved['source_sha256'];z=np.load(p);old=np.load(src);assert np.array_equal(z['starts'],np.r_[np.linspace(32,14849,9,dtype=int),old['starts']+15000]);assert z['reference'].shape==(306,150,12);assert len(z['q'])==510000
  return
 cfg,data,cache,params,s=load();torch.set_num_threads(1);src=OLD/'external_validation/rollout_inputs.npz';z=np.load(src)
 assert sha(src)==json.loads((OLD/'external_validation/preparation_complete.json').read_text())['rollout_inputs_sha256']
 starts0=np.linspace(32,14849,9,dtype=int);idx=starts0[:,None]+np.arange(1,151)[None,:];ref=np.concatenate([data['test']['q'].numpy(),data['test']['v'].numpy()],1)[idx]
 threshold=.05*np.quantile(abs(data['train']['v'].numpy()),.95,axis=0);low,rev,_=rm.regime_masks(data['test']['v'].numpy(),threshold,cfg)
 np.savez_compressed(p,**{k:np.concatenate([data['test'][k].numpy(),z[k]]) for k in ['q','v','a','u']},starts=np.r_[starts0,z['starts']+15000],reference=np.concatenate([ref,z['reference']]),low_speed_mask=np.concatenate([low[idx],z['low_speed_mask']]),reversal_mask=np.concatenate([rev[idx],z['reversal_mask']]),origin_record=np.r_[np.zeros(9,dtype=int),z['origin_record']])
 dump(out/'preparation.json',dict(status='complete',starts=starts0.tolist(),origins=306,source_sha256=sha(src),output_sha256=sha(p),amendment_sha256=sha(R/'积分阈值修订单.md')))
def main(seed,model):
 prepare();out=R/'rollout'/f'{model}_{seed}';out.mkdir(exist_ok=False);inputp=R/'rollout/prepared.npz';inputs=ep.freeze([Path(__file__),inputp,R/'rollout/preparation.json',OLD/'adaptive_integrator.py',OLD/'numerical_refinement.py']);dump(out/'inputs_initial.json',inputs)
 cfg,data,cache,params,s=load();torch.set_num_threads(1)
 for p in ep.weights(seed,s):inputs[str(p)]=sha(p)
 dump(out/'inputs.json',inputs)
 z=np.load(inputp);starts=z['starts'];d={k:torch.tensor(z[k]) for k in ['q','v','a','u']};scale=torch.cat([s['qstd'],s['vstd']]);w=R/'training'/f'seed{seed}'/f'{model}_best.pt'
 assert json.loads((w.parent/'completion.json').read_text())['status']=='complete'
 original=JointNet(7);original.load_state_dict(torch.load(w,weights_only=True));net=JointNet(7);sd=copy.deepcopy(original.state_dict())
 for k in ['w1','skip']:sd[k][:,0]=sd[k][:,0]-sd[k][:,1:].sum(1)
 net.load_state_dict(sd);net.eval();eager=FrozenRHS(net,'history',params,s,cfg).eval();ix=torch.tensor(starts);x=torch.cat([d['q'][ix],d['v'][ix]],1);u=d['u'][ix];hist=d['v'][ix[:,None]-torch.arange(33)[None,:]]
 err=[]
 with torch.no_grad():
  for count in [1,9,306]:
   for cval in [0,.375,1]:
    c=torch.full((count,1),cval);raw=history_stage(hist[:count],x[:count,6:],cfg['history_lags'],c);f=(raw-s['vmean'][None,:,None])/s['vstd'][None,:,None];delta=f.clone();delta[:,:,1:]-=delta[:,:,:1];a=original(delta);b=net(f);err.append(float((a-b).abs().max()))
  assert max(err)<1e-10,max(err)
  with warnings.catch_warnings(record=True) as ws:
   warnings.simplefilter('always');compiled=torch.jit.freeze(torch.jit.trace(eager,(x[:9],u[:9],hist[:9],torch.linspace(0,1,9)[:,None]),check_trace=False).eval())
  graphchecks=[]
  for ids in [np.array([0]),np.arange(9),np.arange(306),np.array([15,299,31,0])]:
   for shift in [0.,1e-5]:
    xx=x[ids].clone()+shift;hh=hist[ids]+shift;uu=u[ids]-.1*shift;c=torch.linspace(0,1,len(ids))[:,None];a,ia=eager(xx,uu,hh,c);b,ib=compiled(xx,uu,hh,c);de=float((a-b).abs().max());assert torch.equal(ia,ib) and de<1e-10;graphchecks.append(de)
  a,sa=ai.robot_rollout(eager,d,dict(cfg,horizon=2),starts[[0,4,8,9,105,305]],scale,1e-8,1e-10,False);b,sb=ai.robot_rollout(compiled,d,dict(cfg,horizon=2),starts[[0,4,8,9,105,305]],scale,1e-8,1e-10,False);de=float(np.max(abs((a-b)/scale.numpy())));assert de<1e-10;assert all(sa[k]==sb[k] for k in ['accepted_steps','rejected_steps','rhs_batch_calls','min_step_s'])
 b=io.BytesIO();torch.jit.save(compiled,b);(out/'rhs.pt').write_bytes(b.getvalue());dump(out/'verification.json',dict(status='pass',coordinate_max_output_difference=max(err),compiled_max_rhs_difference=max(graphchecks),short_rollout_max_scaled_difference=de,trace_warnings=sorted(set(str(v.message) for v in ws)),kernel_signature=ai.algorithm_signature()))
 result={};metrics=[];t0=time.time()
 for label,rtol,af in [('loose',1e-6,1e-8),('tight',1e-8,1e-10)]:
  pred,st=ai.robot_rollout(compiled,d,cfg,starts,scale,rtol,af);np.savez_compressed(out/f'{label}.npz',prediction=pred,starts=starts);dump(out/f'{label}_stats.json',st);result[label]=pred
 def window_checks(a,b,indices):
  rows=[]
  for local,ix in enumerate(indices):
   diff=a[local:local+1,:,:6]-b[local:local+1,:,:6];mx=float(np.max(abs(diff/s['qstd'].numpy())));rr={};ok=mx<=1e-3
   for key in ['all','low_speed','reversal']:
    mask=None if key=='all' else z[key+'_mask'][ix:ix+1];dd=core.metric(a[local:local+1,:,:6],b[local:local+1,:,:6],s['qstd'].numpy(),mask)['nrmse'];rr[key]=dd
    if dd is not None and dd>1e-4:ok=False
   rows.append(dict(origin_index=int(ix),start=int(starts[ix]),max_scaled_position_difference=mx,nrmse_difference=rr,pass_check=ok))
  return rows
 metrics=window_checks(result['tight'],result['loose'],np.arange(len(starts)));failed=np.array([r['origin_index'] for r in metrics if not r['pass_check']],dtype=int);dump(out/'per_window_tolerance_checks.json',metrics)
 finecheck=None
 if len(failed):
  fine,st=ai.robot_rollout(compiled,d,cfg,starts[failed],scale,1e-10,1e-12);np.savez_compressed(out/'fine_failed.npz',prediction=fine,origin_indices=failed,starts=starts[failed]);dump(out/'fine_stats.json',st)
  frows=window_checks(fine,result['tight'][failed],failed);remaining=[r['origin_index'] for r in frows if not r['pass_check']];dump(out/'per_window_fine_checks.json',frows)
  finecheck=dict(indices=failed.tolist(),remaining_failed_indices=remaining,per_window_checks=frows,pass_check=len(remaining)==0)
 for p,h in inputs.items():assert sha(p)==h,p
 dump(out/'completion.json',dict(status='complete',seed=seed,model=model,seconds=time.time()-t0,initial_failed_indices=failed.tolist(),max_scaled_position_difference=max(r['max_scaled_position_difference'] for r in metrics),fine_check=finecheck,numerical_check_pass=len(failed)==0 or finecheck['pass_check'],inputs_unchanged=True,outputs={p.name:sha(p) for p in out.iterdir() if p.is_file()}));print('ROLLOUT COMPLETE',model,seed,flush=True)
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--prepare',action='store_true');ap.add_argument('--seed',type=int);ap.add_argument('--model',choices=['Hdelta','Cdelta']);args=ap.parse_args()
 if args.prepare:prepare()
 else:main(args.seed,args.model)
