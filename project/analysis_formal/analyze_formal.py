"""Audit and analyze the preregistered 420-run experiment, without new optimization."""
from pathlib import Path
import csv, hashlib, itertools, json, math, re
import numpy as np
from scipy.io import loadmat
from scipy.stats import rankdata, wilcoxon

ROOT=Path(__file__).resolve().parents[1]
OUT=Path(__file__).resolve().parent
NAMES=['MODE-CD-G','MODE-EAR-G','MODE-CD-S','MODE-EAR-S','MV-NSGA-II','MV-SPEA2','CAT-QMC']
CYCLES=[2.5,3.,3.5]
SEEDS=list(range(93101,93121))
RNG=np.random.default_rng(20260921)

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def write_csv(name, rows):
    assert rows
    with (OUT/name).open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)

def hv_rectangles(F):
    if len(F)==0: return 0.,0
    z=np.column_stack(((F[:,0]-.7)/.8,F[:,1])); inside=np.all(z<1.1,axis=1)
    excluded=int((~inside).sum()); z=z[inside]
    if len(z)==0: return 0.,excluded
    edges=np.unique(np.r_[z[:,0],1.1]); value=0.
    for left,right in zip(edges[:-1],edges[1:]):
        value+=(right-left)*(1.1-np.min(z[z[:,0]<=left,1]))
    return float(value),excluded

def signed_rank(d):
    d=np.round(np.asarray(d,dtype=float),12); d=d[d!=0]
    if len(d)==0: return 1.,0.,0.
    r2=np.rint(2*rankdata(np.abs(d),method='average')).astype(int)
    positive=int(r2[d>0].sum()); total=int(r2.sum()); lower=min(positive,total-positive)
    counts=np.zeros(total+1,dtype=np.int64); counts[0]=1; reach=0
    for r in r2:
        old=counts.copy(); counts[r:reach+r+1]+=old[:reach+1]; reach+=r
    p=min(1.,2*float(counts[:lower+1].sum())/(2**len(d)))
    rb=(2*positive-total)/total
    return p,lower/2.,rb

def holm(p):
    p=np.asarray(p); order=np.argsort(p,kind='stable'); out=np.empty(len(p)); running=0.
    for j,i in enumerate(order):
        running=max(running,(len(p)-j)*p[i]); out[i]=min(1.,running)
    return out

def effect(d):
    d=np.asarray(d); p,w,rb=signed_rank(d)
    means=d[RNG.integers(0,len(d),size=(10000,len(d)))].mean(axis=1)
    lo,hi=np.quantile(means,[.025,.975])
    return dict(mean_difference=float(d.mean()),median_difference=float(np.median(d)),
                ci95_mean_low=float(lo),ci95_mean_high=float(hi),
                wins=int(np.sum(d>1e-12)),losses=int(np.sum(d< -1e-12)),ties=int(np.sum(np.abs(d)<=1e-12)),
                signed_rank_statistic=w,rank_biserial=rb,p_raw=p)

def self_check():
    assert abs(hv_rectangles(np.array([[.7,1.],[1.5,0.]]))[0]-.21)<1e-12
    assert signed_rank([0,0,0])[0]==1
    assert signed_rank([1,2,3,4,5])[0]==2/32
    for d in [np.array([1.,-1,2,-3,0]),np.array([1.,2,4,-8,16])]:
        nz=d[d!=0]; r=rankdata(abs(nz)); observed=min(r[nz>0].sum(),r[nz<0].sum())
        sums=[r[np.array(signs)==1].sum() for signs in itertools.product([0,1],repeat=len(nz))]
        exact=min(1.,2*np.mean(np.asarray(sums)<=observed))
        assert abs(signed_rank(d)[0]-exact)<1e-15
    assert abs(signed_rank([1,2,4,-8,16])[0]-wilcoxon([1,2,4,-8,16],method='exact').pvalue)<1e-15
    assert np.allclose(holm([.01,.04,.03]),[.03,.06,.06])

