from pathlib import Path
import hashlib,json
from adaptive_integrator import R,B,REV,load,torch,dump,core
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
cfg,data,cache,params,s=load();torch.set_num_threads(1)
assert cfg['horizon']==150 and cfg['dt']==.004 and cfg['history_lags']==[0,1,2,4,8,16,32]
paths=[Path(__file__),B/'config.json',B/'physics_run/cache.pt',REV/'results/selected.json',REV/'run_revision.py',B/'run_model.py',B/'bootstrap.py',B/'core.py',B/'networks.py']
paths += [core.SOURCE/('roblue__sympybotconv_'+tag+'_code.py') for tag in ['M','C','g']]+[core.SOURCE/'roblue__roblue.py']
checks=[]
for model in ['velocity','capacity_control','history','history_removed']:
 for seed in [9,19,29]:
  p=REV/f'evaluations/{model}_{seed}/scalers.pt'
  if p.exists():
   prior=torch.load(p,weights_only=True);assert set(prior)==set(s)
   assert all(torch.equal(prior[k],s[k]) for k in s),(model,seed)
   paths.append(p);checks.append(dict(model=model,seed=seed,all_scalers_exact_equal=True))
assert len(checks)>=9
dump(R/'external_validation/semantic_dependencies.json',dict(status='pass',timing='Recorded after pointwise preparation and before new-trajectory rollout; compares current scalers with all available historical selected-evaluation scalers',hashes={str(p):sha(p) for p in paths},config=cfg,scalers={k:v.numpy().tolist() for k,v in s.items()},checks=checks))
print('DEPENDENCIES PASS',len(checks),'historical scaler sets',len(paths),'files')
