from pathlib import Path
import sys,json,csv,shutil
R=Path(__file__).resolve().parent;B=R.parent;OLD=B/'jme_review_20260929';REV=B/'revision_v2_20260929';A=R/'adaptive';F=R/'delivery/figures';F.mkdir(exist_ok=True)
sys.path.insert(0,str(B/'plot_deps'))
import numpy as np,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
font_manager.fontManager.addfont('C:/Windows/Fonts/simsun.ttc')
plt.rcParams.update({'font.family':'SimSun','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'savefig.bbox':'tight','svg.fonttype':'none','axes.unicode_minus':False})
def read(p):
 with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def save(fig,name):
 fig.tight_layout()
 for ext in ['png','svg','pdf']:fig.savefig(F/f'{name}.{ext}',dpi=250)
 plt.close(fig)
for seed in [9,19,29]:assert json.loads((A/f'completion_seed{seed}.json').read_text())['status']=='complete'
for i in range(1,6):assert list(F.glob(f'fig{i}_*.png')),'Run render_first_five.py first'
rows=read(OLD/'experiments/integration_metrics.csv');adaptive=json.loads((A/'summary.json').read_text())
colors=['0.0','0.35','0.6'];fig,axs=plt.subplots(1,3,figsize=(9,3.3))
for ax,reg,title in zip(axs,['all','low_speed','reversal'],['完整轨迹','低速区间','换向区间']):
 for model,color,label,mark,line in zip(['capacity_control','history','history_removed'],colors,['D','H','H0'],['o','s','^'],['-','--','-.']):
  ys=[np.mean([float(r['nrmse']) for r in rows if r['model']==model and r['regime']==reg and int(r['substeps'])==ss]) for ss in [8,4,2,1]]
  ax.plot([.5,1,2,4],ys,marker=mark,ls=line,color=color,label=label,ms=4)
  value=next(r[model] for r in adaptive if r['regime']==reg and r['tolerance']=='tight')
  ax.axhline(value,color=color,ls=':',lw=1)
 ax.set_xscale('log',base=2);ax.set_xticks([.5,1,2,4],['0.5','1','2','4']);ax.set_xlabel('RK4 内部步长 / ms');ax.set_ylabel('位置 NRMSE');ax.set_title(title);ax.grid(alpha=.2)
axs[0].legend(fontsize=8);save(fig,'fig6_integration')
z=np.load(REV/'evaluations/history_9/predictions.npz');i=len(z['starts'])//2;reference=z['reference'][i,:,:6]
preds={'D':np.load(A/'capacity_control_9_tight.npz')['prediction'][i,:,:6],'H':np.load(A/'history_9_tight.npz')['prediction'][i,:,:6],'恒速':np.load(OLD/'experiments/constant_velocity.npz')['prediction'][i]}
fig,axs=plt.subplots(2,3,figsize=(9,4.8));tt=np.arange(1,151)*.004
for j,ax in enumerate(axs.flat):
 for label,color,line in zip(['D','H','恒速'],['0.0','0.35','0.6'],['-','--','-.']):ax.plot(tt,(preds[label][:,j]-reference[:,j])*180/np.pi,label=label,color=color,ls=line,lw=1.2)
 ax.set_xlabel('预测时长 / s');ax.set_ylabel('位置误差 / (°)');ax.set_title(f'关节{j+1}');ax.grid(alpha=.2)
axs[0,0].legend(fontsize=8);save(fig,'guide_middle_trace')
neutral=dict(trace_origin=int(z['starts'][i]),trace_time_s=float(z['starts'][i]*.004),seed=9,selection_rule='middle origin by index; not ranked by error',integration='Dormand-Prince5(4)',rtol=1e-8,atol_training_state_scale_factor=1e-10)
local=json.loads((A/'local_sensitivity_summary.json').read_text());assert len(local['figure_cases'])==2
from adaptive_integrator import load
_,_,_,_,scales=load();sq=scales['qstd'].numpy();fig,axs=plt.subplots(2,2,figsize=(8.4,4.8))
for row,case in enumerate(local['figure_cases']):
 seed=case['seed'];index=case['origin_index'];joint=case['joint']-1
 zz=np.load(REV/f'evaluations/history_{seed}/predictions.npz');lo=np.load(A/f'history_{seed}_loose.npz')['prediction'][index,:,:6];hi=np.load(A/f'history_{seed}_tight.npz')['prediction'][index,:,:6];ref=zz['reference'][index,:,:6]
 assert int(zz['starts'][index])==case['start_sample']
 for value,line,label in [(lo,'--','较松容限'),(hi,'-','较严容限')]:axs[row,0].plot(tt,(value[:,joint]-ref[:,joint])*180/np.pi,color='black',ls=line,label=label,lw=1.1)
 delta=np.max(abs((hi-lo)/sq),axis=1);axs[row,1].plot(tt,delta,color='black',lw=1.1);axs[row,1].axhline(1e-3,color='0.5',ls='--',lw=1,label='预定最大差阈值')
 axs[row,0].set_ylabel(f'关节{joint+1}位置误差 / (°)');axs[row,1].set_ylabel('最大标准化位置差')
 for ax in axs[row]:ax.set_xlabel('预测时长 / s');ax.set_title(f'初始化{seed}，起点{case["start_sample"]*.004:.3f} s');ax.grid(alpha=.2)
axs[0,0].legend(fontsize=8);axs[0,1].legend(fontsize=8);save(fig,'fig7_trace')
(F/'selection.json').write_text(json.dumps(dict(manuscript_figure3=local,figure3_file='fig7_trace.png',guide_middle_trace=neutral),ensure_ascii=False,indent=2),encoding='utf-8')
if '--original-only' in sys.argv:
 print('Original-test figures 6/7 and separate neutral-window guide figure rendered; confirmation figure not requested.');sys.exit(0)
ext=R/'external_validation';assert json.loads((ext/'analysis_complete.json').read_text())['status']=='complete'
erows=read(ext/'trajectory_metrics.csv');fig,axs=plt.subplots(1,2,figsize=(8.4,3.7))
for ax,model,label in zip(axs,['capacity_control','constant_velocity'],['D','恒速外推']):
 x=[];y=[]
 for rec in range(1,34):
  h=next(v['nrmse'] for v in erows if v['record']==str(rec) and v['model']=='history' and v['regime']=='all')
  d=next(v['nrmse'] for v in erows if v['record']==str(rec) and v['model']==model and v['regime']=='all')
  if h and d:x.append(float(d));y.append(float(h))
 ax.scatter(x,y,s=26,facecolors='none',edgecolors='black',linewidths=1.1)
 if x:
  lo=min(x+y)*.9;hi=max(x+y)*1.1;ax.plot([lo,hi],[lo,hi],'--',color='#777777',lw=1);ax.set_xlim(lo,hi);ax.set_ylim(lo,hi)
 ax.set_xlabel(label+'整体位置 NRMSE');ax.set_ylabel('H整体位置 NRMSE');ax.set_title(f'共同有效轨迹：{len(x)}');ax.set_aspect('equal',adjustable='box');ax.grid(alpha=.2)
save(fig,'fig8_confirmation')
print('Five inherited figures and three updated/generated figures ready.')
