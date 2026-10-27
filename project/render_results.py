import sys,os,json,csv
from pathlib import Path
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,os.environ.get('STEP4_PLOT_DEPS',str(ROOT/'plot_deps')))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'savefig.bbox':'tight','svg.fonttype':'none'})
OUT=ROOT/'results'; FIG=OUT/'figures';FIG.mkdir(exist_ok=True)
info=json.loads((OUT/'plot_data.json').read_text()); cfg=json.loads((ROOT/'config.json').read_text())
labels={'physics':'Physics','velocity':'Velocity','capacity_control':'Capacity control','history':'Velocity history','ann_only':'ANN only'}
colors={'physics':'#8b9299','velocity':'#3d6ca8','capacity_control':'#bc8d31','history':'#188a72','ann_only':'#8b5aa5'}
models=list(labels)
def save(fig,name):
    for ext in ['png','svg','pdf']:fig.savefig(FIG/(name+'.'+ext),dpi=190)
    plt.close(fig)
def rows(path):
    with path.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))

fig,axes=plt.subplots(1,3,figsize=(13,4.2))
for ax,regime,title in zip(axes,['all','low_speed','reversal'],['Complete trajectory','Low speed','Direction reversal']):
    ss=[next(s for s in info['summary'] if s['model']==m and s['regime']==regime) for m in models]
    ax.bar(np.arange(5),[s['nrmse_mean'] for s in ss],yerr=[s['nrmse_sd'] for s in ss],capsize=3,color=[colors[m] for m in models])
    ax.set_xticks(range(5),[labels[m] for m in models],rotation=35,ha='right');ax.set_title(title);ax.set_ylabel('Window position NRMSE (lower is better)');ax.grid(axis='y',alpha=.2)
fig.suptitle('Controlled rerun: mean and SD across 3 initialization seeds',y=1.02)
fig.text(.5,-.12,'Physics: one shared fit. Seed variation is not independent-trajectory uncertainty.',ha='center',fontsize=9)
fig.tight_layout();save(fig,'01_overall_and_regimes')

joint=rows(OUT/'joint_metrics.csv')
fig,axes=plt.subplots(1,3,figsize=(12.5,3.8))
for ax,reg in zip(axes,['all','low_speed','reversal']):
    ratios=[]
    for j in range(1,7):
        rr=[]
        for seed in cfg['seeds']:
            def val(m):return float(next(r['nrmse'] for r in joint if r['model']==m and int(r['seed'])==seed and r['attempt']=='a' and r['regime']==reg and int(r['joint'])==j))
            rr.append(100*(val('history')/val('velocity')-1))
        ratios.append(rr)
    a=np.array(ratios);ax.bar(range(1,7),a.mean(1),yerr=a.std(1,ddof=1),color=colors['history'],capsize=3)
    ax.axhline(0,color='black',lw=.8);ax.set_xticks(range(1,7));ax.set_xlabel('Joint');ax.set_ylabel('History vs velocity change (%)');ax.set_title(reg.replace('_',' '));ax.grid(axis='y',alpha=.2)
fig.suptitle('Paired-seed relative changes: negative is better');fig.tight_layout();save(fig,'02_joint_changes')

fig,ax=plt.subplots(figsize=(9,4.3))
for model in cfg['models']:
    for ix,seed in enumerate(cfg['seeds']):
        log=json.loads((ROOT/'runs'/f'{model}_seed{seed}_a'/'training_log.json').read_text())
        ax.plot([r['step'] for r in log],[r['validation_acc_nmse'] for r in log],color=colors[model],alpha=.8 if ix==0 else .35,lw=1.5,label=labels[model] if ix==0 else None)
ax.set_yscale('log');ax.set_xlabel('Gradient updates');ax.set_ylabel('Validation acceleration NMSE');ax.legend();ax.grid(alpha=.2);ax.set_title('Training objective is distinct from trajectory prediction error');save(fig,'03_validation_curves')

