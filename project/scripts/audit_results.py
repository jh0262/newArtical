"""Independent Python audit of MATLAB raw numerical evidence; no optimization."""
from pathlib import Path
import argparse,collections,csv,datetime,hashlib,json,sys
import numpy as np
from scipy.io import loadmat

ROOT=Path(__file__).resolve().parents[1]
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def objective(name,x):
    u=x[:,0]; tail=x[:,1:]
    if name in ('ZDT1','ZDT2','ZDT3'):
        g=1+9*tail.mean(1); f=u
        if name=='ZDT2': h=1-(f/g)**2
        else:
            h=1-np.sqrt(f/g)
            if name=='ZDT3': h-=f/g*np.sin(10*np.pi*f)
        return np.column_stack((f,g*h))
    if name=='ZDT4':
        g=1+10*tail.shape[1]+np.sum(tail**2-10*np.cos(4*np.pi*tail),1)
        return np.column_stack((u,g*(1-np.sqrt(u/g))))
    if name=='ZDT6':
        f=1-np.exp(-4*u)*np.sin(6*np.pi*u)**6; g=1+9*tail.mean(1)**.25
        return np.column_stack((f,g*(1-(f/g)**2)))
    if name in ('DTLZ2','DTLZ4'):
        g=1+np.sum((tail-.5)**2,1); angle=(u if name=='DTLZ2' else u**100)*np.pi/2
        return np.column_stack((g*np.cos(angle),g*np.sin(angle)))
    if name=='DTLZ7':
        g=1+9*tail.mean(1)
        return np.column_stack((u,(1+g)*2-u*(1+np.sin(3*np.pi*u))))
    raise ValueError(name)

def hv_curves(fronts,lo,span):
    z=(fronts-lo[None,:,None])/span[None,:,None]
    invalid=np.any(z>=1.1,axis=1)
    x=z[:,0,:].copy(); y=z[:,1,:].copy(); x[invalid]=1.1; y[invalid]=1.1
    order=np.argsort(x,axis=0,kind='stable')
    x=np.take_along_axis(x,order,axis=0); y=np.take_along_axis(y,order,axis=0)
    y=np.minimum.accumulate(y,axis=0)
    widths=np.diff(x,axis=0,append=np.full((1,x.shape[1]),1.1))
    return np.sum(widths*(1.1-y),axis=0)

def igdp(f,r):
    d=np.maximum(f[None,:,:]-r[:,None,:],0)
    return np.sqrt((d*d).sum(2)).min(1).mean()

def status():
    counter=collections.Counter(); problems=collections.Counter(); failures=[]
    for p in (ROOT/'runs/formal_v1').glob('*/*/*/*/manifest.json'):
        try: m=read(p)
        except (ValueError,OSError): counter['writing']+=1; continue
        counter[m['status']]+=1
        if m['status']=='completed': problems[m['problem']]+=1
        if m['status']=='failed': failures.append({'path':str(p),'error':m.get('failureMessage')})
    print(json.dumps({'counts':dict(counter),'completed_by_problem':dict(problems),'failures':failures},ensure_ascii=False))

