from pathlib import Path
import json, math, hashlib
import numpy as np
import pandas as pd
from scipy.io import loadmat
from scipy.spatial.distance import cdist
R=Path(__file__).absolute().parents[1]
runs=pd.read_csv(R/'data/joint_runs.csv');summary=pd.read_csv(R/'data/joint_summary.csv');stats=pd.read_csv(R/'data/joint_statistics.csv')
boot=np.loadtxt(R/'data/bootstrap_indices.csv',delimiter=',',dtype=int)-1
def same(a,b):return np.isclose(a,b,rtol=3e-7,atol=2e-11,equal_nan=True)
def signedrank(d,direction):
 d=d[np.isfinite(d)];nz=d[d!=0]
 if not len(nz):return 1.,0.,1.,0
 order=np.argsort(abs(nz));rank=np.empty(len(nz));ties=0;i=0
 while i<len(nz):
  j=i+1
  while j<len(nz) and abs(nz[order[j]])==abs(nz[order[i]]):j+=1
  rank[order[i:j]]=(i+1+j)/2;ties+=(j-i)**3-(j-i);i=j
 n=len(nz);var=(n*(n+1)*(2*n+1)-ties/2)/24;z=(rank[nz>0].sum()-n*(n+1)/4)/math.sqrt(var)
 weights=np.rint(2*rank).astype(int);counts=np.array([1],dtype=np.int64)
 for w in weights:
  q=np.zeros(len(counts)+w,dtype=np.int64);q[:len(counts)]+=counts;q[w:]+=counts;counts=q
 obs=int(weights[nz>0].sum());exact=min(1.,2*min(counts[:obs+1].sum(),counts[obs:].sum())/2**n)
 return math.erfc(abs(z)/math.sqrt(2)),direction*np.sum(np.sign(nz)*rank)/sum(rank),exact,n
assert signedrank(np.zeros(30),1)[2]==1
assert signedrank(np.ones(3),1)[2]==.25
assert signedrank(np.array([1,2,3.]),1)[2]==.25
assert signedrank(np.array([-1,2,3.]),1)[2]==.5
def hv(f,r):
 f=f[np.all(f<r,axis=1)]
 if not len(f):return 0.
 if len(r)==1:return max(0.,r[0]-f[:,0].min())
 cuts=np.unique(np.r_[f[:,-1],r[-1]]);ans=0.
 for lo,hi in zip(cuts[:-1],cuts[1:]):ans+=(hi-lo)*hv(f[f[:,-1]<=lo,:-1],r[:-1])
 return ans
assert abs(hv(np.array([[.2,.8],[.8,.2]]),np.ones(2))-.28)<1e-14
assert abs(hv(np.array([[.2,.3,.4]]),np.ones(3))-.336)<1e-14
cache={};metric_checks=0
for row in runs.itertuples():
 key=(row.Problem,row.Variant,row.Seed,row.IntegrationPoints)
 if row.IntegrationPoints:
  z=loadmat(R/'validation'/f'{row.Problem}_{row.Variant}_{row.Seed}.mat',simplify_cells=True)
  j=0 if row.IntegrationPoints==262144 else 1
  f=np.atleast_2d(z['allF'][j]);cv=np.atleast_1d(z['allCV'][j]);good=cv==0
  # Independently reconstruct constrained feasible nondominated membership.
  dom=np.all(f[:,None,:]<=f[None,:,:],axis=2)&np.any(f[:,None,:]<f[None,:,:],axis=2)&good[:,None]
  good &= ~np.any(dom,axis=0)
  assert np.array_equal(good,np.atleast_1d(z['allKeep'][j]).astype(bool))
  f=(f[good]-[-8e6,0,-1])/[8e6,2,1]
  values={'IGD':np.nan,'HV':float(np.ravel(z['hv'])[j]),'SP':float(np.ravel(z['sp'])[j])}
 else:
  z=loadmat(R/'results/runs'/f'{row.Problem}_{row.Variant}_{row.Seed}.mat',variable_names=['result'],simplify_cells=True)['result']
  f=np.atleast_2d(z['F'])[np.atleast_1d(z['CV'])==0];values={'IGD':z['IGD'],'HV':z['HV'],'SP':z['Spacing']}
  if row.Problem=='ZDT6':t=np.linspace(.2807753191,1,2001);pf=np.c_[t,1-t*t]
  else:
   w=np.array([[i,j,60-i-j] for i in range(61) for j in range(61-i)],float)/60
   pf=w/np.sqrt(np.sum(w*w,axis=1))[:,None]
  assert same(cdist(pf,f).min(axis=1).mean(),values['IGD'])
  metric_checks+=1
 calc=hv(f,np.full(f.shape[1],1.1))/1.1**f.shape[1];assert same(calc,values['HV']),(key,calc,values)
 distances=cdist(f,f,'cityblock');np.fill_diagonal(distances,np.inf)
 sp=np.std(distances.min(axis=1),ddof=1) if len(f)>1 else np.nan
 assert same(sp,values['SP']),(key,sp,values)
 for k,val in values.items():assert same(val,getattr(row,k))
 cache[key]=values;metric_checks+=2