prep=np.load(ROOT/'preflight/prepared.npz');testv=prep['test_v'];threshold=.05*np.quantile(np.abs(prep['train_v']),.95,axis=0)
# Illustrative, deterministically choose the first sign reversal after 5 s in joint 1.
cross=np.flatnonzero((testv[1:,0]*testv[:-1,0]<0)&(np.arange(1,15000)>1250))+1
center=int(cross[0]) if len(cross) else 7500
base=np.load(ROOT/'runs/velocity_seed9_a/predictions.npz'); origins=base['starts'];k=int(np.argmin(np.abs(origins-(center-75))))
t=(np.arange(1,151)+origins[k])*.004
fig,axes=plt.subplots(2,1,figsize=(9,6),sharex=True)
for ax,col,unit in [(axes[0],0,'Joint 1 position (rad)'),(axes[1],6,'Joint 1 velocity (rad/s)')]:
    ax.plot(t,base['reference'][k,:,col],color='black',lw=2,label='Filtered reference')
    for model in ['velocity','capacity_control','history','ann_only']:
        p=np.load(ROOT/'runs'/f'{model}_seed9_a'/'predictions.npz');ax.plot(t,p['prediction'][k,:,col],color=colors[model],lw=1.3,label=labels[model])
    ax.axvline(center*.004,color='grey',ls=':',lw=1);ax.set_ylabel(unit);ax.grid(alpha=.2)
axes[0].legend(ncol=3,fontsize=8);axes[0].set_title('Illustrative reversal window, seed 9; not selected by prediction error');axes[1].set_xlabel('Record time (s)');fig.tight_layout();save(fig,'04_example_reversal')

fig,axes=plt.subplots(1,2,figsize=(10,3.8)); x=np.arange(6)
for i,split in enumerate(['train','validation','test']):
    cv=[c for c in info['coverage'] if c['split']==split]
    axes[0].bar(x+(i-1)*.25,[100*c['low_speed_samples']/c['samples'] for c in cv],width=.25,label=split)
    axes[1].bar(x+(i-1)*.25,[c['reversal_events'] for c in cv],width=.25,label=split)
for ax in axes:ax.set_xticks(x,np.arange(1,7));ax.set_xlabel('Joint');ax.grid(axis='y',alpha=.2)
axes[0].set_ylabel('Low-speed timestamps (%)');axes[1].set_ylabel('Reversal events');axes[0].legend();fig.suptitle('Regime coverage; thresholds derived from training data only');fig.tight_layout();save(fig,'05_coverage')

scale=prep['train_q'].std(0);fig,ax=plt.subplots(figsize=(9,4.3))
for model in models:
    curves=[]
    for seed in ([9] if model=='physics' else cfg['seeds']):
        p=np.load(ROOT/'runs'/f'{model}_seed{seed}_a'/'predictions.npz')
        e=(p['prediction'][:,:,:6]-p['reference'][:,:,:6])/scale
        curves.append(np.sqrt((e**2).mean(axis=(0,2))))
    a=np.array(curves);mean=a.mean(0);sd=a.std(0)
    ax.plot(np.arange(1,151)*.004,mean,label=labels[model],color=colors[model]);ax.fill_between(np.arange(1,151)*.004,np.maximum(0,mean-sd),mean+sd,alpha=.12,color=colors[model])
ax.set_xlabel('Prediction horizon (s)');ax.set_ylabel('Position NRMSE at each horizon');ax.legend();ax.grid(alpha=.2);ax.set_title('Accumulation of open-loop prediction error');save(fig,'06_horizon_errors')
(OUT/'render_manifest.json').write_text(json.dumps({'matplotlib':matplotlib.__version__,'numpy_for_rendering':np.__version__,'figures':[p.name for p in FIG.glob('*.png')],'example_policy':'first joint-1 reference sign reversal after 5 seconds; seed 9'},indent=2))
print('Rendered',len(list(FIG.glob('*.png'))),'figures in PNG/SVG/PDF')
