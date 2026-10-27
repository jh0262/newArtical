from pathlib import Path
import json,csv
from train_controlled import R,B,load,dump,write_csv,sha
import torch,numpy as np,core
def avg(v):return float(np.mean(v))
def main():
 from check_active_evaluation import main as guard
 guard('before_summary')
 cfg,data,cache,params,s=load();torch.set_num_threads(1);out=R/'analysis';out.mkdir(exist_ok=True);summary={};tr=[];pair=[]
 for seed in [9,19,29]:
  p=R/'training'/f'seed{seed}';done=json.loads((p/'completion.json').read_text());assert done['status']=='complete'
  metrics=json.loads((p/'metrics.json').read_text());tr.extend(metrics);checks=list(csv.DictReader((p/'checkpoints.csv').open(encoding='utf-8-sig')));failed=[int(c['step']) for c in checks if c['equivalence_pass']=='False'];sel=done['selection']['Ds']['step'];cc=next(c for c in checks if int(c['step'])==sel)
  pair.append(dict(seed=seed,updates=done['steps'],failed_checkpoints=failed,first_failure=done['first_equivalence_failure'],selected_step=sel,selected_check_pass=cc['equivalence_pass']=='True',max_scaled_acc_difference=max(float(c[k]) for c in checks for k in ['train_max_acc_diff','validation_max_acc_diff']),selected_max_scaled_acc_difference=max(float(cc[k]) for k in ['train_max_acc_diff','validation_max_acc_diff']),max_parameter_difference=max(float(c['effective_parameter_difference']) for c in checks),clip_counts=done['clip_counts']))
 summary['training_equivalence']=pair;summary['training_models']=tr;dump(out/'training_summary.json',summary)
 point=R/'pointwise';roll=R/'rollout'
 if (point/'completion.json').exists():
  ms=json.loads((point/'metrics.json').read_text());pr=json.loads((point/'permutation_metrics.json').read_text());cov=json.loads((point/'coverage.json').read_text());pt=[]
  for which in ['best','final']:
   for group in ['train','validation','test','peer']:
    for model in ['training_mean','Ds','Vm','Cdelta','Hdelta']:
     rs=[r for r in ms if r['model']==model and (r['checkpoint']==which or model=='training_mean') and (r['record'].startswith('peer') if group=='peer' else r['record']==group)]
     pt.append(dict(group=group,model=model,checkpoint=which,nmse=avg([r['nmse'] for r in rs]),joint_nmse=np.mean([r['joint_nmse'] for r in rs],0).tolist(),joint_rmse_rad_s2=np.sqrt(np.mean(np.square([r['rmse_rad_s2'] for r in rs]),0)).tolist()))
  per_record=[]
  for record in [f'peer_{i:02d}' for i in range(1,34)]+['test']:
   get=lambda model:avg([r['nmse'] for r in ms if r['record']==record and r['model']==model and r['checkpoint']=='best'])
   pp=[r for r in pr if r['record']==record];co=[r for r in cov if r['record']==record]
   per_record.append(dict(record=record,C_nmse=get('Cdelta'),H_nmse=get('Hdelta'),true_common_nmse=avg([r['true_nmse'] for r in pp]),resampled_common_nmse=avg([r['permuted_nmse'] for r in pp]),coverage=avg([r['coverage'] for r in co])))
  summary['pointwise']=pt;summary['pointwise_per_record']=per_record;summary['resampling_coverage']=cov;summary['resampling_metrics']=pr
  write_csv(out/'pointwise_per_record.csv',per_record)
 else:summary['pointwise_status']='pending'
 if all((roll/f'{m}_{seed}/completion.json').exists() for m in ['Cdelta','Hdelta'] for seed in [9,19,29]):
  z=np.load(roll/'prepared.npz');sq=s['qstd'].numpy();steps=np.arange(1,151)*.004;idx=z['starts'];q=z['q'][idx];v=z['v'][idx];a=z['a'][idx];ref=z['reference'][:,:,:6];metrics=[];numerical=[]
  nets={}
  for m in ['Cdelta','Hdelta']:
   for seed in [9,19,29]:
    p=roll/f'{m}_{seed}';done=json.loads((p/'completion.json').read_text());numerical.append(done);nets[(m,seed)]=np.load(p/'tight.npz')['prediction'][:,:,:6]
  nets[('position_hold',0)]=np.broadcast_to(q[:,None,:],ref.shape);nets[('constant_velocity',0)]=q[:,None,:]+steps[None,:,None]*v[:,None,:];nets[('constant_acceleration',0)]=q[:,None,:]+steps[None,:,None]*v[:,None,:]+.5*steps[None,:,None]**2*a[:,None,:]
  for (model,seed),pred in nets.items():
   for rec in range(34):
    ix=np.where(z['origin_record']==rec)[0]
    for regime in ['all','low_speed','reversal']:
     mask=None if regime=='all' else z[regime+'_mask'][ix];met=core.metric(pred[ix],ref[ix],sq,mask)
     metrics.append(dict(record=rec,model=model,seed=seed,regime=regime,**met))
  agg=[];per_record=[]
  for regime in ['all','low_speed','reversal']:
   for model in ['Cdelta','Hdelta','position_hold','constant_velocity','constant_acceleration']:
    values=[]
    for rec in range(34):
     rs=[r for r in metrics if r['record']==rec and r['model']==model and r['regime']==regime and r['nrmse'] is not None];value=avg([r['nrmse'] for r in rs]) if rs else None
     per_record.append(dict(record=rec,model=model,regime=regime,nrmse=value))
     if rec==0:agg.append(dict(group='test',model=model,regime=regime,nrmse=value))
     elif value is not None:values.append(value)
    agg.append(dict(group='peer',model=model,regime=regime,nrmse=avg(values),median=float(np.median(values)),records=len(values)))
  summary['rollout']=agg;summary['rollout_per_record']=per_record;summary['numerical_checks']=[{k:v for k,v in c.items() if k not in ['outputs']} for c in numerical];dump(out/'rollout_metrics.json',metrics);write_csv(out/'rollout_per_record.csv',per_record)
  seed_effects=[]
  for seed in [9,19,29]:
   row={'seed':seed}
   for model in ['Cdelta','Hdelta']:
    row[model+'_pointwise']=avg([v['nmse'] for v in ms if v['model']==model and v['seed']==seed and v['checkpoint']=='best' and v['record'].startswith('peer')])
    row[model+'_rollout']=avg([v['nrmse'] for v in metrics if v['model']==model and v['seed']==seed and v['regime']=='all' and v['record']>0])
   for task in ['pointwise','rollout']:row[task+'_change_percent']=100*(row['Hdelta_'+task]/row['Cdelta_'+task]-1)
   seed_effects.append(row)
  summary['seed_effects']=seed_effects;write_csv(out/'seed_effects.csv',seed_effects)
 else:summary['rollout_status']='pending'
 summary['script_sha256']=sha(__file__);dump(out/'summary.json',summary)
 print(json.dumps({k:v for k,v in summary.items() if k in ['training_equivalence','pointwise','rollout','pointwise_status','rollout_status']},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
