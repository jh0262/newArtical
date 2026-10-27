from pathlib import Path
import sys,csv,json
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent/'plot_deps'))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib import font_manager
font_manager.fontManager.addfont('C:/Windows/Fonts/msyh.ttc')
plt.rcParams.update({'font.family':'Microsoft YaHei','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'savefig.bbox':'tight','svg.fonttype':'none','axes.unicode_minus':False})
FIG=ROOT/'figures';FIG.mkdir(exist_ok=True)
R=ROOT/'results'
def rows(name):
 with (R/name).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def save(fig,name):
 fig.tight_layout()
 for ext in ['png','svg','pdf']:fig.savefig(FIG/(name+'.'+ext),dpi=220)
 plt.close(fig)
models=['velocity','capacity_control','history','history_removed'];names=['V 瞬时','D 重参数化','H 历史','H0 移除历史']
colors=['#6b7280','#c18b32','#167a72','#a95b75']
regimes=['all','low_speed','reversal'];regnames=['完整轨迹','低速区间','换向区间']
geom=rows('history_geometry.csv');sv=json.loads((R/'singular_values.json').read_text())
fig,ax=plt.subplots(1,2,figsize=(9,3.2))
for joint in range(1,7):
 ss=[r for r in sv if r['joint']==joint]
 ax[0].plot([r['max_lag_ms'] for r in ss],[100*r['pc1_fraction'] for r in ss],'-o',ms=3,label=f'关节{joint}')
for idx,split in enumerate(['train','validation','test']):
 yy=[float(next(r['linear_residual_energy_fraction'] for r in geom if r['split']==split and int(r['joint'])==j and int(r['max_lag_ms'])==128))*100 for j in range(1,7)]
 ax[1].plot(range(1,7),yy,'-o',ms=4,label=['训练','验证','测试'][idx])
ax[0].set_xlabel('最大历史跨度 / ms');ax[0].set_ylabel('第一主成分解释比 / %');ax[0].legend(ncol=2,fontsize=8)
ax[1].set_xlabel('关节');ax[1].set_ylabel('线性投影残差能量比 / %');ax[1].set_xticks(range(1,7));ax[1].legend(fontsize=8)
for a in ax:a.grid(alpha=.2)
save(fig,'fig1_geometry')

metrics=rows('metrics.csv')
def val(model,seed,reg):return float(next(r['nrmse'] for r in metrics if r['model']==model and int(r['seed'])==seed and r['regime']==reg))
fig,axs=plt.subplots(1,3,figsize=(10,3.35))
for ax,reg,title in zip(axs,regimes,regnames):
 for i,(m,n,c) in enumerate(zip(models,names,colors)):
  y=[val(m,seed,reg) for seed in [9,19,29]]
  ax.errorbar(i,np.mean(y),yerr=np.std(y,ddof=1),fmt='s',color=c,ms=6,capsize=4)
  ax.scatter(i+np.array([-.12,0,.12]),y,s=16,color=c,alpha=.8)
 ax.set_xticks(range(4),['V','D','H','H0']);ax.set_title(title);ax.set_ylabel('位置 NRMSE');ax.grid(axis='y',alpha=.2)
save(fig,'fig2_metrics')

fig,ax=plt.subplots(figsize=(8.2,3.1))
for seed,mark in zip([9,19,29],['o','s','^']):
 y=[100*(val('history',seed,g)/val('history_removed',seed,g)-1) for g in regimes]
 ax.plot(range(3),y,marker=mark,label=f'初始化 {seed}')
ax.axhline(0,color='#777',lw=.9);ax.set_xticks(range(3),regnames);ax.set_ylabel('H相对H0的误差变化 / %');ax.grid(alpha=.2);ax.legend(ncol=3,fontsize=9)
save(fig,'fig3_ablation')

h=rows('horizons.csv');fig,ax=plt.subplots(figsize=(8.2,3.1))
for m,n,c in zip(models,names,colors):
 yy=[np.mean([float(r['nrmse']) for r in h if r['model']==m and abs(float(r['horizon_s'])-t)<1e-8]) for t in [.1,.3,.6]]
 ax.plot([.1,.3,.6],yy,'-o',label=n,color=c,ms=4)
ax.set_xlabel('预测时长 / s');ax.set_ylabel('区间位置 NRMSE');ax.grid(alpha=.2);ax.legend(fontsize=9,ncol=2)
save(fig,'fig4_horizon')

t=rows('threshold_sensitivity.csv');fig,ax=plt.subplots(figsize=(8.2,3.1))
for m,n,c in zip(models,names,colors):
 yy=[np.mean([float(r['nrmse']) for r in t if r['model']==m and abs(float(r['threshold_fraction'])-f)<1e-8]) for f in [.025,.05,.1]]
 ax.plot([2.5,5,10],yy,'-o',label=n,color=c,ms=4)
ax.set_xlabel('训练速度绝对值95分位数的比例 / %');ax.set_ylabel('低速位置 NRMSE');ax.grid(alpha=.2);ax.legend(fontsize=9,ncol=2)
save(fig,'fig5_threshold')
print('5 scientific figures in PNG SVG PDF')
