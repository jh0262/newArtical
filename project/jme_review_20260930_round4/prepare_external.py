from pathlib import Path
import sys,json,hashlib,time,traceback
R=Path(__file__).resolve().parent;B=R.parent;REV=B/'revision_v2_20260929';sys.path.insert(0,str(REV))
from run_revision import load,dump,write_csv,JointNet
import core,run_model as rm,torch,numpy as np
from scipy.io import loadmat
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
 cfg,data,cache,params,s=load();torch.set_num_threads(1);D=R/'external_validation';D.mkdir(exist_ok=True)
 catalog=json.loads((R/'external_data/mapping_and_eligibility.json').read_text());assert catalog['status']=='pass'
 assert catalog['protocol_sha256']==sha(R/'external_validation_protocol.md')
 entries=[r for r in catalog['eligibility'] if r['eligible']];assert len(entries)==33
 selected=json.loads((REV/'results/selected.json').read_text());nets=[]
 for label in ['velocity','capacity_control','history','history_removed']:
  source='history' if label=='history_removed' else label;mode='capacity_control' if label=='history_removed' else label
  for seed in [9,19,29]:
   r=next(r for r in selected if r['model']==source and r['seed']==seed)
   net=JointNet(1 if source=='velocity' else 7);net.load_state_dict(torch.load(REV/r['path']/'best.pt',weights_only=True));net.eval();nets.append((label,mode,seed,net))
 paths=[Path(__file__),R/'external_validation_protocol.md',R/'external_validation_protocol_amendment.md',R/'external_data/mapping_and_eligibility.json',B/'preflight/prepared.npz',B/'physics_run/best.pt',B/'core.py',B/'run_model.py',B/'networks.py']+[REV/r['path']/'best.pt' for r in selected]
 paths+=sorted(set(R/'external_data/unpacked/raw_data'/r['file'] for r in entries))
 hashes={str(p):sha(p) for p in paths};dump(D/'inputs_prepare.json',hashes)
 threshold=cfg['low_speed_fraction_of_train_p95']*np.quantile(np.abs(data['train']['v'].numpy()),.95,axis=0)
 relative=np.linspace(32,15000-cfg['horizon']-1,9,dtype=int);phy=core.load_physics();rows=[];coverage=[];combined={k:[] for k in ['q','v','a','u']};starts=[];refs=[];lows=[];revs=[];origin_record=[]
 t0=time.time();loaded_name=None;loaded=None
 for i,entry in enumerate(entries):
  if entry['file']!=loaded_name:
   loaded=loadmat(R/'external_data/unpacked/raw_data'/entry['file'],simplify_cells=True);loaded_name=entry['file']
  begin=entry['start'];sl=slice(begin,begin+15000);rawq=np.concatenate([loaded['q_se_meas'][:3,sl],loaded['q_mot_meas'][3:,sl]],0).T*np.pi/180
  q,v,a,u=core.spectral(rawq,loaded['tau_meas'][:,sl].T,.004,200)
  d={k:torch.tensor(x) for k,x in zip(['q','v','a','u'],[q,v,a,u])};np.savez_compressed(D/f'prepared_{i+1:02d}.npz',q=q,v=v,a=a,u=u)
  for k in combined:combined[k].append(d[k].numpy())
  low,rev,events=rm.regime_masks(v,threshold,cfg);target=relative[:,None]+np.arange(1,cfg['horizon']+1)[None,:]
  refs.append(np.concatenate([q,v],1)[target]);lows.append(low[target]);revs.append(rev[target]);starts.extend((relative+i*15000).tolist());origin_record.extend([i+1]*len(relative))
  coverage.append(dict(record=i+1,file=entry['file'],realization=entry['realization'],source_start=begin,origins=relative.tolist(),threshold_rad_s=threshold.tolist(),low_counts=low.sum(0).tolist(),reversal_counts=rev.sum(0).tolist(),events=events,payload_field_present=entry['payload_field_present']))
  ids=torch.arange(32,15000);parts=[]
  with torch.no_grad():
   for j in range(0,15000,512):
    p=phy(torch.cat([d['q'][j:j+512],d['v'][j:j+512]],1),d['u'][j:j+512],params['dyn'],params['friction'],False,True)
    assert not torch.linalg.cholesky_ex(p['M'])[1].any(),('inertia',i,j)
    parts.append((p['x_dot_result'][:,6:],p['M_inverse']))
   base=torch.cat([p[0] for p in parts]);inv=torch.cat([p[1] for p in parts]);outputs={'physics_no_friction':base[ids].numpy()}
   mean=s['amean'][None,:].expand(len(ids),6).numpy()
   rows.append(dict(record=i+1,model='training_mean',seed=0,nmse=float(np.mean(((mean-a[32:])/s['astd'].numpy())**2))))
   rows.append(dict(record=i+1,model='physics_no_friction',seed=0,nmse=float(np.mean(((outputs['physics_no_friction']-a[32:])/s['astd'].numpy())**2))))
   for label,mode,seed,net in nets:
    predictions=[]
    for j in range(0,len(ids),512):
     ii=ids[j:j+512];predictions.append(rm.acceleration(net,rm.features(d,ii,mode,cfg,s),base[ii],inv[ii],mode,s).numpy())
    pred=np.concatenate(predictions);assert np.isfinite(pred).all();outputs[f'{label}_{seed}']=pred
    rows.append(dict(record=i+1,model=label,seed=seed,nmse=float(np.mean(((pred-a[32:])/s['astd'].numpy())**2))))
  np.savez_compressed(D/f'acceleration_{i+1:02d}.npz',**outputs);write_csv(D/'pointwise_metrics.csv',rows)
  print('PREPARED',i+1,'of',len(entries),'seconds',round(time.time()-t0,1),flush=True)
 dump(D/'coverage.json',coverage)
 np.savez_compressed(D/'rollout_inputs.npz',**{k:np.concatenate(v) for k,v in combined.items()},starts=np.array(starts),reference=np.concatenate(refs),low_speed_mask=np.concatenate(lows),reversal_mask=np.concatenate(revs),origin_record=np.array(origin_record),relative_origins=relative)
 for p,h in hashes.items():assert sha(p)==h,p
 dump(D/'preparation_complete.json',dict(status='complete',records=33,origins_per_record=9,total_origins=len(starts),pointwise_rows=len(rows),input_hashes_unchanged=True,rollout_inputs_sha256=sha(D/'rollout_inputs.npz'),seconds=time.time()-t0))
 print('EXTERNAL PREPARATION COMPLETE',flush=True)

if __name__=='__main__':
 try:main()
 except Exception:
  d=R/'external_validation';d.mkdir(exist_ok=True);(d/'preparation_failure.txt').write_text(traceback.format_exc(),encoding='utf-8');raise
