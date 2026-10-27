"""Verified frozen graph, separate execution directory; unchanged DP kernel."""
from pathlib import Path
import argparse,json,hashlib,time,traceback,io
import adaptive_integrator as ai
from adaptive_integrator import np,torch,load,robot_rollout,dump,R,REV
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--seed',type=int,required=True);ap.add_argument('--model',choices=['history','history_removed'],required=True);a=ap.parse_args()
 D=R/'external_validation';O=R/'external_validation_compiled';O.mkdir(exist_ok=True)
 cfg,data,cache,params,s=load();torch.set_num_threads(1);assert cfg['horizon']==150 and cfg['dt']==.004 and cfg['history_lags']==[0,1,2,4,8,16,32]
 dep=json.loads((D/'semantic_dependencies.json').read_text());assert dep['status']=='pass'
 for p,h in dep['hashes'].items():assert sha(p)==h,p
 assert {k:v.numpy().tolist() for k,v in s.items()}==dep['scalers']
 check=R/'compiled_execution/verification.json';v=json.loads(check.read_text());assert v['status']=='pass' and v['algorithm_signature']==ai.algorithm_signature()
 for p,h in json.loads((R/'compiled_execution/verification_inputs.json').read_text()).items():assert sha(p)==h,p
 row=next(vv for vv in v['models'] if vv['model']==a.model and vv['seed']==a.seed);graph=Path(row['path']);assert sha(graph)==row['sha256']
 selected=json.loads((REV/'results/selected.json').read_text());source='history' if a.model=='history_removed' else a.model
 chosen=next(r for r in selected if r['model']==source and r['seed']==a.seed);weight=REV/chosen['path']/'best.pt'
 assert sha(weight)==row['weight_sha256'];prepared_inputs=json.loads((D/'inputs_prepare.json').read_text());assert prepared_inputs[str(weight)]==row['weight_sha256']
 rhs=torch.jit.load(io.BytesIO(graph.read_bytes())).eval();scale=torch.cat([s['qstd'],s['vstd']])
 prep=json.loads((D/'preparation_complete.json').read_text());assert prep['status']=='complete' and sha(D/'rollout_inputs.npz')==prep['rollout_inputs_sha256']
 for p,h in json.loads((D/'inputs_prepare.json').read_text()).items():assert sha(p)==h,p
 z=np.load(D/'rollout_inputs.npz');d={k:torch.tensor(z[k]) for k in ['q','v','a','u']};starts=z['starts'];assert len(starts)==297
 plan=R/'external_execution_modes.json';pv=json.loads(plan.read_text());assert pv['selection'][a.model]=='external_validation_compiled'
 paths=[Path(__file__),R/'adaptive_integrator.py',R/'numerical_refinement.py',D/'inputs_prepare.json',D/'semantic_dependencies.json',D/'rollout_inputs.npz',R/'external_validation_protocol.md',R/'external_validation_protocol_amendment.md',R/'external_validation_tie_rule.md',check,R/'compiled_execution/verification_inputs.json',graph,weight,plan]+[Path(p) for p in dep['hashes']]
 hashes={str(p):sha(p) for p in paths};manifest=O/f'inputs_{a.model}_{a.seed}.json'
 if manifest.exists():assert json.loads(manifest.read_text())==hashes
 else:dump(manifest,hashes)
 record=O/f'completion_{a.model}_{a.seed}.json';ex=dict(status='running',model=a.model,seed=a.seed,implementation='verified frozen TorchScript graph',algorithm_signature=ai.algorithm_signature(),cases=[]);dump(record,ex)
 for name,rtol,af in [('loose',1e-6,1e-8),('tight',1e-8,1e-10)]:
  path=O/f'{a.model}_{a.seed}_{name}.npz';sp=O/f'{a.model}_{a.seed}_{name}_stats.json';print('EXTERNAL COMPILED START',a.model,a.seed,name,flush=True)
  if path.exists():
   p=np.load(path);assert p['prediction'].shape==(297,150,12) and np.array_equal(p['starts'],starts);stats=json.loads(sp.read_text());assert [i for i in range(1,34) if not np.isfinite(p['prediction'][z['origin_record']==i]).all()]==stats['failed_records']
  else:
   started=time.time()
   try:pred,stats=robot_rollout(rhs,d,cfg,starts,scale,rtol,af);stats.update(mode='all_origins_batch',failed_records=[])
   except Exception as exc:
    (O/f'batch_failure_{a.model}_{a.seed}_{name}.txt').write_text(traceback.format_exc(),encoding='utf-8');pred=np.full((297,150,12),np.nan);failures=[];records=[]
    for i in range(1,34):
     mask=z['origin_record']==i
     try:part,stat=robot_rollout(rhs,d,cfg,starts[mask],scale,rtol,af,False);pred[mask]=part;records.append(dict(record=i,status='complete',**stat))
     except Exception as sub:failures.append(i);records.append(dict(record=i,status='failed',error=repr(sub),traceback=traceback.format_exc()))
     print('ISOLATED',i,records[-1]['status'],flush=True)
    stats=dict(mode='record_isolation_after_batch_failure',batch_error=repr(exc),per_record=records,failed_records=failures,seconds=time.time()-started)
   stats['implementation']='verified frozen TorchScript graph';dump(sp,stats);np.savez_compressed(path,prediction=pred,starts=starts,origin_record=z['origin_record'])
  ex['cases'].append(dict(tolerance=name,prediction_sha256=sha(path),stats_sha256=sha(sp),failed_records=stats['failed_records']));dump(record,ex);print('EXTERNAL COMPILED COMPLETE',a.model,a.seed,name,stats['failed_records'],flush=True)
 for p,h in hashes.items():assert sha(p)==h,p
 ex.update(status='complete',input_hashes_unchanged=True);dump(record,ex)
if __name__=='__main__':
 try:main()
 except Exception:
  out=R/'external_validation_compiled';out.mkdir(exist_ok=True);(out/('failure_'+'_'.join(__import__('sys').argv[1:]).replace('--','')+'.txt')).write_text(traceback.format_exc(),encoding='utf-8');raise
