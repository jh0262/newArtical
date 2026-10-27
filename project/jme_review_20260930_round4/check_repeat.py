from pathlib import Path
import sys,json,hashlib,time
R=Path(__file__).resolve().parent;B=R.parent;REV=B/'revision_v2_20260929'
sys.path.insert(0,str(REV))
from run_revision import load,JointNet,dump,write_csv
import run_model as rm
import core,torch,numpy as np
from scipy.io import loadmat

cfg,data,cache,params,s=load();torch.set_num_threads(1)
dest=R/'repeat_check';dest.mkdir(exist_ok=True);start=time.time()
source=core.SOURCE/'common_data__py_recording_2021_12_15_20H_45M.mat'
selected=json.loads((REV/'results/selected.json').read_text())
paths=[source,R/'repeat_protocol.md',Path(__file__),B/'physics_run/best.pt']+[REV/r['path']/'best.pt' for r in selected]
hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths};dump(dest/'inputs.json',hashes)
raw=loadmat(source,simplify_cells=True)['realizations'][2]['periods']
phy=core.load_physics();rows=[];signals=[];outputs={}
for per in [0,1]:
 p=raw[per];q,v,a,u=core.spectral(np.asarray(p['y_data_V'][:,:6],float)*np.pi/180,np.asarray(p['u_data_V'],float),.004,200)
 d={k:torch.tensor(x) for k,x in zip(['q','v','a','u'],[q,v,a,u])};signals.append(q)
 ids=torch.arange(32,15000);parts=[]
 with torch.no_grad():
  for ss in range(0,15000,512):
   z=phy(torch.cat([d['q'][ss:ss+512],d['v'][ss:ss+512]],1),d['u'][ss:ss+512],params['dyn'],params['friction'],False,True)
   assert not torch.linalg.cholesky_ex(z['M'])[1].any()
   parts.append((z['x_dot_result'][:,6:],z['M_inverse']))
 base=torch.cat([p[0] for p in parts]);Minv=torch.cat([p[1] for p in parts])
 mean_pred=s['amean'][None,:].expand(len(ids),6);mean_err=((mean_pred-d['a'][ids])/s['astd']).numpy()
 rows.append(dict(period=per+1,model='training_mean',seed=0,nmse=float((mean_err**2).mean())))
 for label in ['velocity','capacity_control','history','history_removed']:
  model='capacity_control' if label=='history_removed' else label;original='history' if label=='history_removed' else label
  for seed in [9,19,29]:
   r=next(r for r in selected if r['model']==original and r['seed']==seed)
   net=JointNet(1 if original=='velocity' else 7);net.load_state_dict(torch.load(REV/r['path']/'best.pt',weights_only=True));net.eval();pred=[]
   with torch.no_grad():
    for st in range(0,len(ids),512):
     ii=ids[st:st+512]
     pred.append(rm.acceleration(net,rm.features(d,ii,model,cfg,s),base[ii],Minv[ii],model,s).numpy())
   pred=np.concatenate(pred);outputs[f'p{per+1}_{label}_{seed}']=pred
   err=(pred-a[32:])/s['astd'].numpy()
   rows.append(dict(period=per+1,model=label,seed=seed,nmse=float((err**2).mean())))
 np.savez_compressed(dest/f'prepared_period{per+1}.npz',q=q,v=v,a=a,u=u)
np.savez_compressed(dest/'acceleration_outputs.npz',**outputs)
write_csv(dest/'metrics.csv',rows)
summary=[]
for per in [1,2]:
 for model in ['training_mean','velocity','capacity_control','history','history_removed']:
  vals=np.array([r['nmse'] for r in rows if r['period']==per and r['model']==model])
  summary.append(dict(period=per,model=model,mean=float(vals.mean()),sd=float(vals.std(ddof=1)) if len(vals)>1 else 0.0))
first_expected={'velocity':22.4292945764471,'capacity_control':21.84392692134388,'history':21.518670954143033}
checks={k:abs(next(r['mean'] for r in summary if r['period']==1 and r['model']==k)-v) for k,v in first_expected.items()}
assert max(checks.values())<1e-9,checks
relations=[dict(joint=j+1,position_correlation=float(np.corrcoef(signals[0][:,j],signals[1][:,j])[0,1]),position_difference_rmse_rad=float(np.sqrt(np.mean((signals[0][:,j]-signals[1][:,j])**2)))) for j in range(6)]
dependencies=[]
for per in [1,2]:
 for seed in [9,19,29]:
  diff=outputs[f'p{per}_history_{seed}']-outputs[f'p{per}_history_removed_{seed}']
  dependencies.append(dict(period=per,seed=seed,output_difference_rmse_rad_s2=float(np.sqrt(np.mean(diff**2)))))
for p,h in hashes.items():assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==h,p
write_csv(dest/'summary.csv',summary)
dump(dest/'verification.json',dict(status='pass',input_hashes_unchanged=True,first_period_differences=checks,summary=summary,repeat_relation=relations,history_output_differences=dependencies,seconds=time.time()-start,scope='Same excitation, second measured period; no independent-condition validation or new rollout; all checkpoints frozen.'))
print(json.dumps(dict(summary=summary,relations=relations,checks=checks),ensure_ascii=False))
