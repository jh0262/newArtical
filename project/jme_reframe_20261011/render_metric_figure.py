from pathlib import Path
import sys,csv
R=Path(__file__).resolve().parent;B=R.parent
sys.path.insert(0,str(B/'plot_deps'))
import numpy as np,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'svg.fonttype':'none'})
fig,ax=plt.subplots(1,2,figsize=(10.8,3.65),layout='constrained')
colors={1:'#555555',3:'#287e8e',7:'#bd513d'}
for K in [1,3,7]:
    rows=[]
    for p in sorted((R/'metric_experiment').glob(f'k{K}_*/per_step.csv')):
        rows.extend(csv.DictReader(p.open(encoding='utf-8-sig')))
    rho=np.array([float(r['input_fraction']) for r in rows]);rat=np.array([float(r['matched_norm'])/float(r['ordinary_norm']) for r in rows])
    ax[0].scatter(rho,rat,s=5,color=colors[K],alpha=.22,rasterized=True)
    x=np.linspace(0,1,401);ax[0].plot(x,np.sqrt(1+(K-1)*x),color=colors[K],label=f'K = {K}',lw=1.4)
ax[0].set(xlabel=r'Input-block energy fraction $\rho$',ylabel=r'Gradient-norm ratio $G/G_0$',xlim=(-.015,1.015),ylim=(.9,2.8));ax[0].legend(frameon=False);ax[0].grid(alpha=.15)
ks=np.array([1,3,7]);xx=np.arange(3);wide=62412+606*(ks-1);compact=np.full(3,62412)
ax[1].bar(xx-.18,wide/1000,width=.36,color='#287e8e',label='Repeated input')
ax[1].bar(xx+.18,compact/1000,width=.36,color='#b6c5d0',label='Folded input')
for i,k in enumerate(ks):ax[1].text(i,wide[i]/1000+1,f'{(wide[i]-compact[i])/wide[i]*100:.2f}% fewer',ha='center',fontsize=9)
ax[1].set(xticks=xx,xticklabels=[str(k) for k in ks],xlabel='Replication factor K',ylabel='Parameter count (thousands)',ylim=(0,83));ax[1].legend(loc='upper left',frameon=False,ncol=2,fontsize=9)
out=R/'delivery/figures';out.mkdir(exist_ok=True,parents=True)
for ext in ['png','svg','pdf']:fig.savefig(out/f'fig_metric.{ext}',dpi=240)
plt.close(fig)
