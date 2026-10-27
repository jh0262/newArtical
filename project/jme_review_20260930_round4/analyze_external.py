"""Recompute every confirmation metric from preserved predictions; never trains."""
from pathlib import Path
import json,csv,hashlib
from adaptive_integrator import R,REV,load,np,torch,core,dump,write_csv
D=R/'external_validation';planpath=R/'external_execution_modes.json';execution_plan=json.loads(planpath.read_text())['selection']
assert execution_plan=={'capacity_control':'external_validation','history':'external_validation_compiled','history_removed':'external_validation_compiled'}
def read(p):
 with Path(p).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def describe(vals):
 vals=[v for v in vals if v is not None]
 return dict(n=len(vals),mean=float(np.mean(vals)) if vals else None,median=float(np.median(vals)) if vals else None,min=min(vals) if vals else None,max=max(vals) if vals else None)
def direction(a,b):
 delta=np.asarray(a)-np.asarray(b);return dict(lower=int((delta < -1e-12).sum()),equal=int((abs(delta)<=1e-12).sum()),higher=int((delta>1e-12).sum()))

cfg,data,cache,params,s=load();torch.set_num_threads(1);scale=s['qstd'].numpy();z=np.load(D/'rollout_inputs.npz');coverage=json.loads((D/'coverage.json').read_text());assert len(coverage)==33
point=read(D/'pointwise_metrics.csv');assert len(point)==462
for row in point:row['record']=int(row['record']);row['seed']=int(row['seed']);row['nmse']=float(row['nmse'])
point_summary=[];point_traj=[]
for model in ['training_mean','physics_no_friction','velocity','capacity_control','history','history_removed']:
 vals=[]
 for rec in range(1,34):
  rr=[v['nmse'] for v in point if v['model']==model and v['record']==rec];assert len(rr)==(1 if model in ['training_mean','physics_no_friction'] else 3)
  val=float(np.mean(rr));vals.append(val);point_traj.append(dict(record=rec,model=model,nmse=val))
 point_summary.append(dict(model=model,**describe(vals)))
rows=[];baseline=[];checks=[];failures=[];stats=[];refs=z['reference'][:,:,:6];regimes=['all','low_speed','reversal']
def masks(rec):
 ids=z['origin_record']==rec
 return ids,[None,z['low_speed_mask'][ids],z['reversal_mask'][ids]]
for model in ['capacity_control','history','history_removed']:
 for seed in [9,19,29]:
  source=R/execution_plan[model]
  completion=json.loads((source/f'completion_{model}_{seed}.json').read_text());assert completion['status']=='complete' and completion['input_hashes_unchanged']
  for p,h in json.loads((source/f'inputs_{model}_{seed}.json').read_text()).items():assert sha(p)==h,p
  predictions=[]
  for name in ['loose','tight']:
   path=source/f'{model}_{seed}_{name}.npz';c=next(x for x in completion['cases'] if x['tolerance']==name);assert sha(path)==c['prediction_sha256']
   sp=source/f'{model}_{seed}_{name}_stats.json';assert sha(sp)==c['stats_sha256'];ss=json.loads(sp.read_text());stats.append(dict(model=model,seed=seed,tolerance=name,seconds=ss['seconds'],mode=ss['mode'],implementation=completion.get('implementation','eager FrozenRHS'),source_directory=str(source),failed_records=ss['failed_records']))
   p=np.load(path);assert np.array_equal(p['starts'],z['starts']);pred=p['prediction'][:,:,:6];predictions.append(pred)
   for rec in range(1,34):
    ids,mm=masks(rec);finite=bool(np.isfinite(pred[ids]).all())
    if not finite:failures.append(dict(model=model,seed=seed,tolerance=name,record=rec))
    for reg,mask in zip(regimes,mm):
     met=core.metric(pred[ids],refs[ids],scale,mask) if finite else dict(nrmse=None,rmse_rad=None,pair_counts=[])
     rows.append(dict(record=rec,model=model,seed=seed,tolerance=name,regime=reg,nrmse=met['nrmse'],rmse_rad=met['rmse_rad'],finite=finite,pair_counts=json.dumps(met['pair_counts'])))
  for rec in range(1,34):
   ids,mm=masks(rec);finite=all(np.isfinite(p[ids]).all() for p in predictions);mx=float(np.max(abs((predictions[1][ids]-predictions[0][ids])/scale))) if finite else None;diffs={}
   for reg,mask in zip(regimes,mm):diffs[reg]=core.metric(predictions[1][ids],predictions[0][ids],scale,mask)['nrmse'] if finite else None
   valid=[v for v in diffs.values() if v is not None];passed=bool(finite and valid and max(valid)<=1e-4 and mx<=1e-3)
   checks.append(dict(record=rec,model=model,seed=seed,finite=bool(finite),max_normalized_position_difference=mx,**{'delta_'+k:v for k,v in diffs.items()},consistency_pass=passed))
