from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parent;REV=ROOT.parent.parent/'revision_v2_20260929';sys.path.insert(0,str(REV))
from run_revision import load,write_csv,dump,JointNet
import torch,numpy as np,run_model as rm
cfg,data,cache,params,s=load();torch.set_num_threads(1);rows=[]
selected=json.loads((REV/'results/selected.json').read_text())
with torch.no_grad():
 for split,d in data.items():
  ids=torch.arange(32,15000);a=d['a'][ids];c=cache[split]
  preds={'train_mean':s['amean'][None,:].expand_as(a),'zero':torch.zeros_like(a),'physics_no_friction':c['base_acc'][ids]}
  for r in selected:
   net=JointNet(1 if r['model']=='velocity' else 7);net.load_state_dict(torch.load(REV/r['path']/'best.pt',weights_only=True));net.eval()
   preds[f"{r['model']}_{r['seed']}"]=rm.acceleration(net,rm.features(d,ids,r['model'],cfg,s),c['base_acc'][ids],c['Minv'][ids],r['model'],s)
  for label,p in preds.items():
   e=p-a;ms=(e**2).mean(0).numpy();nm=ms/s['astd'].numpy()**2
   for j in range(6):rows.append(dict(split=split,model=label,joint=j+1,rmse_rad_s2=float(np.sqrt(ms[j])),nmse=float(nm[j]),training_acc_std_rad_s2=float(s['astd'][j]),test_reference_std_rad_s2=float(a[:,j].std(unbiased=False))))
write_csv(ROOT/'acceleration_scale.csv',rows)
dump(ROOT/'scale_summary.json',[dict(split=split,model=model,nmse=float(np.mean([r['nmse'] for r in rows if r['split']==split and r['model']==model]))) for split in data for model in preds])
print('scale analysis complete',len(rows))
