"""Replot retained evidence for legible monochrome printing; values unchanged."""
from pathlib import Path
import sys,csv,json
ROOT=Path(__file__).resolve().parent;B=ROOT.parent;REV=B/'revision_v2_20260929';EXP=B/'jme_review_20260929/experiments';FIG=ROOT/'delivery/figures';FIG.mkdir(exist_ok=True)
sys.path.insert(0,str(B/'plot_deps'))
import numpy as np,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
font_manager.fontManager.addfont('C:/Windows/Fonts/simsun.ttc')
plt.rcParams.update({'font.family':'SimSun','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'savefig.bbox':'tight','svg.fonttype':'none','axes.unicode_minus':False})
def read(path):
 with path.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def save(fig,name):
 fig.tight_layout()
 for ext in ['png','svg','pdf']:fig.savefig(FIG/f'{name}.{ext}',dpi=300)
 plt.close(fig)
models=['velocity','capacity_control','history','history_removed'];names=['V 瞬时','D 重参数化','H 历史','H0 移除历史']
colors=['0.0','0.25','0.45','0.65'];lines=['-','--','-.',':'];marks=['o','s','^','D'];regimes=['all','low_speed','reversal'];regnames=['完整轨迹','低速区间','换向区间']
geom=read(REV/'results/history_geometry.csv');sv=json.loads((REV/'results/singular_values.json').read_text())
fig,axs=plt.subplots(1,2,figsize=(9,3.2))
for j,(line,mark) in enumerate(zip(['-','--','-.',':','-','--'],['o','s','^','D','v','x']),1):
 ss=[v for v in sv if v['joint']==j];axs[0].plot([v['max_lag_ms'] for v in ss],[100*v['pc1_fraction'] for v in ss],color=str((j-1)*.1),ls=line,marker=mark,ms=3,label=f'关节{j}')
for i,split in enumerate(['train','validation','test']):
 yy=[100*float(next(v['linear_residual_energy_fraction'] for v in geom if v['split']==split and int(v['joint'])==j and int(v['max_lag_ms'])==128)) for j in range(1,7)]
 axs[1].plot(range(1,7),yy,color=colors[i],ls=lines[i],marker=marks[i],ms=4,label=['训练','验证','测试'][i])
axs[0].set_xlabel('最大历史跨度 / ms');axs[0].set_xticks([8,32,128]);axs[0].set_ylabel('第一主成分解释比 / %');axs[0].legend(ncol=2,fontsize=8)
axs[1].set_xlabel('关节');axs[1].set_ylabel('线性投影残差能量比 / %');axs[1].set_xticks(range(1,7));axs[1].legend(fontsize=8)
for ax in axs:ax.grid(alpha=.2)
save(fig,'fig1_geometry')
metrics=read(REV/'results/metrics.csv');baselines=read(EXP/'kinematic_baselines.csv')
def val(m,seed,reg):return float(next(v['nrmse'] for v in metrics if v['model']==m and int(v['seed'])==seed and v['regime']==reg))
fig,axs=plt.subplots(1,3,figsize=(9,3.1))
for ax,reg,title in zip(axs,regimes,regnames):
 for i,m in enumerate(models):
  v=[val(m,s,reg) for s in [9,19,29]];ax.errorbar(i,np.mean(v),yerr=np.std(v,ddof=1),fmt=marks[i],color=colors[i],ms=4,capsize=3);ax.scatter(i+np.array([-.13,0,.13]),v,s=12,color=colors[i],marker=marks[i])
 for m,line,label in [('constant_velocity','--','恒速外推'),('position_hold',':','位置保持')]:
  v=float(next(v['nrmse'] for v in baselines if v['model']==m and v['regime']==reg));ax.axhline(v,color='black',ls=line,lw=.9,label=label)
 ax.set_xticks(range(4),['V','D','H','H0']);ax.set_title(title);ax.set_ylabel('位置 NRMSE');ax.grid(axis='y',alpha=.2)
axs[0].legend(fontsize=8);save(fig,'fig2_metrics')
fig,ax=plt.subplots(figsize=(8.2,3.1))
for i,seed in enumerate([9,19,29]):ax.plot(range(3),[100*(val('history',seed,g)/val('history_removed',seed,g)-1) for g in regimes],ls=lines[i],marker=marks[i],color=colors[i],label=f'初始化 {seed}')
ax.axhline(0,color='0.5',lw=.9);ax.set_xticks(range(3),regnames);ax.set_ylabel('H相对H0的误差变化 / %');ax.grid(alpha=.2);ax.legend(ncol=3,fontsize=9);save(fig,'fig3_ablation')
for source,field,xs,title,ytitle,name in [('horizons.csv','horizon_s',[.1,.3,.6],'预测时长 / s','区间位置 NRMSE','fig4_horizon'),('threshold_sensitivity.csv','threshold_fraction',[.025,.05,.1],'训练速度绝对值95分位数的比例 / %','低速位置 NRMSE','fig5_threshold')]:
 rows=read(REV/'results'/source);fig,ax=plt.subplots(figsize=(8.2,3.1))
 for i,(m,label) in enumerate(zip(models,names)):
  yy=[np.mean([float(v['nrmse']) for v in rows if v['model']==m and abs(float(v[field])-x)<1e-8]) for x in xs]
  ax.plot(xs if field=='horizon_s' else [100*x for x in xs],yy,ls=lines[i],marker=marks[i],label=label,color=colors[i],ms=4)
 ax.set_xlabel(title);ax.set_ylabel(ytitle);ax.grid(alpha=.2);ax.legend(fontsize=9,ncol=2);save(fig,name)
print('Five monochrome figures reconstructed from retained results.')
