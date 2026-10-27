from pathlib import Path
import json
from train_controlled import R,B,sha
import torch
OLD=B/'jme_review_20260930_round4'
def freeze(extra):
 dep=OLD/'external_validation/semantic_dependencies.json';d=json.loads(dep.read_text());assert d['status']=='pass'
 for p,h in d['hashes'].items():assert sha(p)==h,p
 paths=[Path(p) for p in d['hashes']]+[dep,Path(__file__),R/'train_controlled.py',R/'冻结实验协议.md',R/'积分阈值修订单.md',R/'供体抽样命名澄清.md',B/'preflight/prepared.npz',B/'physics_run/best.pt']+list(extra)
 return {str(p):sha(p) for p in paths}
def weights(seed,s):
 p=R/'training'/f'seed{seed}';c=json.loads((p/'completion.json').read_text());assert c['status']=='complete'
 for name,h in c['outputs'].items():
  if name.endswith('.pt'):assert sha(p/name)==h,p/name
 old=torch.load(p/'scalers.pt',weights_only=True);assert set(s)==set(old) and all(torch.equal(s[k],old[k]) for k in s)
 return [p/'completion.json',p/'scalers.pt']+[p/n for n in c['outputs'] if n.endswith('.pt')]
