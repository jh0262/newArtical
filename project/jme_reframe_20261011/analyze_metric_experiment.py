"""Independently aggregate saved per-step/probe CSV and actual tensor storage."""
from pathlib import Path
import sys,json,csv,hashlib,math
R=Path(__file__).resolve().parent;B=R.parent;O=R/'metric_experiment';A=R/'analysis';A.mkdir(exist_ok=True)
sys.path.insert(0,str(B));import bootstrap
import torch,numpy as np
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
read=lambda p:json.loads(Path(p).read_text(encoding='utf-8'))
csvread=lambda p:list(csv.DictReader(Path(p).open(encoding='utf-8-sig',newline='')))
def write(p,rows):
    with Path(p).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

completion=read(O/'completion.json');assert completion['status']=='complete' and completion['cases']==27
for p,h in read(O/'input_hashes.json').items():assert sha(p)==h,p
for p,h in completion['outputs'].items():assert sha(O/p)==h,p
cases=read(O/'summary.json');flat=[];max_num_diff=0.;norm_res=0.;count=0
for c in cases:
    steps=csvread(O/c['case']/'per_step.csv');probes=csvread(O/c['case']/'probe_checks.csv')
    assert [int(v['step']) for v in steps]==list(range(1,201))
    assert len(probes)==84
    for r in steps:
        a,b=float(r['input_grad_energy']),float(r['other_grad_energy']);K=int(r['K']);G=math.sqrt(K*a+b);G0=math.sqrt(a+b)
        norm_res=max(norm_res,abs(G-float(r['matched_norm']))/max(G,1e-30))
        gamma=None if r['gamma']=='off' else float(r['gamma'])
        cm=1 if gamma is None else min(1,gamma/(G+1e-6));c0=1 if gamma is None else min(1,gamma/(G0+1e-6))
        assert abs(c0/cm-float(r['ordinary_over_matched_clip']))<1e-12
        assert 1-1e-12<=c0/cm<=math.sqrt(K)+1e-12
        count+=1
    for name in ['M','N','L','R']:
        p=[v for v in probes if v['method']==name];mx=max(float(v['max_probe_output_difference']) for v in p)
        failed=sum(float(v['max_probe_output_difference'])>1e-9 for v in p)
        assert failed==c['methods'][name]['failed_probes']
        max_num_diff=max(max_num_diff,abs(mx-c['methods'][name]['max_probe_output_difference']))
        assert max_num_diff<1e-12
        flat.append(dict(case=c['case'],seed=c['seed'],K=c['K'],gamma=c['gamma'],method=name,max_probe_output_difference=mx,final_probe_output_difference=float(p[-1]['max_probe_output_difference']),failed_probes=failed,reference_clipped_steps=c['clip_counts']['D']))
        if name=='M' or c['K']==1 or name=='N' and c['gamma']=='off':assert failed==0,(c['case'],name)
    for name in ['D','M','N','L','R']:
        state=torch.load(O/c['case']/(name+'_final.pt'),weights_only=True)
        opt=torch.load(O/c['case']/(name+'_adam.pt'),weights_only=True)
        pars=list(state.values());mom=[v for st in opt['state'].values() for k,v in st.items() if torch.is_tensor(v) and k!='step']
        actual=dict(parameters=sum(v.numel() for v in pars),parameter_bytes=sum(v.numel()*v.element_size() for v in pars),adam_moment_elements=sum(v.numel() for v in mom),adam_moment_bytes=sum(v.numel()*v.element_size() for v in mom))
        assert actual==c['storage'][name]
write(A/'all_case_effects.csv',flat)
groups=[]
for K in [1,3,7]:
    for g in [1,100,'off']:
        picked=[v for v in flat if v['K']==K and v['gamma']==g]
        r=dict(K=K,gamma=g)
        for n in ['M','N','L','R']:r[n+'_max_difference']=max(v['max_probe_output_difference'] for v in picked if v['method']==n)
        r['clipped_steps_min']=min(v['reference_clipped_steps'] for v in picked);r['clipped_steps_max']=max(v['reference_clipped_steps'] for v in picked);groups.append(r)
write(A/'mechanism_groups.csv',groups)
storage=[]
for K in [1,3,7]:
    c=next(v for v in cases if v['K']==K);d,m=c['storage']['D'],c['storage']['M']
    saved=d['parameter_bytes']+d['adam_moment_bytes']-m['parameter_bytes']-m['adam_moment_bytes']
    storage.append(dict(K=K,wide_parameters=d['parameters'],compact_parameters=m['parameters'],parameters_removed=d['parameters']-m['parameters'],parameter_reduction_percent=100*(d['parameters']-m['parameters'])/d['parameters'],wide_weight_and_moments_bytes=d['parameter_bytes']+d['adam_moment_bytes'],compact_weight_and_moments_bytes=m['parameter_bytes']+m['adam_moment_bytes'],bytes_saved=saved))
    assert d['parameters']==62412+606*(K-1) and m['parameters']==62412
    assert saved==24*606*(K-1)
write(A/'storage.csv',storage)
old=[]
for seed in [9,19,29]:
    for name in ['Ds','Vm']:
        p=B/f'jme_review_20260930_round5/training/seed{seed}'
        state=torch.load(p/f'{name}_final.pt',weights_only=True);opt=torch.load(p/f'{name}_optimizer_final.pt',weights_only=True)
        wbytes=sum(v.numel()*v.element_size() for v in state.values());moment=sum(v.numel()*v.element_size() for st in opt['state'].values() for k,v in st.items() if torch.is_tensor(v) and k!='step')
        old.append(dict(seed=seed,model=name,weight_bytes=wbytes,moment_bytes=moment,checkpoint_sha256=sha(p/f'{name}_final.pt'),optimizer_sha256=sha(p/f'{name}_optimizer_final.pt')))
        assert wbytes+moment==(66048 if name=='Ds' else 62412)*24
write(A/'previous_full_training_storage.csv',old)
audit=dict(status='pass',cases=27,updates=27000,raw_steps=count,probe_rows=27*84,stored_models_checked=135,summary_max_abs_error=max_num_diff,norm_max_relative_error=norm_res,all_matched_probes_pass=True,all_degenerate_negative_controls_pass=True,output_hashes_verified=len(completion['outputs']),storage_scope='weights plus Adam first and second moments; excludes gradients, activations, step scalars, Python/process overhead, archive overhead; no timing speedup claim',sources_unchanged=True)
(A/'independent_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(audit,ensure_ascii=False));print(groups);print(storage)