def v(problem,mode,point,metric):
 q=runs[(runs.Problem==problem)&(runs.Variant==mode)&(runs.IntegrationPoints==point)].sort_values('Seed')
 assert len(q)==30 and q.Seed.nunique()==30 and (q.FE==25100).all()
 return np.array([cache[(problem,mode,r.Seed,point)][metric] for r in q.itertuples()])
exact=[]
for row in stats.itertuples():
 vals=lambda mode:v(row.Problem,mode,row.IntegrationPoints,row.Metric)
 if row.Contrast=='Interaction':a=vals('Full')-vals('noNoise');b=vals('noLock')-vals('joint')
 else:a,b=(vals(mode) for mode in row.Contrast.split('_'))
 d=a-b;p,e,ex,nz=signedrank(d,1 if row.Metric=='HV' else -1)
 expected={'NValid':30,'NMissing':0,'MeanDifference':d.mean(),'MedianDifference':np.median(d),'RawP':p,'CandidateEffect':e,'Positive':sum(d>0),'Negative':sum(d<0),'Zero':sum(d==0)}
 for k,x in expected.items():assert same(x,getattr(row,k)),(row.Contrast,k,x,getattr(row,k))
 ci=np.quantile(d[boot].mean(axis=0),[.025,.975],method='hazen');assert same(ci[0],row.CILow) and same(ci[1],row.CIHigh)
 exact.append(dict(Problem=row.Problem,Metric=row.Metric,IntegrationPoints=row.IntegrationPoints,Contrast=row.Contrast,NonzeroPairs=nz,ExactP=ex,ApproxP=p,ApproxHolmP=row.HolmP))
keys=['Problem','Metric','IntegrationPoints']
exact=pd.DataFrame(exact);exact['ExactHolmP']=np.nan
for key,g in stats.groupby(keys):
 q=g.sort_values('RawP');assert len(q)==6;h=np.minimum(1,np.maximum.accumulate(q.RawP.to_numpy()*(6-np.arange(6))));assert np.allclose(h,q.HolmP,rtol=1e-12,atol=1e-12)
for key,g in exact.groupby(keys):
 q=g.sort_values('ExactP');h=np.minimum(1,np.maximum.accumulate(q.ExactP.to_numpy()*(6-np.arange(6))));exact.loc[q.index,'ExactHolmP']=h
exact['DecisionChanged']=(exact.ExactHolmP<.05)!=(exact.ApproxHolmP<.05);exact.to_csv(R/'data/joint_exact_sensitivity.csv',index=False)
summary_checks=0
for row in summary.itertuples():
 for metric in ['IGD','HV','SP']:
  a=v(row.Problem,row.Variant,row.IntegrationPoints,metric);a=a[np.isfinite(a)]
  for prefix,fn in [('mean',np.mean),('std',lambda q:np.std(q,ddof=1)),('median',np.median)]:
   val=fn(a) if len(a) else np.nan;assert same(val,getattr(row,prefix+'_'+metric));summary_checks+=1
status=[json.loads(p.read_text('utf-8-sig')) for p in (R/'results/runs').glob('*_status.json')]
assert len(status)==360 and all(s['ok'] for s in status)
manifest=json.loads((R.parent/'PACKAGE_MANIFEST.json').read_text('utf-8'))
for item in manifest:
 if item['path'].endswith('.m'):assert hashlib.sha256((R.parent/item['path']).read_bytes()).hexdigest()==item['sha256']
audit={'status':'pass','new_searches_this_recalculation':0,'original_batch_searches':90,'historical_tape_replays':270,'run_metric_rows':len(runs),'independent_metric_checks':metric_checks,'paired_statistic_and_interval_rows':len(stats),'summary_checks':summary_checks,'exact_test_examples':4,'HV_examples':2,'exact_test_decision_changes':int(exact.DecisionChanged.sum()),'preserved_inputs':len(manifest)}
(R/'audit/independent_verification.json').write_text(json.dumps(audit,indent=2),'utf-8');print(json.dumps(audit,indent=2))
