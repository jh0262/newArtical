"""Schedule one existing verified model independently; same numerical kernel and input manifest.

Use only after the original seed worker is paused to avoid concurrent output writers.
After all cases finish, rerun adaptive_integrator.py --stage run --seed N to rebuild its
metrics and completion record from these exact cached predictions, without integrating again.
"""
from pathlib import Path
import json,hashlib,argparse,time
import adaptive_integrator as ai
from adaptive_integrator import np,torch,load,JointNet,FrozenRHS,robot_rollout,dump,R,REV

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--seed',type=int,required=True);ap.add_argument('--model',choices=['history','history_removed'],required=True);args=ap.parse_args()
 cfg,data,cache,params,s=load();torch.set_num_threads(1);dest=R/'adaptive';seed=args.seed;label=args.model
 verified=json.loads((dest/'implementation_checks.json').read_text());assert verified['status']=='pass' and verified['algorithm_signature']==ai.algorithm_signature()
 hashes=json.loads((dest/f'inputs_seed{seed}.json').read_text())
 for p,h in hashes.items():assert sha(p)==h,p
 script_hash=sha(__file__);record=dest/f'case_execution_{label}_{seed}.json'
 if record.exists():
  prior=json.loads(record.read_text());assert prior['wrapper_sha256']==script_hash
 provenance=dict(status='running',seed=seed,model=label,wrapper_sha256=script_hash,algorithm_signature=ai.algorithm_signature(),original_input_manifest=f'inputs_seed{seed}.json',scope='Scheduling only; unchanged checked robot_rollout and advance functions',cases=[])
 dump(record,provenance)
 selected=json.loads((REV/'results/selected.json').read_text());r=next(r for r in selected if r['model']=='history' and r['seed']==seed)
 net=JointNet(7);net.load_state_dict(torch.load(REV/r['path']/'best.pt',weights_only=True));rhs=FrozenRHS(net,'history' if label=='history' else 'capacity_control',params,s,cfg).eval()
 z=np.load(REV/f'evaluations/{label}_{seed}/predictions.npz');scale=torch.cat([s['qstd'],s['vstd']])
 for name,rtol,af in [('loose',1e-6,1e-8),('tight',1e-8,1e-10)]:
  path=dest/f'{label}_{seed}_{name}.npz';log=dest/f'{label}_{seed}_{name}_stats.json'
  print('CASE START',label,seed,name,flush=True);reused=path.exists()
  if reused:
   assert log.exists();v=np.load(path);assert v['prediction'].shape==(593,150,12) and np.array_equal(v['starts'],z['starts'])
  else:
   pred,stat=robot_rollout(rhs,data['test'],cfg,z['starts'],scale,rtol,af)
   assert not path.exists(),'Another writer created output unexpectedly'
   dump(log,stat);np.savez_compressed(path,prediction=pred,starts=z['starts'])
  provenance['cases'].append(dict(tolerance=name,reused=reused,prediction_sha256=sha(path),stats_sha256=sha(log)))
  dump(record,provenance);print('CASE COMPLETE',label,seed,name,flush=True)
 for p,h in hashes.items():assert sha(p)==h,p
 assert sha(__file__)==script_hash
 provenance['status']='complete';provenance['input_hashes_unchanged']=True;dump(record,provenance)

if __name__=='__main__':main()
