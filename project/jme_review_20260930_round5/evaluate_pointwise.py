from pathlib import Path
import sys,time,json
from train_controlled import R,B,load,JointNet,dump,write_csv,sha,feats,infer
import torch,numpy as np,core
import evaluation_provenance as ep
OLD=B/'jme_review_20260930_round4';O=R/'pointwise'

def donors(v,bounds,std):
 n=len(v);maps=np.full((3,n,6),-1,dtype=np.int32);distance=[]
 gens=[np.random.default_rng(i) for i in [73031,73032,73033]]
 for j in range(6):
  bins=np.searchsorted(bounds[j][1:-1],v[:,j],side='right')
  for b in range(20):
   ix=np.where(bins==b)[0];order=ix[np.argsort(v[ix,j])];sv=v[order,j]
   lower=np.searchsorted(sv,v[ix,j]-.05*std[j]);upper=np.searchsorted(sv,v[ix,j]+.05*std[j],side='right')
   for i,lo,hi in zip(ix,lower,upper):
    choices=order[lo:hi];choices=choices[abs(choices-i)>32]
    if len(choices):
     for rep,g in enumerate(gens):maps[rep,i,j]=g.choice(choices)
 valid=(maps>=0).all(2)
 for rep in range(3):
  ii=np.where(valid[rep])[0];ds=np.stack([abs(v[maps[rep,ii,j],j]-v[ii,j])/std[j] for j in range(6)],1)
  unique=[len(np.unique(maps[rep,ii,j])) for j in range(6)]
  distance.append(dict(rep=rep,covered=int(len(ii)),coverage=float(valid[rep].mean()),max_velocity_gap_scaled=float(ds.max()) if len(ii) else None,mean_velocity_gap_scaled=float(ds.mean()) if len(ii) else None,unique_donors_by_joint=unique,reuse_fraction_by_joint=[1-u/len(ii) for u in unique] if len(ii) else [None]*6))
 return maps,valid,distance
def stats(a,ref,s):
 mse=((a-ref)**2).mean(0);return dict(nmse=float((mse/s['astd'].square()).mean()),rmse_rad_s2=mse.sqrt().tolist(),joint_nmse=(mse/s['astd'].square()).tolist())
def main():
 O.mkdir(exist_ok=False);inputs=ep.freeze([Path(__file__)]+list((OLD/'external_validation').glob('prepared_*.npz')));dump(O/'inputs_initial.json',inputs)
 cfg,data,cache,params,s=load();torch.set_num_threads(1);phy=core.load_physics();nets={};t0=time.time()
 for seed in [9,19,29]:
  p=R/'training'/f'seed{seed}';assert json.loads((p/'completion.json').read_text())['status']=='complete'
  for wp in ep.weights(seed,s):inputs[str(wp)]=sha(wp)
  for name in ['Ds','Vm','Cdelta','Hdelta']:
   for which in ['best','final']:
    w=p/f'{name}_{which}.pt';inputs[str(w)]=sha(w);n=JointNet(1 if name=='Vm' else 7);n.load_state_dict(torch.load(w,weights_only=True));n.eval();nets[(seed,name,which)]=n
 dump(O/'inputs.json',inputs)
 bounds=np.quantile(data['train']['v'][32:].numpy(),np.linspace(0,1,21),axis=0).T;bounds[:,0]=-np.inf;bounds[:,-1]=np.inf
 rows=[];perms=[];coverage=[];labels=['train','validation','test']+[f'peer_{i:02d}' for i in range(1,34)]
 for label in labels:
  if label in data:d=data[label];c={k:cache[label][k][32:] for k in ['base_acc','Minv']}
  else:
   pp=OLD/'external_validation'/f'prepared_{int(label[-2:]):02d}.npz';inputs[str(pp)]=sha(pp);z=np.load(pp);d={k:torch.tensor(z[k]) for k in ['q','v','a','u']};parts=[]
   with torch.no_grad():
    for i in range(32,15000,512):
     p=phy(torch.cat([d['q'][i:i+512],d['v'][i:i+512]],1),d['u'][i:i+512],params['dyn'],params['friction'],False,True)
     assert not torch.linalg.cholesky_ex(p['M'])[1].any();parts.append((p['x_dot_result'][:,6:],p['M_inverse']))
   c=dict(base_acc=torch.cat([x[0] for x in parts]),Minv=torch.cat([x[1] for x in parts]))
  f=feats(d,s);ref=d['a'][32:];preds={};rows.append(dict(record=label,seed=0,model='training_mean',checkpoint='fixed',**stats(s['amean'].expand_as(ref),ref,s)))
  for (seed,name,which),n in nets.items():
   a=infer(n,f[name],c,s);preds[f'{name}_{seed}_{which}']=a.numpy();rows.append(dict(record=label,seed=seed,model=name,checkpoint=which,**stats(a,ref,s)))
  np.savez_compressed(O/f'{label}_predictions.npz',**preds)
  maps,valid,dist=donors(d['v'][32:].numpy(),bounds,s['vstd'].numpy());np.savez_compressed(O/f'{label}_donors.npz',donor_active_index=maps,valid=valid);coverage.extend([dict(record=label,**v) for v in dist])
  for rep in range(3):
   ids=np.where(valid[rep])[0]
   if not len(ids):continue
   cf={k:v[ids] for k,v in c.items()};xx=f['Hdelta'][ids].clone()
   for j in range(6):xx[:,j,1:]=f['Hdelta'][maps[rep,ids,j],j,1:]
   for seed in [9,19,29]:
    a=infer(nets[(seed,'Hdelta','best')],xx,cf,s);true=torch.tensor(preds[f'Hdelta_{seed}_best'][ids]);target=ref[ids]
    perms.append(dict(record=label,seed=seed,rep=rep,covered=len(ids),true_nmse=stats(true,target,s)['nmse'],permuted_nmse=stats(a,target,s)['nmse'],prediction_change_rmse_rad_s2=(a-true).square().mean(0).sqrt().tolist()))
    np.save(O/f'{label}_permuted_{seed}_{rep}.npy',a.numpy())
  dump(O/'metrics.json',rows);dump(O/'permutation_metrics.json',perms);dump(O/'coverage.json',coverage);print('POINTWISE',label,'seconds',round(time.time()-t0),flush=True)
 for p,h in inputs.items():assert sha(p)==h
 dump(O/'completion.json',dict(status='complete',records=len(labels),models=len(nets),seconds=time.time()-t0,inputs_unchanged=True,outputs={p.name:sha(p) for p in O.iterdir() if p.is_file()}))
if __name__=='__main__':main()
