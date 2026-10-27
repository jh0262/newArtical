from run_revision import ROOT,load,refine_rollout,write_csv,dump
from networks import JointNet
import numpy as np,torch,json,time
import core
cfg,data,cache,params,s=load();selected=json.loads((ROOT/'results/selected.json').read_text());rows=[];checks=[]
for model in ['capacity_control','history']:
 r=next(r for r in selected if r['model']==model and r['seed']==9)
 z=np.load(ROOT/'evaluations'/f'{model}_9/predictions.npz');starts=z['starts'][::12];ref=z['reference'][::12];old=z['prediction'][::12];scale=s['qstd'].numpy()
 net=JointNet(7);net.load_state_dict(torch.load(ROOT/r['path']/'best.pt',weights_only=True));net.eval()
 same=refine_rollout(net,model,data['test'],params,s,cfg,starts[:2],1)
 err=float(np.max(abs(same-old[:2])));checks.append(dict(model=model,original_grid_max_state_error=err,passed=err<1e-10));assert err<1e-10
 two=np.load(ROOT/'results'/f'refinement_{model}.npz')['prediction'];preds={1:old,2:two}
 for ss in [4,8]:
  st=time.time();pred=refine_rollout(net,model,data['test'],params,s,cfg,starts,ss);preds[ss]=pred
  np.savez_compressed(ROOT/'results'/f'refinement_{model}_{ss}substeps.npz',prediction=pred,reference=ref,starts=starts)
  print(model,ss,'seconds',time.time()-st,flush=True)
 for ss,p in preds.items():
  met=core.metric(p[:,:,:6],ref[:,:,:6],scale)
  delta=None if ss==1 else core.metric(p[:,:,:6],preds[ss//2][:,:,:6],scale)['nrmse']
  rows.append(dict(model=model,seed=9,origins=len(starts),substeps=ss,dt=.004/ss,error_nrmse=met['nrmse'],difference_from_previous_grid_nrmse=delta))
 write_csv(ROOT/'results/integration_convergence.csv',rows)
dump(ROOT/'results/refinement_implementation_check.json',checks)
