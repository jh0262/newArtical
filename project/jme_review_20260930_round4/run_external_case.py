"""Frozen-model confirmation on all 33 eligible trajectories; no fitting."""
from pathlib import Path
import argparse,json,hashlib,time,traceback
import adaptive_integrator as ai
from adaptive_integrator import np,torch,load,JointNet,FrozenRHS,robot_rollout,dump,R,REV

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--seed',required=True,type=int);ap.add_argument('--model',required=True,choices=['capacity_control','history','history_removed']);a=ap.parse_args()
 D=R/'external_validation';cfg,data,cache,params,s=load();torch.set_num_threads(1)
 assert cfg['horizon']==150 and cfg['dt']==.004 and cfg['history_lags']==[0,1,2,4,8,16,32]
 dep=json.loads((D/'semantic_dependencies.json').read_text());assert dep['status']=='pass'
 for p,h in dep['hashes'].items():assert sha(p)==h,p
 assert {k:v.numpy().tolist() for k,v in s.items()}==dep['scalers']
 verified=json.loads((R/'adaptive/implementation_checks.json').read_text());assert verified['status']=='pass' and verified['algorithm_signature']==ai.algorithm_signature()
 prep=json.loads((D/'preparation_complete.json').read_text());assert prep['status']=='complete' and prep['records']==33 and prep['pointwise_rows']==462
 assert sha(D/'rollout_inputs.npz')==prep['rollout_inputs_sha256']
 for p,h in json.loads((D/'inputs_prepare.json').read_text()).items():assert sha(p)==h,p
 z=np.load(D/'rollout_inputs.npz');d={k:torch.tensor(z[k]) for k in ['q','v','a','u']};starts=z['starts'];assert len(starts)==297
 selected=json.loads((REV/'results/selected.json').read_text());source='history' if a.model=='history_removed' else a.model;r=next(r for r in selected if r['model']==source and r['seed']==a.seed)
 weight=REV/r['path']/'best.pt';net=JointNet(7);net.load_state_dict(torch.load(weight,weights_only=True));rhs=FrozenRHS(net,'history' if a.model=='history' else 'capacity_control',params,s,cfg).eval();scale=torch.cat([s['qstd'],s['vstd']])
 paths=[Path(__file__),R/'adaptive_integrator.py',R/'numerical_refinement.py',D/'inputs_prepare.json',D/'semantic_dependencies.json',D/'rollout_inputs.npz',R/'external_validation_protocol.md',R/'external_validation_protocol_amendment.md',R/'external_validation_tie_rule.md',weight]+[Path(p) for p in dep['hashes']]
 hashes={str(p):sha(p) for p in paths};manifest=D/f'inputs_{a.model}_{a.seed}.json'
 if manifest.exists():assert json.loads(manifest.read_text())==hashes
 else:dump(manifest,hashes)
 record=D/f'completion_{a.model}_{a.seed}.json';execution=dict(status='running',model=a.model,seed=a.seed,algorithm_signature=ai.algorithm_signature(),cases=[]);dump(record,execution)
 for name,rtol,af in [('loose',1e-6,1e-8),('tight',1e-8,1e-10)]:
  path=D/f'{a.model}_{a.seed}_{name}.npz';statpath=D/f'{a.model}_{a.seed}_{name}_stats.json';print('EXTERNAL START',a.model,a.seed,name,flush=True)
  if path.exists():
   assert statpath.exists();v=np.load(path);assert v['prediction'].shape==(297,150,12) and np.array_equal(v['starts'],starts);stats=json.loads(statpath.read_text())
   nonfinite=[number for number in range(1,34) if not np.isfinite(v['prediction'][z['origin_record']==number]).all()]
   assert nonfinite==stats['failed_records'],'Cached nonfinite records disagree with failure log'
  else:
   started=time.time();failures=[]
   try:
    pred,stats=robot_rollout(rhs,d,cfg,starts,scale,rtol,af);stats['mode']='all_origins_batch';stats['failed_records']=[]
   except Exception as exc:
    batch_trace=traceback.format_exc();(D/f'batch_failure_{a.model}_{a.seed}_{name}.txt').write_text(batch_trace,encoding='utf-8');print('BATCH FAILED; ISOLATING EACH RECORD',repr(exc),flush=True)
    pred=np.full((297,150,12),np.nan);per_record=[]
    for number in range(1,34):
     mask=z['origin_record']==number
     try:
      part,stat=robot_rollout(rhs,d,cfg,starts[mask],scale,rtol,af,False);pred[mask]=part;per_record.append(dict(record=number,status='complete',**stat))
     except Exception as sub:
      failures.append(number);per_record.append(dict(record=number,status='failed',error=repr(sub),traceback=traceback.format_exc()))
     print('ISOLATED RECORD',number,per_record[-1]['status'],flush=True)
    stats=dict(mode='record_isolation_after_batch_failure',batch_error=repr(exc),per_record=per_record,failed_records=failures,seconds=time.time()-started)
   dump(statpath,stats);np.savez_compressed(path,prediction=pred,starts=starts,origin_record=z['origin_record'])
  execution['cases'].append(dict(tolerance=name,prediction_sha256=sha(path),stats_sha256=sha(statpath),failed_records=stats['failed_records']));dump(record,execution);print('EXTERNAL COMPLETE',a.model,a.seed,name,'failed_records',stats['failed_records'],flush=True)
 for p,h in hashes.items():assert sha(p)==h,p
 execution['status']='complete';execution['input_hashes_unchanged']=True;dump(record,execution)

if __name__=='__main__':
 try:main()
 except Exception:
  (R/'external_validation'/('execution_failure_'+'_'.join(__import__('sys').argv[1:]).replace('--','')+'.txt')).write_text(traceback.format_exc(),encoding='utf-8');raise
