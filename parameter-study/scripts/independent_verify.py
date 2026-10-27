from pathlib import Path
import json, hashlib, math, sys
import numpy as np
import pandas as pd
R=Path(__file__).resolve().parents[1]; D=R/'data'
IDS=['N11','N12','N13','N21','B','N23','N31','N32','N33','W2','W10','C005','W2C005']
NAMES=['eta_low_to_mid','eta_mid_to_high','floor_low_to_mid','floor_mid_to_high','noise_corner_interaction','window_5_to_2','cap_020_to_0005','window_cap_interaction','window_5_to_10']
def same(a,b): return np.allclose(a,b,rtol=3e-8,atol=3e-11,equal_nan=True)
def hv(f,r):
    f=f[np.all(f<r,axis=1)]
    if not len(f): return 0.
    if len(r)==1:return max(0.,r[0]-f[:,0].min())
    cuts=np.unique(np.r_[f[:,-1],r[-1]])
    return sum((hi-lo)*hv(f[f[:,-1]<=lo,:-1],r[:-1]) for lo,hi in zip(cuts[:-1],cuts[1:]))
def exact(d):
    d=d[d!=0]
    if not len(d):return 1.,0.
    order=np.argsort(abs(d),kind='stable');rank=np.empty(len(d));i=0
    while i<len(d):
        j=i+1
        while j<len(d) and abs(d[order[j]])==abs(d[order[i]]):j+=1
        rank[order[i:j]]=(i+1+j)/2;i=j
    w=np.rint(2*rank).astype(int);counts=np.array([1],np.int64)
    for step in w:
        nextcounts=np.zeros(len(counts)+step,np.int64);nextcounts[:len(counts)]+=counts;nextcounts[step:]+=counts;counts=nextcounts
    obs=w[d>0].sum();return min(1.,2*min(counts[:obs+1].sum(),counts[obs:].sum())/2**len(d)),(np.sign(d)*rank).sum()/rank.sum()
def holm(p):
    p=np.asarray(p);ix=np.argsort(p);out=np.empty(len(p));out[ix]=np.minimum(1,np.maximum.accumulate(p[ix]*(len(p)-np.arange(len(p)))));return out
def effects(v):
    return np.c_[np.mean(v[:,3:6]-v[:,:3],axis=1),np.mean(v[:,6:9]-v[:,3:6],axis=1),np.mean(v[:,[1,4,7]]-v[:,[0,3,6]],axis=1),np.mean(v[:,[2,5,8]]-v[:,[1,4,7]],axis=1),(v[:,8]-v[:,6])-(v[:,2]-v[:,0]),((v[:,9]-v[:,4])+(v[:,12]-v[:,11]))/2,((v[:,11]-v[:,4])+(v[:,12]-v[:,9]))/2,(v[:,12]-v[:,9])-(v[:,11]-v[:,4]),v[:,10]-v[:,4]]
