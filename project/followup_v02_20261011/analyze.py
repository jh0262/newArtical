"""Audit 120 raw ledgers and compute the prespecified paired comparisons."""
from pathlib import Path
import csv,hashlib,json,sys
import numpy as np
from scipy.io import loadmat

ROOT=Path(__file__).resolve().parent;BASE=ROOT.parent;OUT=ROOT/'analysis'
sys.path.insert(0,str(BASE/'analysis_formal'))
import analyze_formal as previous

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(name,rows):
    with (OUT/name).open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

def hv(F):
    if len(F)==0:return 0.
    z=np.column_stack(((F[:,0]-.7)/.8,F[:,1]));z=z[np.all(z<1.1,axis=1)]
    if len(z)==0:return 0.
    z=z[np.argsort(z[:,0],kind='stable')];bottom=np.minimum.accumulate(z[:,1])
    last=np.r_[np.flatnonzero(np.diff(z[:,0])!=0),len(z)-1]
    return float(np.sum(np.diff(np.r_[z[last,0],1.1])*(1.1-bottom[last])))

def main():
    OUT.mkdir(exist_ok=True);previous.RNG=np.random.default_rng(20261011);previous.self_check()
    assert abs(hv(np.array([[.7,1.],[1.5,0.]]))-.21)<1e-12
    manifest=json.loads((ROOT/'provenance/manifest.json').read_text(encoding='utf-8'))
    for item in manifest['files']:assert sha(ROOT/item['path'])==item['sha256']
    old=json.loads((BASE/'provenance/formal_manifest.json').read_text(encoding='utf-8'))
    for item in old['files']:assert sha(BASE/item['path'])==item['sha256']
    files=sorted((ROOT/'raw').glob('*.mat'));assert len(files)==120,len(files)
    metrics=[];hashes=[];engineering=[];convergence=[];paired_data={};initial={};maxhv=0.;maxcv=0.
    timings=[]
    for file in files:
        r=loadmat(file,simplify_cells=True)['result']; label=str(r['label']);cycle=float(r['cycle_limit_s']);seed=int(r['seed'])
        assert label in [f'D{i}' for i in range(6)] and cycle in [2.5,3.5] and seed in range(104101,104111)
        assert int(r['FE'])==32064 and int(r['N'])==64 and int(r['generations'])==500
        assert json.loads(str(r['manifest']))==manifest
        X,F,CV,G,P,A,tr=(np.asarray(r[k]) for k in ['history_X','history_F','history_CV','history_G','population_ids','archive_ids','trace'])
        assert X.shape==(32064,4) and F.shape==(32064,2) and CV.shape==(32064,) and G.shape==(32064,10)
        assert P.shape==(501,64) and A.shape==(501,64) and tr.shape==(501,7)
        assert all(np.all(np.isfinite(x)) for x in [X,F,CV,G,tr])
        assert np.all(X[:,0]==np.floor(X[:,0])) and np.all((X[:,0]>=1)&(X[:,0]<=19))
        assert np.all(X[:,1:]>=np.array([.7,.15,.1])-1e-14) and np.all(X[:,1:]<=np.array([1.5,.49,.5])+1e-14)
        assert np.array_equal(X[:,1],F[:,0]) and np.all(F[:,1]>=0)
        e=float(np.max(np.abs(CV-np.maximum(G-1e-10,0).sum(axis=1))));maxcv=max(maxcv,e);assert e<1e-12
        assert np.allclose(G[:,0],2*(X[:,1]+.25)/cycle-1,atol=1e-14,rtol=0)
        assert np.array_equal(tr[:,0],np.arange(501)) and np.array_equal(tr[:,1],64*np.arange(1,502))
        key=(cycle,seed)
        if key in initial:assert np.array_equal(initial[key],X[:64])
        else:initial[key]=X[:64].copy()
        for g in range(501):
            ids=P[g].astype(int)-1;a=A[g][A[g]>0].astype(int)-1
            assert np.all(np.diff(ids)>0) and ids.min()>=0 and ids.max()<64*(g+1)
            assert len(a)<=64 and np.all(np.diff(a)>0) and np.all(CV[a]==0)
            if g:
                children=np.arange(64*g,64*(g+1));assert np.all(np.isin(ids,np.r_[P[g-1].astype(int)-1,children]))
                before=A[g-1][A[g-1]>0].astype(int)-1;assert np.all(np.isin(a,np.r_[before,children]))
            ff=F[ids[CV[ids]==0]];h=hv(ff);delta=abs(h-tr[g,2]);maxhv=max(maxhv,delta);assert delta<1e-12
            assert abs(np.mean(CV[ids]==0)-tr[g,3])<1e-15
            if g%10==0 or g==500:convergence.append(dict(cycle_limit_s=cycle,method=label,seed=seed,generation=g,FE=64*(g+1),HV=h))
        ids=P[-1].astype(int)-1;ok=ids[CV[ids]==0];ff=F[ok]
        details=np.asarray(r['selection_details']);ear=details[:,3]==1
        assert details.shape==(500,8)
        assert np.all(details[ear,5]<=details[ear,6]+1e-10)
        excluded=int(np.sum(~np.all(np.column_stack(((ff[:,0]-.7)/.8,ff[:,1]))<1.1,axis=1)))
        row=dict(cycle_limit_s=cycle,method=label,seed=seed,FE=32064,HV=hv(ff),compute_seconds=float(r['compute_seconds']),final_feasible_fraction=float(len(ok)/64),feasible_evaluations=int(np.sum(CV==0)),catalogues=int(len(np.unique(X[ok,0]))),archive_catalogues=int(tr[-1,6]),ear_calls=int(ear.sum()),ear_fallbacks=int(details[ear,4].sum()),reference_excluded=excluded)
        metrics.append(row);paired_data[(cycle,label,seed)]=row['HV'];hashes.append(dict(file=file.relative_to(ROOT).as_posix(),sha256=sha(file)))
        for threshold in [.05,.1,.2]:
            elig=ok[F[ok,1]<=threshold];best=np.nan if len(elig)==0 else float(np.min(2*(F[elig,0]+.25)))
            engineering.append(dict(cycle_limit_s=cycle,method=label,seed=seed,residual_threshold_um=threshold,attained=int(len(elig)>0),shortest_cycle_s=best))
        for name,value in zip(['initialization','objective','variation','selection','archive','logging'],r['component_seconds']):timings.append(dict(cycle_limit_s=cycle,method=label,seed=seed,component=name,seconds=float(value)))
        saved=np.loadtxt(file.with_name(file.stem+'_final.csv'),delimiter=',');expected=np.column_stack((ids+1,X[ids],F[ids],CV[ids]));assert np.allclose(saved,expected,rtol=0,atol=1e-12)
        assert np.allclose(np.loadtxt(file.with_name(file.stem+'_trace.csv'),delimiter=','),tr,atol=1e-12,rtol=0)
    summary=[];contrasts=[];interaction=[];engsummary=[]
    for c in [2.5,3.5]:
        for name in [f'D{i}' for i in range(6)]:
            rr=[r for r in metrics if r['cycle_limit_s']==c and r['method']==name];assert len(rr)==10
            vals=np.array([r['HV'] for r in rr]); summary.append(dict(cycle_limit_s=c,method=name,n=10,HV_mean=float(vals.mean()),HV_median=float(np.median(vals)),HV_std=float(vals.std(ddof=1)),HV_min=float(vals.min()),HV_max=float(vals.max()),median_seconds=float(np.median([r['compute_seconds'] for r in rr]))))
            for t in [.05,.1,.2]:
                ee=[r for r in engineering if r['cycle_limit_s']==c and r['method']==name and r['residual_threshold_um']==t]; v=[r['shortest_cycle_s'] for r in ee if r['attained']]
                engsummary.append(dict(cycle_limit_s=c,method=name,residual_threshold_um=t,attained=len(v),n=10,median_shortest_cycle_s=float(np.median(v)) if v else np.nan))
        local=[]
        for a,b in [('D1','D0'),('D3','D0'),('D4','D0'),('D5','D4'),('D2','D1')]:
            d=np.array([paired_data[(c,a,s)]-paired_data[(c,b,s)] for s in range(104101,104111)])
            local.append(dict(cycle_limit_s=c,contrast=a+'-'+b,**previous.effect(d)))
        adjusted=previous.holm([r['p_raw'] for r in local])
        for r,p in zip(local,adjusted):r['p_holm_5']=float(p)
        contrasts.extend(local)
        for s in range(104101,104111):interaction.append(dict(cycle_limit_s=c,seed=s,interaction=paired_data[(c,'D4',s)]-paired_data[(c,'D1',s)]-paired_data[(c,'D3',s)]+paired_data[(c,'D0',s)]))
    for name,data in [('run_metrics.csv',metrics),('raw_hashes.csv',hashes),('summary.csv',summary),('paired_comparisons.csv',contrasts),('interaction_by_seed.csv',interaction),('engineering_by_run.csv',engineering),('engineering_summary.csv',engsummary),('convergence.csv',convergence),('component_times.csv',timings)]:write(name,data)
    audit=dict(status='PASS',runs=120,optimization_FE=sum(r['FE'] for r in metrics),history_rows=120*32064,population_states_checked=120*501,original_frozen_inputs=28,followup_frozen_inputs=len(manifest['files']),paired_initializations_checked=len(initial)*6,independent_HV_max_error=maxhv,raw_constraint_CV_max_error=maxcv,reference_excluded=sum(r['reference_excluded'] for r in metrics),new_analysis_FE=0,script_sha256=sha(Path(__file__)),scope='Raw-ledger, budget, subset history, fixed-HV and statistical verification; no new model evaluation or physical validation.')
    (OUT/'analysis_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8');print(json.dumps(audit,indent=2))
    for r in summary:print(json.dumps(r))
    for r in contrasts:print(json.dumps(r))

if __name__=='__main__':main()
