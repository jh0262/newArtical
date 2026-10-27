import bootstrap
import json,time,hashlib,platform,os
from datetime import datetime
from pathlib import Path
import numpy as np, torch, scipy
from scipy.io import loadmat
import core
root=Path(__file__).resolve().parent
out=root/'preflight'; out.mkdir(exist_ok=True)
torch.set_default_dtype(torch.float64)
raw=core.SOURCE/'common_data__py_recording_2021_12_15_20H_45M.mat'
m=loadmat(raw,simplify_cells=True)
arrays={}
for name,real in zip(['train','validation','test'],m['realizations']):
    p=real['periods'][0]
    arrays[name+'_q_raw']=np.asarray(p['y_data_V'][:,:6],dtype=float)*np.pi/180
    arrays[name+'_u_raw']=np.asarray(p['u_data_V'],dtype=float)
    q,v,a,u=core.spectral(arrays[name+'_q_raw'],arrays[name+'_u_raw'],.004,200)
    for key,value in zip(['q','v','a','u'],[q,v,a,u]): arrays[name+'_'+key]=value
np.savez_compressed(out/'prepared.npz',**arrays)
phy=core.load_physics()
x=torch.tensor(np.c_[arrays['train_q'][::30],arrays['train_v'][::30]])
u=torch.tensor(arrays['train_u'][::30]); dyn=torch.zeros(66,requires_grad=True); friction=torch.zeros(30,requires_grad=True)
bench=[]
for threads in [1,4]:
    torch.set_num_threads(threads)
    t=time.perf_counter()
    for _ in range(3):
        r=phy(x,u,dyn,friction,True,True)
        r['x_dot_result'][:,6:].square().mean().backward()
        dyn.grad=None; friction.grad=None
    bench.append({'threads':threads,'batch':len(x),'forward_backward_seconds':(time.perf_counter()-t)/3})
torch.set_num_threads(1)
with torch.no_grad():
    p=phy(x,u,torch.zeros(66),torch.zeros(30),True,True)
    min_eig=float(torch.linalg.eigvalsh(p['M']).min())
threshold=.05*np.quantile(np.abs(arrays['train_v']),.95,axis=0)
report=dict(time=datetime.now().astimezone().isoformat(),python=platform.python_version(),torch=torch.__version__,numpy=np.__version__,scipy=scipy.__version__,cpu_logical=os.cpu_count(),raw_sha256=hashlib.sha256(raw.read_bytes()).hexdigest(),source_code_sha256=hashlib.sha256((core.SOURCE/'roblue__roblue.py').read_bytes()).hexdigest(),benchmark=bench,min_sampled_inertia_eigenvalue=min_eig,low_speed_threshold_train_only=threshold.tolist(),data_shapes={k:list(v.shape) for k,v in arrays.items()},finite=all(np.isfinite(v).all() for v in arrays.values()),note='Read/prepare real records and short mathematical runtime checks only; no model fitting in this preflight.')
(out/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