def audit_phase(phase):
    runs=pd.DataFrame(json.loads((D/f'{phase}_runs.json').read_text(encoding='utf-8'))).fillna(np.nan)
    fronts=json.loads((D/f'{phase}_fronts.json').read_text(encoding='utf-8'));counter=0
    target=json.loads((D/'targets.json').read_text())['engineering_HV_target']
    for entry in fronts:
        row=runs[(runs.Problem==entry['problem'])&(runs.Variant==entry['variant'])&(runs.Seed==entry['seed'])].iloc[0]
        f=np.atleast_2d(entry['nativeF']);cv=np.asarray(entry['nativeCV']);history=np.array(entry['history']);valid=cv==0
        lo,scale=(np.array([-8e6,0,-1]),np.array([8e6,2,1])) if entry['problem']=='PPAR' else (np.zeros(3),np.ones(3))
        assert same(hv((f[valid]-lo)/scale,np.full(3,1.1))/1.1**3,row.SearchHV)
        assert same(np.trapezoid(history[:,2],history[:,1])/25000,row.AUC)
        assert row.FE==25100 and np.array_equal(history[:,1],np.arange(100,25101,100));counter+=3
        if entry['problem']=='PPAR':
            hit=np.flatnonzero(history[:,2]>=target);assert row.Reached==bool(len(hit));assert row.CappedTargetFE==(history[hit[0],1] if len(hit) else 25100)
            for k,ff in enumerate(entry['fine']):
                f=np.array(ff['F']);cv=np.asarray(ff['CV']);f=f[cv==0]
                assert same(hv((f-lo)/scale,np.full(3,1.1))/1.1**3,row.FineHV if k==0 else row.MillionHV);counter+=1
        else:
            x=np.array(entry['nativeX']);z=x[:,2:]-.5;g=100*np.sum(z*z+1-np.cos(20*np.pi*z),axis=1)
            assert same(g.mean(),row.MeanG)
            ang=np.c_[np.cos(np.pi*x[:,0]/2)*np.cos(np.pi*x[:,1]/2),np.cos(np.pi*x[:,0]/2)*np.sin(np.pi*x[:,1]/2),np.sin(np.pi*x[:,0]/2)]
            assert same(f,(1+g[:,None])*ang)
            w=np.array([[i,j,60-i-j] for i in range(61) for j in range(61-i)],float);pf=w/np.linalg.norm(w,axis=1)[:,None]
            igd=np.linalg.norm(pf[:,None,:]-f[None,:,:],axis=2).min(axis=1).mean();assert same(igd,row.IGD);counter+=3
    stats=pd.read_csv(D/f'{phase}_statistics.csv');boot=np.loadtxt(D/f'{phase}_bootstrap.csv',delimiter=',',dtype=int)-1
    ids=IDS
    if phase=='confirm':
        candidates=json.loads((D/'selection.json').read_text(encoding='utf-8'))['candidates'];candidates=[candidates] if isinstance(candidates,str) else candidates;ids=['B']+candidates
    for (problem,metric),s in stats.groupby(['Problem','Metric'],sort=False):
        vals=np.column_stack([runs[(runs.Problem==problem)&(runs.Variant==v)].sort_values('Seed')[metric].values for v in ids])
        delta=effects(vals) if phase=='screen' else vals[:,1:]-vals[:,[0]];names=NAMES if phase=='screen' else [v+'_minus_B' for v in ids[1:]]
        for row in s.itertuples():
            dd=delta[:,names.index(row.Contrast)];p,e=exact(dd);direction=-1 if metric in ['CappedTargetFE','IGD','MeanG'] else 1
            ci=np.quantile(dd[boot].mean(axis=0),[.025,.975],method='hazen')
            for actual,expected in [(dd.mean(),row.MeanDifference),(np.median(dd),row.MedianDifference),(p,row.RawP),(e*direction,row.BenefitRankEffect),(ci[0],row.CILow),(ci[1],row.CIHigh)]:assert same(actual,expected),(phase,problem,metric,row.Contrast,actual,expected)
        assert same(holm(s.RawP),s.HolmLocal)
    for _,s in stats.groupby('Problem',sort=False):assert same(holm(s.RawP),s.HolmGlobal)
    if phase=='confirm':
        stability=pd.read_csv(D/'confirm_stability.csv')
        for row in stability.itertuples():
            a=runs[(runs.Problem=='PPAR')&(runs.Variant==row.Variant)].sort_values('Seed')[row.Metric].to_numpy()
            b=runs[(runs.Problem=='PPAR')&(runs.Variant=='B')].sort_values('Seed')[row.Metric].to_numpy()
            ratios=np.std(a[boot],axis=0,ddof=1)/np.std(b[boot],axis=0,ddof=1);ci=np.quantile(ratios,[.025,.975],method='hazen')
            quant=lambda x,axis=None:np.quantile(x,.1,axis=axis,method='hazen')
            qc=np.quantile(quant(a[boot],axis=0)-quant(b[boot],axis=0),[.025,.975],method='hazen')
            assert same(np.std(a,ddof=1)/np.std(b,ddof=1),row.SDRatio) and same(ci,[row.SDRatioLow,row.SDRatioHigh])
            assert same(quant(a)-quant(b),row.P10Difference) and same(qc,[row.P10Low,row.P10High]);counter+=4
    return {'runs':len(runs),'numerical_checks':counter,'statistical_rows':len(stats)}
def main():
    audit={phase:audit_phase(phase) for phase in ['screen','confirm']}
    runs=pd.DataFrame(json.loads((D/'screen_runs.json').read_text(encoding='utf-8')))
    ids=[v for v in IDS if v!='B'];means=[runs[(runs.Problem=='PPAR')&(runs.Variant==v)][['MillionHV','AUC']].mean().values for v in ids];means=np.array(means)
    sel=json.loads((D/'selection.json').read_text(encoding='utf-8'));assert sel['accuracy']==ids[np.argmax(means[:,0])] and sel['speed']==ids[np.argmax(means[:,1])]
    audit['engineering_only_selection_verified']=True
    frozen=json.loads((R/'audit/preserved_round2_manifest.json').read_text(encoding='utf-8'));changed=[]
    if '--portable' not in sys.argv:
        for rec in frozen:
            p=Path(rec['path'])
            if not p.is_file() or hashlib.file_digest(p.open('rb'),'sha256').hexdigest()!=rec['sha256']:changed.append(str(p))
        assert not changed; audit['preserved_original_files']=len(frozen)
        src=R.parent/'MO_PACPO_参数作用机理_第二轮_20261026'
        for name in ['Core','Mechanism','Pulse','Tape','Front','Theory']:
            assert (R/'code'/f'ER{name}.m').read_text(encoding='utf-8')==(src/'code'/f'DM{name}.m').read_text(encoding='utf-8').replace('DM','ER')
        assert (R/'code/reference/PPaPaRModel.m').read_bytes()==(src/'code/reference/PPaPaRModel.m').read_bytes()
        audit['algorithm_and_model_unchanged']=True
    else:audit['originals_check']='skipped in portable mode; see original local audit'
    audit['status']='pass'
    (R/'audit/independent_verification.json').write_text(json.dumps(audit,indent=2),encoding='utf-8');print(json.dumps(audit,indent=2))
if __name__=='__main__':main()
