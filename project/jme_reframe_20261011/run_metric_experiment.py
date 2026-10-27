"""Fixed-factor training-path verification using real training observations only."""
from pathlib import Path
import sys, json, hashlib, time, copy, csv, traceback
R=Path(__file__).resolve().parent; B=R.parent
sys.path.insert(0,str(B/'revision_v2_20260929'))
from run_revision import load,JointNet,dump,write_csv
import run_model as rm
import torch,numpy as np

sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
NAMES=['D','M','N','L','R']; INPUTS={'w1','skip'}

def sizes(n,o):
    pars=list(n.parameters()); states=[v for s in o.state.values() for k,v in s.items() if torch.is_tensor(v) and k!='step']
    return dict(parameters=sum(p.numel() for p in pars),parameter_bytes=sum(p.numel()*p.element_size() for p in pars),adam_moment_elements=sum(p.numel() for p in states),adam_moment_bytes=sum(p.numel()*p.element_size() for p in states))

def prediction(net,x,c,s):
    return c['base_acc']+torch.bmm(c['Minv'],(net(x)*s['tstd']+s['tmean'])[:,:,None])[:,:,0]

def case(data,cache,s,seed,K,gamma,batches,probe,runroot):
    cid=f'k{K}_g{gamma if gamma is not None else "off"}_s{seed}'
    out=runroot/cid;out.mkdir(exist_ok=False)
    rm.set_seed(seed,1); slim=JointNet(1);sd=copy.deepcopy(slim.state_dict());nets={}
    for name in NAMES:
        n=JointNet(K if name=='D' else 1);state=copy.deepcopy(sd)
        if name=='D':
            for k in INPUTS:state[k]=state[k].repeat(1,K,1)/K
        n.load_state_dict(state);nets[name]=n
    opts={}
    for name,n in nets.items():
        if name=='D':opts[name]=torch.optim.Adam(n.parameters(),lr=1e-4,weight_decay=1e-5)
        else:opts[name]=torch.optim.Adam([dict(params=[n.w1,n.skip],lr=1e-4*(1 if name=='L' else K),weight_decay=1e-5/(1 if name=='R' else K)),dict(params=[p for k,p in n.named_parameters() if k not in INPUTS],lr=1e-4,weight_decay=1e-5)])
    x=((data['v']-s['vmean'])/s['vstd'])[:,:,None]
    rows=[];checks=[];clips={n:0 for n in NAMES}; t0=time.perf_counter()
    with torch.no_grad():initial=max(float((nets[n](x[probe])-nets['D'](x[probe].repeat(1,1,K))).abs().max()) for n in NAMES[1:])
    assert initial<1e-10
    for step,idx in enumerate(batches,1):
        row=dict(case=cid,seed=seed,K=K,gamma='off' if gamma is None else gamma,step=step)
        for name,n in nets.items():
            opt=opts[name];opt.zero_grad();feat=x[idx].repeat(1,1,K) if name=='D' else x[idx]
            pred=prediction(n,feat,{k:cache[k][idx] for k in ['base_acc','Minv']},s)
            loss=((pred-data['a'][idx])/s['astd']).square().mean()
            if not torch.isfinite(loss):raise RuntimeError(f'Nonfinite {cid}/{name}/{step}')
            loss.backward()
            a=sum(p.grad.square().sum() for k,p in n.named_parameters() if k in INPUTS)
            b=sum(p.grad.square().sum() for k,p in n.named_parameters() if k not in INPUTS)
            weight=1 if name in ['D','N'] else K
            norm=torch.sqrt(weight*a+b)
            fac=torch.tensor(1.) if gamma is None else torch.clamp(gamma/(norm+1e-6),max=1.)
            if name=='M':
                ordinary=torch.sqrt(a+b);rho=a/(a+b)
                analytic=ordinary*torch.sqrt(1+(K-1)*rho)
                c0=1. if gamma is None else float(torch.clamp(gamma/(ordinary+1e-6),max=1.))
                row.update(input_grad_energy=float(a),other_grad_energy=float(b),input_fraction=float(rho),ordinary_norm=float(ordinary),matched_norm=float(norm),norm_identity_relative_error=float((norm-analytic).abs()/torch.clamp(norm,min=1e-30)),ordinary_over_matched_clip=c0/float(fac))
            for p in n.parameters():p.grad.mul_(fac)
            opt.step();clips[name]+=int(float(fac)<1)
            row.update({name+'_loss':float(loss.detach()),name+'_unclipped_norm':float(norm),name+'_clip_factor':float(fac)})
        with torch.no_grad():
            for name in NAMES[1:]:
                others=dict(nets[name].named_parameters()); pd=md=vd=0.
                for k,w in nets['D'].named_parameters():
                    p=others[k];inp=k in INPUTS;fold=w.sum(1,keepdim=True) if inp else w
                    pd=max(pd,float((fold-p).abs().max()))
                    for st in ['exp_avg','exp_avg_sq']:
                        sw=opts['D'].state[w][st];sv=opts[name].state[p][st]
                        err=float(((sw[:,:1] if inp else sw)-sv).abs().max())
                        if st=='exp_avg':md=max(md,err)
                        else:vd=max(vd,err)
                row[name+'_parameter_diff']=pd;row[name+'_m_diff']=md;row[name+'_v_diff']=vd
            if step%10==0 or step==1:
                reference=nets['D'](x[probe].repeat(1,1,K))
                for name in NAMES[1:]:
                    diff=float((nets[name](x[probe])-reference).abs().max())
                    checks.append(dict(case=cid,seed=seed,K=K,gamma='off' if gamma is None else gamma,step=step,method=name,max_probe_output_difference=diff,within_tolerance=diff<=1e-9))
        rows.append(row)
    storage={}
    for name,n in nets.items():
        torch.save(n.state_dict(),out/(name+'_final.pt'));torch.save(opts[name].state_dict(),out/(name+'_adam.pt'));storage[name]=sizes(n,opts[name])
    write_csv(out/'per_step.csv',rows);write_csv(out/'probe_checks.csv',checks)
    summary=dict(case=cid,seed=seed,K=K,gamma='off' if gamma is None else gamma,steps=200,optimizer_updates=1000,initial_output_difference=initial,clip_counts=clips,storage=storage,seconds=time.perf_counter()-t0,
       methods={n:dict(max_probe_output_difference=max(v['max_probe_output_difference'] for v in checks if v['method']==n),failed_probes=sum(not v['within_tolerance'] for v in checks if v['method']==n),max_parameter_difference=max(v[n+'_parameter_diff'] for v in rows)) for n in NAMES[1:]},max_norm_identity_relative_error=max(v['norm_identity_relative_error'] for v in rows),max_clip_ratio=max(v['ordinary_over_matched_clip'] for v in rows),min_clip_ratio=min(v['ordinary_over_matched_clip'] for v in rows))
    dump(out/'summary.json',summary);return summary

