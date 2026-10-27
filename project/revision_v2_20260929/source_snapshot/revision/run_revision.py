"""Post-hoc supplementary study; preserves all parent artifacts. CPU only."""
from pathlib import Path
import sys, json, hashlib, time, csv, shutil, argparse, traceback
ROOT=Path(__file__).resolve().parent
BASE=ROOT.parent
sys.path.insert(0,str(BASE))
import bootstrap
import numpy as np, torch
import core, run_model as rm
from networks import JointNet, history_stage

def dump(path,value):
    Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2,allow_nan=False),encoding='utf-8')
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def write_csv(path,rows):
    if not rows:return
    with Path(path).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def load():
    cfg=json.loads((BASE/'config.json').read_text());rm.set_seed(101,4)
    z=np.load(BASE/'preflight/prepared.npz')
    data={k:{v:torch.tensor(z[k+'_'+v]) for v in ['q','v','a','u']} for k in ['train','validation','test']}
    cache=torch.load(BASE/'physics_run/cache.pt',weights_only=True)
    params=torch.load(BASE/'physics_run/best.pt',weights_only=True)
    s=rm.scalers(data,cache)
    return cfg,data,cache,params,s

def geometry(cfg,data,s):
    rows=[]; singular=[]
    for maxlag in [2,8,32]:
        lags=[v for v in cfg['history_lags'] if v<=maxlag]
        mats={k:((d['v'][torch.arange(32,15000)[:,None]-torch.tensor(lags)[None,:]].permute(0,2,1)-s['vmean'][None,:,None])/s['vstd'][None,:,None]).numpy() for k,d in data.items()}
        for j in range(6):
            tr=mats['train'][:,j,:];basis=np.c_[np.ones(len(tr)),tr[:,0]]
            beta=np.linalg.lstsq(basis,tr[:,1:],rcond=None)[0]
            u=tr-tr.mean(0);sv=np.linalg.svd(u,compute_uv=False)
            singular.append(dict(max_lag_ms=maxlag*4,joint=j+1,pc1_fraction=float(sv[0]**2/(sv@sv)),condition=float(sv[0]/sv[-1]),singular_values=sv.tolist()))
            for split in mats:
                x=mats[split][:,j,:];res=x[:,1:]-np.c_[np.ones(len(x)),x[:,0]]@beta
                denom=np.sum((x[:,1:]-tr[:,1:].mean(0))**2)
                rows.append(dict(max_lag_ms=maxlag*4,joint=j+1,split=split,linear_residual_energy_fraction=float(np.sum(res**2)/denom)))
    write_csv(ROOT/'results/history_geometry.csv',rows);dump(ROOT/'results/singular_values.json',singular)

def mathematical_checks(cfg,data,s):
    rows=[]
    for seed in cfg['seeds']:
        wide=JointNet(7);wide.load_state_dict(torch.load(BASE/f'runs/capacity_control_seed{seed}_a/best.pt',weights_only=True))
        slim=JointNet(1);sd=wide.state_dict();sd['w1']=sd['w1'].sum(1,keepdim=True);sd['skip']=sd['skip'].sum(1,keepdim=True);slim.load_state_dict(sd)
        for split,d in data.items():
            x=(d['v']-s['vmean'])/s['vstd']
            with torch.no_grad():err=float((wide(x[:,:,None].repeat(1,1,7))-slim(x[:,:,None])).abs().max())
            rows.append(dict(seed=seed,split=split,max_abs_normalized_output_difference=err,pass_check=err<1e-10))
    rng=np.random.default_rng(1729);w=rng.normal(size=(7,4));eff=w.sum(0)
    minnorm=np.sum((np.tile(eff/7,(7,1)))**2);target=np.sum(eff**2)/7
    x=rng.normal(size=(13,1));y=rng.normal(size=(13,4));g=2*x.T@(x@eff[None,:]-y)/len(x)
    stepwide=(w-.001*g).sum(0);stepslim=eff-.007*g[0]
    checks={'folding':rows,'l2_identity_abs_error':float(abs(minnorm-target)),'sgd_identity_abs_error':float(np.max(abs(stepwide-stepslim))),
            'scope':'Constructed arrays verify algebra only; robot outputs verify trained-network folding. SGD identity excludes Adam and weight decay.'}
    assert all(r['pass_check'] for r in rows)
    assert checks['l2_identity_abs_error']<1e-12 and checks['sgd_identity_abs_error']<1e-12
    dump(ROOT/'results/mathematical_checks.json',checks)