def audit():
    frozen=read(ROOT/'provenance/code_manifest.json')
    for item in frozen['files']: assert sha(ROOT/item['path'])==item['sha256'],item['path']
    manifest_hash=sha(ROOT/'provenance/code_manifest.json')
    config_hash=sha(ROOT/'provenance/study_config.json')
    cfg=read(ROOT/'provenance/study_config.json')
    matrix=list(csv.DictReader((ROOT/'provenance/experiment_matrix.csv').open(encoding='utf-8')))
    assert len(matrix)==2080
    initial_hash={}; rows=[]; proofs=[]; max_obj_error=0.; max_hv_error=0.; max_igd_error=0.
    now=datetime.datetime.now(datetime.timezone.utc)
    freeze=datetime.datetime.fromisoformat(frozen['frozen_at'])
    for k,row in enumerate(matrix,1):
        base=ROOT/'runs/formal_v1'/row['problem']/row['algorithm']/f"seed_{int(row['seed']):06d}"
        completed=[]
        for path in sorted(base.glob('attempt_*/manifest.json')):
            m=read(path)
            if m['status']=='completed': completed.append((path,m))
        assert len(completed)==1,f'{base}: expected exactly one completed attempt, found {len(completed)}'
        path,m=completed[0]; d=path.parent
        assert m['FE']==50100 and m['generations']==500 and m['N']==100
        assert m['seed']==int(row['seed']) and m['D']==int(row['D'])
        assert m['problem']==row['problem'] and m['algorithm']==row['algorithm']
        assert freeze<=datetime.datetime.fromisoformat(m['started_at'])<=datetime.datetime.fromisoformat(m['ended_at'])<=now
        assert sha(d/'code_manifest.json')==manifest_hash
        assert read(d/'config.json')==cfg
        raw=loadmat(d/'raw.mat',simplify_cells=True)
        fronts=raw['Fronts']; x=raw['finalX']; f=raw['finalF']; init=raw['initialX']
        assert fronts.shape==(100,2,501) and np.isfinite(fronts).all()
        assert x.shape==(100,int(row['D'])) and np.isfinite(x).all()
        assert np.array_equal(fronts[:,:,-1],f)
        lo=np.array(raw['referenceLo']); span=np.array(raw['referenceSpan']); assert (span>0).all()
        e=np.max(np.abs(objective(row['problem'],x)-f)); max_obj_error=max(max_obj_error,float(e)); assert e<1e-9,(d,e)
        assert np.max(np.abs(objective(row['problem'],init)-fronts[:,:,0]))<1e-9
        lb=np.zeros(x.shape[1]); ub=np.ones(x.shape[1])
        if row['problem']=='ZDT4': lb[1:]=-5; ub[1:]=5
        assert np.all(x>=lb-1e-12) and np.all(x<=ub+1e-12)
        block=(row['problem'],row['seed']); ih=hashlib.sha256(init.tobytes()).hexdigest()
        if block in initial_hash: assert initial_hash[block]==ih,(d,'initial mismatch')
        else: initial_hash[block]=ih
        hv=hv_curves(fronts,lo,span); he=np.max(np.abs(hv-raw['HV'])); max_hv_error=max(max_hv_error,float(he)); assert he<1e-10,(d,he)
        ref=(raw['referenceF']-lo)/span
        igd=np.asarray(raw['IGDplus'])
        for gen in range(0,501,10):
            v=igdp((fronts[:,:,gen]-lo)/span,ref); ie=abs(v-igd[gen]); max_igd_error=max(max_igd_error,float(ie)); assert ie<1e-10,(d,gen,ie)
        telemetry=np.asarray(raw['Telemetry']); applied=fallback=0; mean_f=mean_cr=mean_plocal=np.nan
        if telemetry.size:
            assert telemetry.shape==(500,13) and np.isfinite(telemetry).all()
            assert np.all((telemetry[:,0]>0)&(telemetry[:,0]<=1))
            assert np.all((telemetry[:,1]>=0)&(telemetry[:,1]<=1))
            assert np.all((telemetry[:,2]>=.1-1e-12)&(telemetry[:,2]<=.9+1e-12))
            assert np.all(telemetry[:,8]<=telemetry[:,9]+1e-10)
            applied=int(telemetry[:,6].sum()); fallback=int(telemetry[:,7].sum())
            mean_f=float(telemetry[:,0].mean()); mean_cr=float(telemetry[:,1].mean()); mean_plocal=float(telemetry[:,2].mean())
        assert abs(igd[-1]-m['finalIGDplus'])<1e-12 and abs(hv[-1]-m['finalHV'])<1e-12
        guard=read(d/'guardrails.json'); assert all(guard[z] for z in ('finiteObjectives','exactPopulation','exactEvaluationBudget','allGenerationsObserved','finalObjectivesRecomputed'))
        rows.append({'Problem':row['problem'],'D':row['D'],'Algorithm':row['algorithm'],'Seed':row['seed'],'IGDplus':float(igd[-1]),'HV':float(hv[-1]),'AlgorithmSeconds':m['algorithmSeconds'],'WallSeconds':m['wallSeconds'],'EarApplied':applied,'EarFallback':fallback,'MeanF':mean_f,'MeanCR':mean_cr,'MeanPLocal':mean_plocal,'OutsideReference':m['finalOutsideReference'],'UniqueObjectives':m['finalUniqueObjectives'],'RunPath':d.relative_to(ROOT).as_posix()})
        proofs.append({'run':d.relative_to(ROOT).as_posix(),'raw_sha256':sha(d/'raw.mat'),'manifest_sha256':sha(path),'initial_matrix_sha256':ih})
        if k%100==0: print(f'NUMERICAL_AUDIT {k}/2080',flush=True)
    out=ROOT/'analysis/results'; out.mkdir(parents=True,exist_ok=True)
    with (out/'verified_runs.csv').open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    report={'status':'PASS','runs':len(rows),'problem_seed_blocks':len(initial_hash),'evaluations':len(rows)*50100,'generations_each':500,'code_manifest_sha256':manifest_hash,'config_sha256':config_hash,'max_objective_recompute_error':max_obj_error,'max_all_generation_HV_error':max_hv_error,'max_checkpoint_IGDplus_error':max_igd_error,'verification_scope':'Independent Python benchmark formulas, vectorized all-generation HV, every 10-generation IGD+, common initialization, source/config/time/budget/bounds and recorded telemetry checks. Coverage inequality checked from telemetry and separate golden/property tests, not an independent replay of every deleted candidate.','computed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'proofs':proofs}
    (out/'numerical_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='proofs'}),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--status',action='store_true'); args=parser.parse_args()
    if args.status: status()
    else: audit()
