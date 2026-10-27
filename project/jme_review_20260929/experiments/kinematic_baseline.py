from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parent;REV=ROOT.parent.parent/'revision_v2_20260929';sys.path.insert(0,str(REV))
from run_revision import load,write_csv,dump
import numpy as np,torch,core
cfg,data,cache,params,s=load();d=data['test'];torch.set_num_threads(1)
z=np.load(REV/'evaluations/capacity_control_9/predictions.npz');starts=z['starts'];ref=z['reference'][:,:,:6]
t=np.arange(1,cfg['horizon']+1)[None,:,None]*cfg['dt'];q=d['q'][starts].numpy()[:,None,:];v=d['v'][starts].numpy()[:,None,:]
rows=[]
for label,pred in [('position_hold',np.repeat(q,cfg['horizon'],axis=1)),('constant_velocity',q+v*t),('training_mean_acceleration',q+v*t+.5*s['amean'].numpy()[None,None,:]*t*t)]:
 for regime,mask in [('all',None),('low_speed',z['low_speed_mask']),('reversal',z['reversal_mask'])]:
  m=core.metric(pred,ref,s['qstd'].numpy(),mask);rows.append(dict(model=label,regime=regime,nrmse=m['nrmse'],rmse_rad=m['rmse_rad'],endpoint_nrmse=m['endpoint_nrmse']))
 np.savez_compressed(ROOT/f'{label}.npz',prediction=pred,starts=starts)
write_csv(ROOT/'kinematic_baselines.csv',rows);print(json.dumps(rows))
