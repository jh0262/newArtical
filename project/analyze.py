import bootstrap
import csv,json,hashlib,platform
from pathlib import Path
from datetime import datetime
import numpy as np,torch
import core
from run_model import regime_masks
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results';OUT.mkdir(exist_ok=True)
cfg=json.loads((ROOT/'config.json').read_text())
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def csvwrite(name,rows):
    if not rows:return
    with (OUT/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
z=np.load(ROOT/'preflight/prepared.npz')
scale=core.fit_scales(z['train_q'])[1]
threshold=cfg['low_speed_fraction_of_train_p95']*np.quantile(np.abs(z['train_v']),.95,axis=0)
rows=[];jointrows=[];recoveries=[];checks=[];runs=[]
for dest in sorted((ROOT/'runs').iterdir()):
    if not (dest/'manifest.json').exists():continue
    m=json.loads((dest/'manifest.json').read_text())
    if m['status']=='running':raise RuntimeError('Run still active: '+dest.name)
    if not (dest/'predictions.npz').exists():
        checks.append({'run':dest.name,'finite_predictions':False,'reason':'No prediction artifact'});continue
    p=np.load(dest/'predictions.npz'); pred=p['prediction'][:,:,:6];ref=p['reference'][:,:,:6]
    masks={'all':np.ones_like(pred,dtype=bool),'low_speed':p['low_speed_mask'],'reversal':p['reversal_mask']}
    result={key:core.metric(pred,ref,scale,mask) for key,mask in masks.items()}
    result['legacy_endpoint_nmse_evaluation_scale']=float((((pred[:,-1]-ref[:,-1])/z['test_q'].std(0,ddof=1))**2).mean())
    low,rev,events=regime_masks(z['test_v'],threshold,cfg)
    result['coverage']={'origins':len(p['starts']),'low_speed_threshold_rad_s':threshold.tolist(),'events':events,'low_timestamp_counts':low.sum(0).tolist(),'reversal_timestamp_counts':rev.sum(0).tolist()}
    if (dest/'metrics.json').exists():
        old=json.loads((dest/'metrics.json').read_text())
        for key in masks:
            if not np.isclose(result[key]['nrmse'],old[key]['nrmse'],rtol=1e-12,atol=1e-12):raise RuntimeError('Metric recomputation mismatch')
    elif (dest/'failure.txt').exists() and 'int64 is not JSON serializable' in (dest/'failure.txt').read_text():
        (dest/'recovered_metrics.json').write_text(json.dumps(result,indent=2,allow_nan=False))
        recovery={'recovered_at':datetime.now().astimezone().isoformat(),'original_status':m['status'],'type':'export_serialization_only','source_prediction_sha256':sha(dest/'predictions.npz'),'analysis_sha256':sha(__file__),'retrained':False,'resimulated':False}
        (dest/'recovery.json').write_text(json.dumps(recovery,indent=2));recoveries.append(dest.name)
    else:raise RuntimeError('Unclassified prediction/metric state in '+dest.name)
    checks.append({'run':dest.name,'finite_predictions':bool(np.isfinite(pred).all()),'metric_recomputed':True,'starts_match':np.array_equal(p['starts'],np.arange(32,14850,25))})
    for key,r in result.items():
        if key not in masks:continue
        rows.append({'run':dest.name,'model':m['model'],'seed':m['seed'],'attempt':m['attempt'],'regime':key,'nrmse':r['nrmse'],'rmse_rad':r['rmse_rad'],'endpoint_nrmse':r['endpoint_nrmse'],'pair_count':sum(r['pair_counts']),'original_status':m['status'],'export_recovered':dest.name in recoveries})
        for j in range(6):
            jointrows.append({'run':dest.name,'model':m['model'],'seed':m['seed'],'attempt':m['attempt'],'regime':key,'joint':j+1,'nrmse':r['joint_nrmse'][j],'rmse_rad':r['joint_rmse_rad'][j],'pair_count':r['pair_counts'][j]})
    runs.append({'run':dest.name,'model':m['model'],'seed':m['seed'],'attempt':m['attempt'],'parameters':m.get('parameter_count',0),'termination':m.get('termination','fixed_shared_physics'),'best_step':m.get('best_step',''),'updates':m.get('updates',''),'best_validation_acc_nmse':m.get('best_validation_acc_nmse',''),'training_seconds':m.get('training_seconds',0),'elapsed_seconds':m['elapsed_seconds'],'export_recovered':dest.name in recoveries})
csvwrite('run_metrics.csv',rows);csvwrite('joint_metrics.csv',jointrows);csvwrite('training_runs.csv',runs)
summary=[]
for model in ['physics']+cfg['models']:
    for regime in ['all','low_speed','reversal']:
        rr=[r for r in rows if r['model']==model and r['regime']==regime and r['attempt']=='a']
        if not rr:continue
        vals=np.array([r['nrmse'] for r in rr],float)
        summary.append({'model':model,'regime':regime,'n_runs':len(rr),'nrmse_mean':float(vals.mean()),'nrmse_sd':float(vals.std(ddof=1)) if len(vals)>1 else 0.,'rmse_rad_mean':float(np.mean([r['rmse_rad'] for r in rr])),'endpoint_nrmse_mean':float(np.mean([r['endpoint_nrmse'] for r in rr]))})
csvwrite('summary.csv',summary)
comparisons=[]
for seed in cfg['seeds']:
    for regime in ['all','low_speed','reversal']:
        def get(model):return next(r['nrmse'] for r in rows if r['model']==model and r['seed']==seed and r['attempt']=='a' and r['regime']==regime)
        a,b,c=get('velocity'),get('capacity_control'),get('history')
        comparisons.append({'seed':seed,'regime':regime,'history_over_velocity':c/a,'history_change_vs_velocity_percent':100*(c/a-1),'history_over_capacity':c/b,'history_change_vs_capacity_percent':100*(c/b-1),'overall_guardrail_pass':c/a<=cfg['overall_relative_guardrail'] if regime=='all' else ''})
csvwrite('paired_comparisons.csv',comparisons)
coverage=[];datarecords=[]
for split in ['train','validation','test']:
    low,rev,events=regime_masks(z[split+'_v'],threshold,cfg)
    for j in range(6):coverage.append({'split':split,'joint':j+1,'samples':15000,'low_threshold_rad_s':float(threshold[j]),'low_speed_samples':int(low[:,j].sum()),'reversal_samples':int(rev[:,j].sum()),'reversal_events':sum(e['joint']==j+1 for e in events)})
    for k,unit,source in [('q','rad','encoder angle; original degrees converted'),('v','rad/s','filtered position frequency derivative'),('a','rad/s^2','filtered position second derivative'),('u','N*m','motor torque; filtered')]:
        for j in range(6):datarecords.append({'split':split,'variable':f'{k}{j+1}','unit':unit,'source':source,'mean':float(z[split+'_'+k][:,j].mean()),'std':float(z[split+'_'+k][:,j].std()),'minimum':float(z[split+'_'+k][:,j].min()),'maximum':float(z[split+'_'+k][:,j].max())})
csvwrite('coverage.csv',coverage);csvwrite('variable_dictionary.csv',datarecords)
repro={}
for suffix in ['a','repeat']:
    f=ROOT/'runs'/f'velocity_seed9_{suffix}'/'predictions.npz'; pp=np.load(f)
    repro[suffix]=hashlib.sha256(pp['prediction'].tobytes()).hexdigest()
repro['bitwise_equal']=repro['a']==repro['repeat']
repro['scope']='same machine, environment, config and seed; first export recovered; serialization-only code correction does not alter prediction computation'
split_info={'assignments':{'train':'realization 1 period 1','validation':'realization 2 period 1','test':'realization 3 period 1'},'array_hashes':{s:hashlib.sha256(z[s+'_q_raw'].tobytes()+z[s+'_u_raw'].tobytes()).hexdigest() for s in ['train','validation','test']},'preprocessing_fit':'scales and velocity threshold use train only; each trajectory separately FFT filtered offline','limitations':'Distinct assignments and hashes do not prove statistical independence; only one held-out realization; overlapping windows.'}
(OUT/'split_lineage.json').write_text(json.dumps(split_info,indent=2))
audit={'completed_at':datetime.now().astimezone().isoformat(),'expected_rows':14,'prediction_rows':len(checks),'runs':checks,'recovered_exports':recoveries,'same_seed_reproduction':repro,'config_sha256':sha(ROOT/'config.json'),'raw_sha256':sha(core.SOURCE/'common_data__py_recording_2021_12_15_20H_45M.mat'),'all_prediction_rows_present':len(checks)==14,'all_finite':all(c['finite_predictions'] for c in checks),'metric_recomputation':'all available prediction bundles recalculated without training','physical_validation':False,'strict_paper_reproduction':False,'statistical_independence_or_superiority_proven':False}
(OUT/'audit.json').write_text(json.dumps(audit,indent=2))
(OUT/'plot_data.json').write_text(json.dumps({'summary':summary,'comparisons':comparisons,'coverage':coverage,'runs':runs},indent=2))
print(json.dumps({'summary':summary,'comparisons':comparisons,'audit':audit},indent=2))