q=z['q'][z['starts']];v=z['v'][z['starts']];times=np.arange(1,151)*.004
base={'constant_velocity':q[:,None,:]+times[None,:,None]*v[:,None,:],'position_hold':np.repeat(q[:,None,:],150,axis=1)}
for model,pred in base.items():
 for rec in range(1,34):
  ids,mm=masks(rec)
  for reg,mask in zip(regimes,mm):
   met=core.metric(pred[ids],refs[ids],scale,mask);baseline.append(dict(record=rec,model=model,regime=reg,nrmse=met['nrmse'],rmse_rad=met['rmse_rad'],pair_counts=json.dumps(met['pair_counts'])))
traj=[];summaries=[];comparisons=[]
allmodels=['capacity_control','history','history_removed','constant_velocity','position_hold']
for reg in regimes:
 vals={}
 for model in allmodels:
  vals[model]=[]
  for rec in range(1,34):
   rr=[v['nrmse'] for v in (baseline if model in base else rows) if v['record']==rec and v['model']==model and v['regime']==reg and (model in base or v['tolerance']=='tight')]
   assert len(rr)==(1 if model in base else 3);val=float(np.mean(rr)) if all(v is not None for v in rr) else None;vals[model].append(val);traj.append(dict(record=rec,file=coverage[rec-1]['file'],model=model,regime=reg,nrmse=val))
  ds=describe(vals[model]);summaries.append(dict(model=model,regime=reg,complete_all_33=ds['n']==33,**ds))
 for control in ['capacity_control','history_removed','constant_velocity']:
  valid=[i for i in range(33) if vals['history'][i] is not None and vals[control][i] is not None];h=[vals['history'][i] for i in valid];d=[vals[control][i] for i in valid];groups={}
  for i in valid:groups.setdefault(coverage[i]['file'],[]).append(i)
  fullgroups=[ix for ix in groups.values() if len(ix)==3];gh=[float(np.mean([vals['history'][i] for i in ix])) for ix in fullgroups];gd=[float(np.mean([vals[control][i] for i in ix])) for ix in fullgroups]
  comparisons.append(dict(regime=reg,control=control,common_records=len(valid),record_numbers=[i+1 for i in valid],all_33_complete=len(valid)==33,reduction_percent=100*(1-float(np.mean(h))/float(np.mean(d))) if d else None,trajectory_direction=direction(h,d),complete_file_groups=len(fullgroups),file_direction=direction(gh,gd)))
assert len(rows)==1782 and len(baseline)==198 and len(checks)==297
write_csv(D/'rollout_metrics.csv',rows);write_csv(D/'baseline_metrics.csv',baseline);write_csv(D/'tolerance_checks.csv',checks);write_csv(D/'trajectory_metrics.csv',traj);write_csv(D/'pointwise_trajectory_metrics.csv',point_traj)
dump(D/'summary.json',dict(pointwise_summary=point_summary,rollout_summary=summaries,comparisons=comparisons,failures=failures,tolerance_cases=len(checks),tolerance_passes=sum(r['consistency_pass'] for r in checks),max_tolerance_difference=max((r['max_normalized_position_difference'] for r in checks if r['max_normalized_position_difference'] is not None),default=None),checks_by_model=[dict(model=m,cases=99,passed=sum(c['consistency_pass'] for c in checks if c['model']==m)) for m in allmodels[:3]],execution_stats=stats))
dump(D/'analysis_complete.json',dict(status='complete',records=33,rollout_rows=len(rows),baseline_rows=len(baseline),pointwise_rows=len(point),tolerance_cases=len(checks),summary_sha256=sha(D/'summary.json'),analysis_script_sha256=sha(__file__),execution_mode_plan_sha256=sha(planpath),execution_sources=execution_plan))
print(json.dumps(dict(pointwise_summary=point_summary,rollout_summary=summaries,comparisons=comparisons,failures=failures,tolerance_passes=sum(r['consistency_pass'] for r in checks)),ensure_ascii=False))