def main():
    self_check(); OUT.mkdir(exist_ok=True)
    manifest=json.loads((ROOT/'provenance/formal_manifest.json').read_text(encoding='utf-8'))
    for item in manifest['files']: assert digest(ROOT/item['path'])==item['sha256'],item['path']
    actual=list((ROOT/'formal_v01').glob('*.mat')); assert len(actual)==420,len(actual)
    runs=[]; data={}; trace_rows=[]; archive_rows=[]; engineering=[]; hash_rows=[]; endpoint_rows=[]
    for cycle,seed,name in itertools.product(CYCLES,SEEDS,NAMES):
        p=ROOT/'formal_v01'/f'cycle{cycle:.1f}_{name}_seed{seed}.mat'; assert p.exists(),p
        r=loadmat(p,simplify_cells=True)['result']; X,F,CV,tr=r['X'],r['F'],r['CV'],r['trace']
        assert r['method']==name and r['seed']==seed and r['FE']==32064 and r['N']==64 and r['generations']==500
        assert r['cycle_limit_s']==cycle and r['config']['cycle_limit_s']==cycle
        assert json.loads(str(r['manifest']))==manifest
        assert X.shape==(64,4) and F.shape==(64,2) and CV.shape==(64,) and tr.shape==(501,7)
        assert np.all(np.isfinite(X)) and np.all(np.isfinite(F)) and np.all(np.isfinite(CV)) and np.all(np.isfinite(tr))
        assert np.all(CV>=0) and np.all(F[:,1]>=0)
        assert np.all((X[:,0]>=1)&(X[:,0]<=19)&(X[:,0]==X[:,0].astype(int)))
        assert np.all(X[:,1:]>=np.array([.7,.15,.1])-1e-13) and np.all(X[:,1:]<=np.array([1.5,.49,.5])+1e-13)
        assert np.array_equal(tr[:,0],np.arange(501)) and np.array_equal(tr[:,1],64*np.arange(1,502))
        saved=np.loadtxt(p.with_name(p.stem+'_final.csv'),delimiter=',')
        assert np.allclose(saved,np.column_stack((X,F,CV)),rtol=0,atol=1e-12)
        assert np.allclose(np.loadtxt(p.with_name(p.stem+'_trace.csv'),delimiter=','),tr,rtol=0,atol=1e-10)
        h,excluded=hv_rectangles(F[CV==0]); assert abs(h-tr[-1,2])<1e-12
        assert r['max_coverage_excess']<1e-10
        feas=CV==0
        row=dict(cycle_limit_s=cycle,seed=seed,method=name,FE=32064,HV=h,
                 search_seconds=float(r['seconds']),final_feasible_fraction=float(feas.mean()),
                 final_unique_designs=len(np.unique(X,axis=0)),final_feasible_catalogues=len(np.unique(X[feas,0])),
                 final_archive_catalogues=int(tr[-1,6]),reference_excluded=excluded,
                 ear_calls=int(r['ear_calls']),ear_fallbacks=int(r['ear_fallbacks']),
                 coverage_excess=float(r['max_coverage_excess']),HV_crosscheck_error=abs(h-tr[-1,2]))
        runs.append(row); data[(cycle,seed,name)]={'raw':r,'row':row}
        hash_rows.append(dict(file=p.relative_to(ROOT).as_posix(),sha256=digest(p),bytes=p.stat().st_size))
        for t in [.05,.1,.2]:
            valid=feas&(F[:,1]<=t)
            value=float(2*(np.min(F[valid,0])+.25)) if np.any(valid) else None
            engineering.append(dict(cycle_limit_s=cycle,seed=seed,method=name,residual_threshold_um=t,
                                    attained=int(value is not None),minimum_cycle_s=value))
        for k in range(64):
            endpoint_rows.append(dict(cycle_limit_s=cycle,seed=seed,method=name,point=k+1,catalog_row=int(X[k,0]),T_s=X[k,1],r=X[k,2],u=X[k,3],residual_um=F[k,1],CV=CV[k]))
    # Recheck that all seven initial scalar measures agree for paired seeds.
    initmax=0.
    for c,s in itertools.product(CYCLES,SEEDS):
        hv0=[data[(c,s,n)]['raw']['trace'][0,2] for n in NAMES]
        initmax=max(initmax,max(hv0)-min(hv0)); assert max(hv0)-min(hv0)<1e-12
    summaries=[]; comparisons=[]; factorial=[]; engineering_summary=[]
    for c in CYCLES:
        values={n:np.array([data[(c,s,n)]['row']['HV'] for s in SEEDS]) for n in NAMES}
        for n in NAMES:
            rr=[data[(c,s,n)]['row'] for s in SEEDS]; v=values[n]
            summaries.append(dict(cycle_limit_s=c,method=n,n=20,HV_mean=float(v.mean()),HV_median=float(np.median(v)),
                HV_std=float(v.std(ddof=1)),HV_min=float(v.min()),HV_max=float(v.max()),
                mean_final_feasible_fraction=float(np.mean([x['final_feasible_fraction'] for x in rr])),
                median_search_seconds=float(np.median([x['search_seconds'] for x in rr])),
                median_feasible_catalogues=float(np.median([x['final_feasible_catalogues'] for x in rr])),
                median_archive_catalogues=float(np.median([x['final_archive_catalogues'] for x in rr])),
                ear_calls=sum(x['ear_calls'] for x in rr),ear_fallbacks=sum(x['ear_fallbacks'] for x in rr)))
            traces=np.stack([data[(c,s,n)]['raw']['trace'] for s in SEEDS])
            for g in range(501):
                trace_rows.append(dict(cycle_limit_s=c,method=n,generation=g,FE=int(traces[0,g,1]),
                    HV_median=float(np.median(traces[:,g,2])),HV_q25=float(np.quantile(traces[:,g,2],.25)),HV_q75=float(np.quantile(traces[:,g,2],.75))))
            for threshold in [.05,.1,.2]:
                matches=[r for r in engineering if r['cycle_limit_s']==c and r['method']==n and r['residual_threshold_um']==threshold]
                vals=[r['minimum_cycle_s'] for r in matches if r['attained']]
                engineering_summary.append(dict(cycle_limit_s=c,method=n,residual_threshold_um=threshold,attained_runs=len(vals),total_runs=20,
                    conditional_median_cycle_s=float(np.median(vals)) if vals else None,
                    conditional_min_cycle_s=float(np.min(vals)) if vals else None))
        local=[]
        for n in NAMES:
            if n=='MODE-EAR-S': continue
            row=dict(cycle_limit_s=c,candidate='MODE-EAR-S',comparator=n,**effect(values['MODE-EAR-S']-values[n])); local.append(row)
        adj=holm([r['p_raw'] for r in local])
        for row,padj in zip(local,adj):
            row['p_holm_6']=float(padj); row['decision']='higher' if padj<.05 and row['mean_difference']>0 else ('lower' if padj<.05 and row['mean_difference']<0 else 'not_significant'); comparisons.append(row)
        f00,f10,f01,f11=[values[n] for n in NAMES[:4]]
        fs={'A_ear':((f10-f00)+(f11-f01))/2,'B_stratified':((f01-f00)+(f11-f10))/2,'AB_interaction':f11-f10-f01+f00}
        local=[dict(cycle_limit_s=c,effect=key,**effect(val)) for key,val in fs.items()]
        adj=holm([r['p_raw'] for r in local])
        for row,padj in zip(local,adj): row['p_holm_3']=float(padj); factorial.append(row)
        for key,values0 in fs.items():
            for seed,v in zip(SEEDS,values0): archive_rows.append(dict(cycle_limit_s=c,seed=seed,effect=key,value=float(v)))
    write_csv('run_metrics.csv',runs); write_csv('summary.csv',summaries); write_csv('paired_comparisons.csv',comparisons)
    write_csv('factorial_effects.csv',factorial); write_csv('factorial_by_seed.csv',archive_rows)
    write_csv('engineering_by_run.csv',engineering); write_csv('engineering_summary.csv',engineering_summary)
    write_csv('convergence_summary.csv',trace_rows); write_csv('all_final_designs.csv',endpoint_rows); write_csv('raw_hashes.csv',hash_rows)
    audit={'status':'PASS','runs':420,'total_FE':sum(r['FE'] for r in runs),'final_designs':420*64,
           'matlab_python_HV_max_error':max(r['HV_crosscheck_error'] for r in runs),'initial_HV_max_difference':initmax,
           'reference_excluded_total':sum(r['reference_excluded'] for r in runs),'max_coverage_excess':max(r['coverage_excess'] for r in runs),
           'final_feasible_fraction_min':min(r['final_feasible_fraction'] for r in runs),
           'inferential_checks':'exact signed-rank DP checked against brute force and SciPy; Holm fixture passed',
           'manifest_inputs_verified':len(manifest['files']),'script_sha256':digest(Path(__file__)),
           'scope':'Completeness, fixed FE, hashes, raw/CSV agreement, independent HV and statistical arithmetic. No physical validation.'}
    (OUT/'analysis_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(audit,indent=2))
    print('MEDIAN HV:')
    for c in CYCLES:
        print(c,[(r['method'],round(r['HV_median'],8)) for r in summaries if r['cycle_limit_s']==c])
    print('CANDIDATE VS BASELINE:')
    for r in comparisons:
        if r['comparator']=='MODE-CD-G': print(json.dumps(r))
    print('FACTORIAL:')
    for r in factorial: print(json.dumps(r))

if __name__=='__main__': main()
