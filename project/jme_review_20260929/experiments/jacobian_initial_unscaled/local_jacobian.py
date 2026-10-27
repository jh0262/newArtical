"""Exploratory numerical-sensitivity diagnostic; no stability certification.
Frozen-past 12-state instantaneous RHS Jacobian; histories from test reference.
Before calculation choose 128 equally spaced valid test timestamps, every D/H/H0
selected seed, centered steps 1e-6 and 5e-7. No extreme-point cherry-picking.
"""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parent;REV=ROOT.parent.parent/'revision_v2_20260929';sys.path.insert(0,str(REV))
from run_revision import load,write_csv,dump,JointNet
import numpy as np,torch,core
cfg,data,cache,params,s=load();torch.set_num_threads(1);phy=core.load_physics()
selected=json.loads((REV/'results/selected.json').read_text());ids=torch.tensor(np.linspace(32,14999,128,dtype=int));d=data['test'];x=torch.cat([d['q'][ids],d['v'][ids]],1);u=d['u'][ids]
past=d['v'][ids[:,None]-torch.tensor(cfg['history_lags'])[None,:]].permute(0,2,1);rows=[]
with torch.no_grad():
 for label in ['capacity_control','history','history_removed']:
  for seed in [9,19,29]:
   r=next(r for r in selected if r['model']==('history' if label=='history_removed' else label) and r['seed']==seed)
   net=JointNet(7);net.load_state_dict(torch.load(REV/r['path']/'best.pt',weights_only=True));net.eval()
   def rhs(state):
    p=phy(state,u,params['dyn'],params['friction'],False,True)
    raw=past.clone() if label=='history' else state[:,6:,None].repeat(1,1,7)
    raw[:,:,0]=state[:,6:]
    tau=net((raw-s['vmean'][None,:,None])/s['vstd'][None,:,None])*s['tstd']+s['tmean']
    a=p['x_dot_result'][:,6:]+torch.bmm(p['M_inverse'],tau[:,:,None])[:,:,0]
    return torch.cat([state[:,6:],a],1)
   mats=[]
   for eps in [1e-6,5e-7]:
    cols=[]
    for j in range(12):
     delta=torch.zeros_like(x);delta[:,j]=eps
     cols.append(((rhs(x+delta)-rhs(x-delta))/(2*eps)).numpy())
    mats.append(np.stack(cols,axis=-1))
   eig=np.linalg.eigvals(mats[-1]);relative=float(np.linalg.norm(mats[0]-mats[1])/max(np.linalg.norm(mats[1]),1e-30))
   for k,idx in enumerate(ids):
    vals=eig[k];stable=vals[np.real(vals)<-1e-6]
    row=dict(model=label,seed=seed,index=int(idx),min_real_eigenvalue=float(np.min(vals.real)),max_real_eigenvalue=float(np.max(vals.real)),jacobian_step_relative_difference=relative)
    for dt in [.004,.002,.001,.0005]:
     z=dt*stable; amp=abs(1+z+z**2/2+z**3/6+z**4/24)
     row[f'max_RK4_amplification_negative_modes_{dt:g}s']=float(np.max(amp)) if len(amp) else 0
    rows.append(row)
   np.savez_compressed(ROOT/f'jacobian_{label}_{seed}.npz',jacobian=mats[-1],indices=ids.numpy(),eigenvalues=eig)
write_csv(ROOT/'local_jacobian.csv',rows)
summary=[]
for label in ['capacity_control','history','history_removed']:
 a=[r for r in rows if r['model']==label];summary.append(dict(model=label,points=len(a),minimum_real_eigenvalue=min(r['min_real_eigenvalue'] for r in a),maximum_real_eigenvalue=max(r['max_real_eigenvalue'] for r in a),max_jacobian_step_difference=max(r['jacobian_step_relative_difference'] for r in a),negative_mode_RK4_outside_unit_disk={str(dt):sum(r[f'max_RK4_amplification_negative_modes_{dt:g}s']>1+1e-6 for r in a) for dt in [.004,.002,.001,.0005]}))
dump(ROOT/'local_jacobian_summary.json',summary);print(json.dumps(summary))