def train_candidates(cfg,data,cache,s):
    records=[];selected=[]
    for model in ['velocity','capacity_control','history']:
        for seed in cfg['seeds']:
            choices=[]
            for lr in [1e-5,1e-4,1e-3]:
                dest=ROOT/'candidates'/f'{model}_{seed}_lr{lr:g}'
                dest.mkdir(parents=True,exist_ok=False)
                c=dict(cfg,nn_lr=lr,nn_steps=10000,patience_steps=2000)
                dump(dest/'config.json',c);rm.set_seed(seed,4)
                net=JointNet(1 if model=='velocity' else 7)
                try:
                    info=rm.train(net,model,data,cache,s,c,dest)
                    row=dict(model=model,seed=seed,learning_rate=lr,path=str(dest.relative_to(ROOT)),**info)
                    dump(dest/'manifest.json',row);records.append(row);choices.append(row)
                except Exception:
                    (dest/'failure.txt').write_text(traceback.format_exc(),encoding='utf-8');raise
            best=min(choices,key=lambda r:r['best_validation_acc_nmse'])
            selected.append(best)
            write_csv(ROOT/'results/training_candidates.csv',records);dump(ROOT/'results/selected.json',selected)
    return selected

def evaluate_selected(selected,cfg,data,params,s):
    for r in selected:
        model=r['model'];seed=r['seed'];dest=ROOT/'evaluations'/f'{model}_{seed}'
        dest.mkdir(parents=True,exist_ok=False)
        net=JointNet(1 if model=='velocity' else 7)
        net.load_state_dict(torch.load(ROOT/r['path']/'best.pt',weights_only=True));net.eval()
        torch.save(s,dest/'scalers.pt');dump(dest/'selection.json',r)
        rm.evaluate(net,model,data,params,s,cfg,dest)
        if model=='history':
            # Same trained H parameters; duplicated CURRENT input, no refitting.
            ab=ROOT/'evaluations'/f'history_removed_{seed}';ab.mkdir(parents=True,exist_ok=False)
            rm.evaluate(net,'capacity_control',data,params,s,cfg,ab)
            dump(ab/'selection.json',dict(r,intervention='all positive lag inputs replaced with current predicted velocity; frozen weights'))

def refine_rollout(net,model,d,params,s,cfg,starts,substeps):
    phy=core.load_physics();idx=torch.tensor(starts);lags=cfg['history_lags'];dt=cfg['dt']
    x=torch.cat([d['q'][idx],d['v'][idx]],1)
    hist=d['v'][idx[:,None]-torch.arange(33)[None,:]]
    out=[]
    def rhs(state,u,c):
        p=phy(state,u,params['dyn'],params['friction'],False,True)
        if torch.linalg.cholesky_ex(p['M'])[1].any():raise ValueError('Nonpositive M in refinement')
        raw=history_stage(hist,state[:,6:],lags,c) if model=='history' else state[:,6:,None].repeat(1,1,7)
        f=(raw-s['vmean'][None,:,None])/s['vstd'][None,:,None]
        tau=net(f)*s['tstd']+s['tmean']
        a=p['x_dot_result'][:,6:]+torch.bmm(p['M_inverse'],tau[:,:,None])[:,:,0]
        return torch.cat([state[:,6:],a],1)
    with torch.no_grad():
        for k in range(cfg['horizon']):
            u=d['u'][idx+k]
            for ss in range(substeps):
                c=ss/substeps;dc=1/substeps;h=dt/substeps
                a=rhs(x,u,c);b=rhs(x+h*a/2,u,c+dc/2);cc=rhs(x+h*b/2,u,c+dc/2);dd=rhs(x+h*cc,u,c+dc)
                x=x+h*(a+2*b+2*cc+dd)/6
                if not torch.isfinite(x).all() or x.abs().max()>1e6:raise ValueError('Refined integration diverged')
            hist=torch.cat([x[:,None,6:],hist[:,:-1,:]],1);out.append(x.clone())
    return torch.stack(out,1).numpy()

