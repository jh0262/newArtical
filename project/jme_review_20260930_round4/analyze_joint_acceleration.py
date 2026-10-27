"""Descriptive joint decomposition of saved pointwise confirmation errors; no fitting."""
from pathlib import Path
import json,hashlib,datetime
from adaptive_integrator import R,load,np,dump,write_csv
cfg,data,cache,params,s=load();E=R/'external_validation';O=R/'joint_acceleration';O.mkdir(exist_ok=True)
astd=s['astd'].numpy();amean=s['amean'].numpy();rows=[];inputs={}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
models=['training_mean','physics_no_friction','velocity','capacity_control','history','history_removed']
for record in range(1,34):
 pp=E/f'prepared_{record:02d}.npz';ap=E/f'acceleration_{record:02d}.npz';inputs[str(pp)]=sha(pp);inputs[str(ap)]=sha(ap)
 reference=np.load(pp)['a'][32:];saved=np.load(ap)
 for model in models:
  candidates=[np.broadcast_to(amean,reference.shape)] if model=='training_mean' else [saved[model]] if model=='physics_no_friction' else [saved[f'{model}_{seed}'] for seed in [9,19,29]]
  mse=np.mean([np.mean((a-reference)**2,axis=0) for a in candidates],axis=0);nmse=mse/astd**2
  for j in range(6):rows.append(dict(record=record,model=model,joint=j+1,nmse=float(nmse[j]),mse_rad_s2_squared=float(mse[j])))
summary=[]
for model in models:
 joint=np.array([np.mean([r['nmse'] for r in rows if r['model']==model and r['joint']==j]) for j in range(1,7)])
 rmse=np.array([np.sqrt(np.mean([r['mse_rad_s2_squared'] for r in rows if r['model']==model and r['joint']==j])) for j in range(1,7)])
 summary.append(dict(model=model,joint_nmse=joint.tolist(),joint_rmse_rad_s2=rmse.tolist(),overall_nmse=float(joint.mean()),largest_joint=int(joint.argmax()+1),largest_joint_fraction=float(joint.max()/joint.sum())))
write_csv(O/'per_record_joint.csv',rows)
for p,h in inputs.items():assert sha(p)==h,p
dump(O/'summary.json',dict(status='complete',kind='posthoc descriptive decomposition of existing pointwise results; no model selection or fitting',created_at=datetime.datetime.now().astimezone().isoformat(),acceleration_std=astd.tolist(),summary=summary,source_hashes=inputs,script_sha256=sha(__file__)))
print(json.dumps(summary,ensure_ascii=False))
