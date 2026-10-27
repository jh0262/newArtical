"""Pointwise frozen-network input intervention; no training, no future-input claims."""
from run_revision import ROOT,BASE,load,dump,write_csv
import numpy as np,torch,json
import run_model as rm
from networks import JointNet

cfg,data,cache,params,s=load();rows=[]
selected=json.loads((ROOT/'results/selected.json').read_text())
for stage in ['original','supplementary']:
 for seed in cfg['seeds']:
  if stage=='original':p=BASE/f'runs/history_seed{seed}_a/best.pt'
  else:p=ROOT/next(r['path'] for r in selected if r['model']=='history' and r['seed']==seed)/'best.pt'
  net=JointNet(7);net.load_state_dict(torch.load(p,weights_only=True));net.eval()
  for split,d in data.items():
   yh=[];y0=[];truth=[]
   with torch.no_grad():
    for start in range(32,15000,1024):
     ids=torch.arange(start,min(15000,start+1024));c=cache[split]
     for dest,model in [(yh,'history'),(y0,'capacity_control')]:
      feat=rm.features(d,ids,model,cfg,s)
      aa=rm.acceleration(net,feat,c['base_acc'][ids],c['Minv'][ids],model,s)
      dest.append(aa.numpy())
     truth.append(d['a'][ids].numpy())
   h=np.concatenate(yh);a0=np.concatenate(y0);a=np.concatenate(truth);scale=s['astd'].numpy()
   rows.append(dict(stage=stage,seed=seed,split=split,history_acc_nmse=float(np.mean(((h-a)/scale)**2)),removed_acc_nmse=float(np.mean(((a0-a)/scale)**2)),intervention_acc_nrmse=float(np.sqrt(np.mean(((h-a0)/scale)**2))),intervention_acc_rmse_rad_s2=float(np.sqrt(np.mean((h-a0)**2)))))
write_csv(ROOT/'results/pointwise_dependence.csv',rows)
print(json.dumps(rows,ensure_ascii=False))