def refinement(selected,cfg,data,params,s):
    rows=[]
    for model in ['capacity_control','history']:
        r=next(r for r in selected if r['model']==model and r['seed']==9)
        z=np.load(ROOT/'evaluations'/f'{model}_9/predictions.npz');starts=z['starts'][::12]
        net=JointNet(7);net.load_state_dict(torch.load(ROOT/r['path']/'best.pt',weights_only=True));net.eval()
        pred=refine_rollout(net,model,data['test'],params,s,cfg,starts,2)
        old=z['prediction'][::12];ref=z['reference'][::12]
        drift=core.metric(pred[:,:,:6],old[:,:,:6],s['qstd'].numpy())
        oldmet=core.metric(old[:,:,:6],ref[:,:,:6],s['qstd'].numpy());newmet=core.metric(pred[:,:,:6],ref[:,:,:6],s['qstd'].numpy())
        np.savez_compressed(ROOT/'results'/f'refinement_{model}.npz',prediction=pred,reference=ref,starts=starts)
        rows.append(dict(model=model,seed=9,origins=len(starts),dt_original=.004,dt_refined=.002,prediction_difference_nrmse=drift['nrmse'],original_error=oldmet['nrmse'],refined_error=newmet['nrmse'],relative_error_change=newmet['nrmse']/oldmet['nrmse']-1))
    write_csv(ROOT/'results/integration_refinement.csv',rows)

def summarize(cfg,data,s):
    metrics=[];horizons=[];sensitivity=[];one_step=[]
    for path in sorted((ROOT/'evaluations').iterdir()):
        if not (path/'predictions.npz').exists():continue
        label,seed=path.name.rsplit('_',1);z=np.load(path/'predictions.npz');p=z['prediction'][:,:,:6];ref=z['reference'][:,:,:6];scale=s['qstd'].numpy()
        for regime,mask in [('all',None),('low_speed',z['low_speed_mask']),('reversal',z['reversal_mask'])]:
            m=core.metric(p,ref,scale,mask)
            metrics.append(dict(model=label,seed=int(seed),regime=regime,nrmse=m['nrmse'],rmse_rad=m['rmse_rad'],endpoint_nrmse=m['endpoint_nrmse']))
        for n in [25,75,150]:
            met=core.metric(p[:,:n],ref[:,:n],scale)
            horizons.append(dict(model=label,seed=int(seed),horizon_s=n*.004,nrmse=met['nrmse']))
        for fraction in [.025,.05,.1]:
            th=fraction*np.quantile(abs(data['train']['v'].numpy()),.95,axis=0)
            mask=abs(data['test']['v'].numpy())[z['target_ids']]<=th
            m=core.metric(p,ref,scale,mask)
            sensitivity.append(dict(model=label,seed=int(seed),threshold_fraction=fraction,nrmse=m['nrmse'],pairs=int(mask.sum())))
    write_csv(ROOT/'results/metrics.csv',metrics);write_csv(ROOT/'results/horizons.csv',horizons);write_csv(ROOT/'results/threshold_sensitivity.csv',sensitivity)
    # Descriptive initialization spread, never a CI over physical trajectories.
    rows=[]
    for model in sorted({r['model'] for r in metrics}):
        for regime in ['all','low_speed','reversal']:
            rr=[r for r in metrics if r['model']==model and r['regime']==regime]
            vals=np.array([r['nrmse'] for r in rr]);rows.append(dict(model=model,regime=regime,n=len(rr),mean=float(vals.mean()),sd=float(vals.std(ddof=1))))
    write_csv(ROOT/'results/summary.csv',rows)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--stage',choices=['all','summarize'],default='all');args=parser.parse_args()
    if args.stage=='all':
        (ROOT/'results').mkdir(exist_ok=True)
        start=time.time()
        inputs={str(p.relative_to(BASE)):sha(p) for p in [BASE/'config.json',BASE/'preflight/prepared.npz',BASE/'physics_run/best.pt',BASE/'physics_run/cache.pt',BASE/'core.py',BASE/'networks.py',BASE/'run_model.py']}
        dump(ROOT/'input_manifest.json',{'inputs':inputs,'protocol_sha256':sha(ROOT/'补充实验协议.md'),'script_sha256':sha(__file__),'started_unix':start,'status':'running'})
        cfg,data,cache,params,s=load();geometry(cfg,data,s);mathematical_checks(cfg,data,s)
        selected=train_candidates(cfg,data,cache,s)
        evaluate_selected(selected,cfg,data,params,s);refinement(selected,cfg,data,params,s);summarize(cfg,data,s)
        dump(ROOT/'completion.json',{'status':'complete','elapsed_seconds':time.time()-start,'candidate_trainings':27,'selected_rollouts':9,'history_removal_rollouts':3,'refined_rollouts':2,'all_inputs_unchanged':all(sha(BASE/k)==v for k,v in inputs.items()),'script_sha256':sha(__file__)})
    else:
        cfg,data,cache,params,s=load();summarize(cfg,data,s)

if __name__=='__main__':main()
