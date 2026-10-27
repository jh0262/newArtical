from pathlib import Path
import json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm
R=Path(__file__).resolve().parents[1];D=R/'data';O=R/'figures'
COLORS=['#0072B2','#D55E00','#009E73','#CC79A7','#E69F00','#56B4E9','#555555']
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.top':False,'axes.spines.right':False,'axes.grid':True,'grid.alpha':.18,'pdf.fonttype':42,'savefig.dpi':180})
def save(fig,name):
    fig.savefig(O/(name+'.png'),bbox_inches='tight',facecolor='white');fig.savefig(O/(name+'.pdf'),bbox_inches='tight',facecolor='white',metadata={'CreationDate':None});plt.close(fig)
def main():
    screen=pd.read_csv(D/'screen_runs.csv');confirm=pd.read_csv(D/'confirm_runs.csv');curve=pd.read_csv(D/'confirm_curves.csv');profiles=pd.read_csv(D/'screen_profiles.csv');stats=pd.read_csv(D/'confirm_statistics.csv');stab=pd.read_csv(D/'confirm_stability.csv')
    sel=json.loads((D/'selection.json').read_text(encoding='utf-8'));cand=sel['candidates'];cand=[cand] if isinstance(cand,str) else cand;ids=['B']+cand
    s=screen[screen.Problem=='PPAR'];b=s[s.Variant=='B'];grid=np.array([['N11','N12','N13'],['N21','B','N23'],['N31','N32','N33']])
    fig,axs=plt.subplots(1,3,figsize=(11.5,3.5),layout='constrained')
    for ax,metric,label in zip(axs,['MillionHV','AUC','MillionHV'],['Mean final HV','Mean HV AUC','10th percentile final HV']):
        agg=(lambda x:np.quantile(x,.1,method='hazen')) if label.startswith('10') else np.mean
        ref=agg(b[metric]);vals=np.array([[100*(agg(s[s.Variant==id][metric])/ref-1) for id in row] for row in grid]);limit=max(abs(vals).max(),1e-8)
        im=ax.imshow(vals,cmap='RdBu',norm=TwoSlopeNorm(vmin=-limit,vcenter=0,vmax=limit));ax.grid(False)
        for i in range(3):
            for j in range(3):ax.text(j,i,f'{vals[i,j]:+.3f}%',ha='center',va='center',color='white' if abs(vals[i,j])>.65*limit else 'black')
        ax.set_xticks(range(3),['0.005','0.020','0.050']);ax.set_yticks(range(3),['0.025','0.050','0.100']);ax.set_xlabel('Step-size floor');ax.set_ylabel('Noise gain');ax.set_title(label);fig.colorbar(im,ax=ax,shrink=.8,label='Change from B (%)')
    fig.suptitle('2PPaPaR parameter screening: 16 independent seeds per setting');save(fig,'01_engineering_noise_grid')
    gates=['B','W2','W10','C005','W2C005'];fig,axs=plt.subplots(1,3,figsize=(11,3.4),layout='constrained')
    for ax,met,label in zip(axs,['MillionHV','AUC','Pulses'],['Final HV (million-point evaluation)','Search HV AUC','Pulse events per run']):
        values=[s[s.Variant==id][met].values for id in gates];means=np.array([x.mean() for x in values]);se=np.array([x.std(ddof=1)/np.sqrt(len(x)) for x in values]);ax.errorbar(range(5),means,yerr=1.96*se,fmt='o',capsize=4,color=COLORS[0]);ax.set_xticks(range(5),gates,rotation=25);ax.set_ylabel(label)
    fig.suptitle('2PPaPaR pulse settings: mean and approximate 95% mean interval');save(fig,'02_engineering_gate_effects')
    fig,axs=plt.subplots(1,2,figsize=(10.5,3.8),layout='constrained');target=json.loads((D/'targets.json').read_text())['engineering_HV_target']
    for i,id in enumerate(ids):
        a=curve[(curve.Problem=='PPAR')&(curve.Variant==id)];arr=a.pivot(index='Seed',columns='FE',values='HV');xx=arr.columns.to_numpy();yy=arr.mean().values;sem=arr.std().values/np.sqrt(len(arr));axs[0].plot(xx,yy,label=id,color=COLORS[i]);axs[0].fill_between(xx,yy-1.96*sem,yy+1.96*sem,color=COLORS[i],alpha=.16)
        yy=np.mean(np.maximum.accumulate(arr.to_numpy(),axis=1)>=target,axis=0);axs[1].step(xx,yy,where='post',color=COLORS[i],label=id)
    axs[0].axhline(target,color='gray',ls=':',lw=1);axs[0].set_ylabel('Search HV');axs[1].set_ylabel('Fraction reaching fixed target');axs[1].set_ylim(-.02,1.02)
    for ax in axs:ax.set_xlabel('Objective evaluations');ax.legend(frameon=False)
    fig.suptitle('2PPaPaR independent confirmation: 30 new seeds');save(fig,'03_confirmation_convergence')
    fig,axs=plt.subplots(1,3,figsize=(11.5,3.8),layout='constrained');a=confirm[confirm.Problem=='PPAR'];base=a[a.Variant=='B'].sort_values('Seed')
    for panel,met in enumerate(['MillionHV','AUC']):
        vals=[]
        for id in cand:vals.append(100*(a[a.Variant==id].sort_values('Seed')[met].values-base[met].values)/base[met].values)
        axs[panel].boxplot(vals,tick_labels=cand,showfliers=False)
        for i,val in enumerate(vals):axs[panel].scatter(np.full(len(val),i+1)+np.linspace(-.1,.1,len(val)),val,s=13,alpha=.65,color=COLORS[i+1])
        axs[panel].axhline(0,color='gray',ls='--');axs[panel].set_ylabel('Paired change from B (%)');axs[panel].set_title('Final HV' if panel==0 else 'HV AUC')
    sub=stab[stab.Metric=='MillionHV'];x=np.arange(len(sub));y=sub.SDRatio.values
    for j,row in enumerate(sub.itertuples()):axs[2].plot([j,j],[row.SDRatioLow,row.SDRatioHigh],color=COLORS[1]);axs[2].plot([j-.04,j+.04],[row.SDRatioLow,row.SDRatioLow],color=COLORS[1]);axs[2].plot([j-.04,j+.04],[row.SDRatioHigh,row.SDRatioHigh],color=COLORS[1])
    axs[2].scatter(x,y,color=COLORS[1]);axs[2].axhline(1,color='gray',ls='--');axs[2].set_xticks(x,sub.Variant);axs[2].set_ylabel('Final-HV SD ratio to B');axs[2].set_title('Variability: paired bootstrap 95% CI')
    save(fig,'04_confirmation_quality_stability')
    fig,axs=plt.subplots(1,3,figsize=(11.5,3.6),layout='constrained');pr=profiles[profiles.Problem=='PPAR'];show=['N11','N13','B','N31','N33','W2C005'];stages=['early','middle','late']
    for i,id in enumerate(show):
        a=pr[pr.Variant==id]
        for ax,met in zip(axs,['NoiseRMS','FloorFraction','Pulses']):ax.plot(range(3),[a[a.Stage==stage][met].mean() for stage in stages],marker='o',color=COLORS[i],label=id)
    for ax,label in zip(axs,['Applied regular-noise RMS','Fraction at step-size floor','Pulse events per stage']):ax.set_xticks(range(3),['1–50','51–200','201–250']);ax.set_xlabel('Generation range');ax.set_ylabel(label)
    axs[0].set_yscale('log');axs[0].legend(frameon=False,ncol=2,fontsize=8);fig.suptitle('2PPaPaR mechanism activation along complete trajectories');save(fig,'05_mechanism_activation')
    fig,axs=plt.subplots(1,2,figsize=(10,3.7),layout='constrained');s=screen[screen.Problem=='DTLZ3'];val=np.array([[s[s.Variant==id].IGD.mean() for id in row] for row in grid]);im=axs[0].imshow(val,cmap='viridis_r');axs[0].grid(False)
    for i in range(3):
        for j in range(3):axs[0].text(j,i,f'{val[i,j]:.3f}',ha='center',va='center',color='white' if val[i,j]>val.mean() else 'black')
    axs[0].set_xticks(range(3),['0.005','0.020','0.050']);axs[0].set_yticks(range(3),['0.025','0.050','0.100']);axs[0].set_xlabel('Step-size floor');axs[0].set_ylabel('Noise gain');axs[0].set_title('Screening mean IGD');fig.colorbar(im,ax=axs[0])
    a=confirm[confirm.Problem=='DTLZ3'];vals=[a[a.Variant==id].IGD.values for id in ids];axs[1].boxplot(vals,tick_labels=ids)
    axs[1].set_ylabel('Final IGD (lower is better)');axs[1].set_title('Confirmation of engineering-selected settings');fig.suptitle('DTLZ3: auxiliary multimodal convergence test');save(fig,'06_dtlz3_auxiliary')
    fig,axs=plt.subplots(1,2,figsize=(10,3.6),layout='constrained');a=confirm[confirm.Problem=='PPAR']
    for i,id in enumerate(ids):
        q=a[a.Variant==id].sort_values('Seed');err=100*(q.MillionHV-q.FineHV)/q.MillionHV;axs[0].plot(range(1,len(q)+1),err,'o',ms=3,color=COLORS[i],label=id)
        if id!='B':
            b=a[a.Variant=='B'].sort_values('Seed');x=(q.FineHV.values-b.FineHV.values);y=q.MillionHV.values-b.MillionHV.values;axs[1].scatter(x,y,s=20,color=COLORS[i],label=id)
    axs[0].set_xlabel('Seed index');axs[0].set_ylabel('(Million HV − fine HV) / million HV (%)');axs[1].set_xlabel('Paired HV difference: 262,144 points');axs[1].set_ylabel('Paired HV difference: 1,048,576 points');axs[1].axhline(0,color='gray',ls=':');axs[1].axvline(0,color='gray',ls=':')
    for ax in axs:ax.legend(frameon=False)
    fig.suptitle('Numerical integration sensitivity of final engineering archives');save(fig,'07_integration_sensitivity')
    print('Saved 7 PNG/PDF figure pairs')
if __name__=='__main__':main()