def main():
    out=R/'metric_experiment';out.mkdir(exist_ok=False)
    inputs=[Path(__file__),R/'研究主线与实验协议.md',B/'preflight/prepared.npz',B/'physics_run/cache.pt',B/'physics_run/best.pt',B/'networks.py',B/'run_model.py',B/'core.py',B/'bootstrap.py',B/'revision_v2_20260929/run_revision.py']
    guard={str(p):sha(p) for p in inputs};dump(out/'input_hashes.json',guard)
    _,data,cache,_,s=load();torch.set_num_threads(1); t0=time.time()
    probe=torch.linspace(32,14999,1024).long();np.save(out/'probe_indices.npy',probe.numpy());results=[]
    for seed in [9,19,29]:
        gen=torch.Generator().manual_seed(73000+seed);batches=torch.randint(32,15000,(200,256),generator=gen);np.save(out/f'batches_seed{seed}.npy',batches.numpy())
        for K in [1,3,7]:
            for gamma in [1,100,None]:
                result=case(data['train'],cache['train'],s,seed,K,gamma,batches,probe,out);results.append(result)
                dump(out/'progress.json',dict(completed=len(results),total=27,last_case=result['case'],seconds=time.time()-t0));print(result['case'],{n:result['methods'][n]['max_probe_output_difference'] for n in NAMES[1:]},flush=True)
    for p,h in guard.items():assert sha(p)==h,p
    dump(out/'summary.json',results)
    output_hashes={str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file()}
    dump(out/'completion.json',dict(status='complete',cases=len(results),optimizer_updates=sum(v['optimizer_updates'] for v in results),seconds=time.time()-t0,python=sys.version,torch=torch.__version__,numpy=np.__version__,inputs_unchanged=True,outputs=output_hashes))

if __name__=='__main__':
    try:main()
    except Exception:
        (R/'experiment_failure.txt').write_text(traceback.format_exc(),encoding='utf-8');raise
