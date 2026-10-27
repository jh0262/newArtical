"""Independent audit of saved exploratory outputs; no optimizer is executed."""
import csv
import hashlib
import json
from pathlib import Path
import numpy as np
from scipy.io import loadmat

ROOT=Path(__file__).resolve().parents[1]

def hv_union_rectangles(f):
    """Independent vertical-strip union integration, without Pareto sorting."""
    z=np.column_stack(((f[:,0]-.7)/.8,f[:,1]))
    z=z[np.all(z<1.1,axis=1)]
    if len(z)==0: return 0.
    xs=np.unique(np.r_[z[:,0],1.1]); value=0.
    for left,right in zip(xs[:-1],xs[1:]):
        active=z[z[:,0]<=left,1]
        if len(active): value+=(right-left)*(1.1-active.min())
    return value

def main():
    rows=list(csv.DictReader((ROOT/'pilot_v02/pilot_summary.csv').open(encoding='utf-8-sig')))
    checks=[]
    for row in rows:
        name=row['method']; path=ROOT/'pilot_v02'/f'{name}_seed92102.mat'
        r=loadmat(path,simplify_cells=True)['result']
        X,F,CV=r['X'],r['F'],r['CV']
        assert X.shape==(64,4) and F.shape==(64,2) and CV.shape==(64,)
        assert r['FE']==6464 and int(row['FE'])==6464
        assert np.all((X[:,0]>=1)&(X[:,0]<=19)&(X[:,0]==X[:,0].astype(int)))
        assert np.all(np.isfinite(F)) and np.all(CV>=0)
        h=hv_union_rectangles(F[CV==0]); err=abs(h-float(row['HV']))
        assert err<1e-12 and abs(h-r['trace'][-1,2])<1e-12
        checks.append({'method':name,'FE':int(r['FE']),'HV_independent':h,'HV_error':err,
                       'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    ode=json.loads((ROOT/'verification_v02/independent_ode_report.json').read_text(encoding='utf-8'))
    pre=json.loads((ROOT/'verification_v02/algorithm_preflight.json').read_text(encoding='utf-8'))
    assert ode['status']=='PASS' and pre['status']=='PASS'
    report={'status':'PASS','raw_runs_checked':len(rows),'current_exploratory_FE':6464*len(rows),
            'formal_runs':len(list((ROOT/'formal_v01').glob('*.mat'))),'checks':checks,
            'scope':'raw structure, FE, catalogue index, independent HV, existing verification reports; no physical validation'}
    (ROOT/'verification_v02/package_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__=='__main__': main()
