"""Independent sign enumeration, log audit and replay consistency checks."""
from pathlib import Path
import csv,hashlib,itertools,json,re
import numpy as np
from scipy.stats import rankdata

ROOT=Path(__file__).resolve().parent;OUT=ROOT/'analysis'
def read(name):
    with (OUT/name).open(encoding='utf-8-sig') as f:return list(csv.DictReader(f))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    metrics=read('run_metrics.csv');lookup={(float(r['cycle_limit_s']),r['method'],int(r['seed'])):float(r['HV']) for r in metrics}
    maximum=0.
    for r in read('paired_comparisons.csv'):
        c=float(r['cycle_limit_s']);a,b=r['contrast'].split('-')
        d=np.round([lookup[(c,a,s)]-lookup[(c,b,s)] for s in range(104101,104111)],12);d=d[d!=0]
        if len(d):
            ranks=rankdata(abs(d));actual=min(ranks[d>0].sum(),ranks[d<0].sum())
            sums=np.array([np.dot(sign,ranks) for sign in itertools.product([0,1],repeat=len(d))])
            p=min(1.,2*np.mean(sums<=actual))
        else:p=1.
        err=abs(p-float(r['p_raw']));maximum=max(maximum,err);assert err<1e-15
    for r in read('raw_hashes.csv'):assert sha(ROOT/r['file'])==r['sha256']
    log=(ROOT/'provenance/execution.log').read_text(encoding='utf-8')
    pat=r'RUN (\d+)/120 cycle=([\d.]+) seed=(\d+) method=(D\d) FE=(\d+) HV=([\d.e+-]+)'
    records=re.findall(pat,log);assert len(records)==120
    for i,c,s,m,fe,h in records:
        assert int(fe)==32064 and abs(lookup[(float(c),m,int(s))]-float(h))<1e-11
    complete=re.search(r'COMPLETE runs=(\d+) FE=(\d+) wall=([\d.]+)',log);assert complete
    assert int(complete[1])==120 and int(complete[2])==3847680 and float(complete[3])<1200
    retention=read('retention_summary.csv');assert len(retention)==120
    maxidentity=0.;rowschecked=0
    for r in retention:
        c=float(r['cycle_limit_s']);m=r['method'];s=int(r['seed']);fin=float(r['final_HV']);hh=float(r['history_HV']);common=float(r['common_PCD64_HV'])
        assert abs(lookup[(c,m,s)]-fin)<1e-12 and hh>=fin-1e-12 and hh>=common-1e-12
        replay=np.genfromtxt(OUT/f'cycle{c:.1f}_{m}_seed{s}_replay.csv',delimiter=',',names=True)
        assert len(replay)==500 and np.all(np.diff(replay['history_HV'])>=-1e-12)
        err=float(np.max(abs(replay['selected_HV']-replay['parent_HV']-replay['generation_gain']+replay['selection_loss'])));maxidentity=max(maxidentity,err);assert err<1e-12
        assert np.all(replay['history_HV']>=replay['union_HV']-1e-12)
        assert abs(np.sum(replay['generation_gain'])-float(r['sum_generation_gain']))<1e-11
        assert abs(np.sum(replay['selection_loss'])-float(r['sum_selection_loss']))<1e-11
        rowschecked+=500
    summary=[]
    for c in [2.5,3.5]:
        for m in [f'D{i}' for i in range(6)]:
            rr=[r for r in retention if float(r['cycle_limit_s'])==c and r['method']==m]
            a=np.array([[float(r[k]) for k in ['final_HV','history_HV','common_PCD64_HV','mean_PCD_minus_CD_same_pool','mean_EAR_minus_PCD_same_pool']] for r in rr])
            summary.append(dict(cycle_limit_s=c,method=m,median_history_HV=float(np.median(a[:,1])),median_history_minus_final=float(np.median(a[:,1]-a[:,0])),max_history_minus_final=float(np.max(a[:,1]-a[:,0])),median_common_PCD64_minus_final=float(np.median(a[:,2]-a[:,0])),median_run_mean_PCD_minus_CD=float(np.median(a[:,3])),median_run_mean_EAR_minus_PCD=float(np.median(a[:,4]))))
    with (OUT/'retention_by_method.csv').open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=list(summary[0]));w.writeheader();w.writerows(summary)
    a=json.loads((OUT/'analysis_audit.json').read_text());b=json.loads((OUT/'replay_audit.json').read_text());assert a['status']==b['status']=='PASS'
    audit=dict(status='PASS',date='2026-10-11',runs=120,FE=3847680,batch_wall_seconds=float(complete[3]),log_records_checked=len(records),independently_enumerated_tests=10,max_p_difference=maximum,identity_rows_checked=rowschecked,max_identity_error=maxidentity,new_posthoc_model_evaluations=0,source_sha256=sha(Path(__file__)),scope='Ledger, saved-selection replay, sign-enumeration and arithmetic consistency. No physical validation, equivalence proof or novelty assessment.')
    (OUT/'delivery_audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8');print(json.dumps(audit,indent=2))
    for r in summary:print(json.dumps(r))
    for c in [2.5,3.5]:
        rr=[r for r in retention if float(r['cycle_limit_s'])==c];r=min(rr,key=lambda r:float(r['final_HV']));print('worst case',json.dumps(r))

if __name__=='__main__':main()
