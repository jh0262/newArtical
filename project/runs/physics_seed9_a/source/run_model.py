import bootstrap
import os,sys,json,time,random,hashlib,platform,traceback,shutil,argparse
from pathlib import Path
from datetime import datetime
import numpy as np,torch
import core
from networks import JointNet,PlainNet,history_stage,rollout
ROOT=Path(__file__).resolve().parent
def now():return datetime.now().astimezone().isoformat()
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def set_seed(seed,threads):
    random.seed(seed); np.random.seed(seed);torch.manual_seed(seed)
    torch.set_num_threads(threads);torch.set_default_dtype(torch.float64)
    torch.use_deterministic_algorithms(True)

def scalers(data,cache):
    train=data['train']; ids=torch.arange(32,len(train['q']))
    vmean,vstd=core.fit_scales(train['v'].numpy())
    qm,qs=core.fit_scales(train['q'].numpy())
    am,astd=core.fit_scales(train['a'].numpy())
    feat=torch.cat([train['q'],train['v'],train['u']],1)
    fm,fs=core.fit_scales(feat.numpy())
    residual=torch.bmm(cache['train']['M'],(train['a']-cache['train']['base_acc'])[:,:,None])[:,:,0]
    tm,ts=core.fit_scales(residual[ids].numpy())
    return {k:torch.tensor(v) for k,v in dict(vmean=vmean,vstd=vstd,qmean=qm,qstd=qs,amean=am,astd=astd,fmean=fm,fstd=fs,tmean=tm,tstd=ts).items()}

def features(d,ids,model,cfg,s):
    if model=='ann_only':
        return (torch.cat([d['q'][ids],d['v'][ids],d['u'][ids]],1)-s['fmean'])/s['fstd']
    if model=='history':
        raw=d['v'][ids[:,None]-torch.tensor(cfg['history_lags'])[None,:]].permute(0,2,1)
    else:
        raw=d['v'][ids,:,None]
        if model=='capacity_control':raw=raw.repeat(1,1,len(cfg['history_lags']))
    return (raw-s['vmean'][None,:,None])/s['vstd'][None,:,None]

def acceleration(net,feat,base,Minv,model,s):
    y=net(feat)
    if model=='ann_only':return y*s['astd']+s['amean']
    tau=y*s['tstd']+s['tmean']
    return base+torch.bmm(Minv,tau[:,:,None])[:,:,0]

def train(net,model,data,cache,s,cfg,dest):
    opt=torch.optim.Adam(net.parameters(),lr=cfg['nn_lr'],weight_decay=cfg['nn_weight_decay'])
    best=float('inf');best_step=0; logs=[];t=time.perf_counter()
    valid_ids=torch.arange(32,15000)
    vf=features(data['validation'],valid_ids,model,cfg,s)
    termination='budget_exhausted'
    for step in range(1,cfg['nn_steps']+1):
        ids=torch.randint(32,15000,(cfg['batch_size'],));d=data['train']; c=cache['train']
        pred=acceleration(net,features(d,ids,model,cfg,s),c['base_acc'][ids],c['Minv'][ids],model,s)
        loss=((pred-d['a'][ids])/s['astd']).square().mean()
        if not torch.isfinite(loss):raise RuntimeError('Nonfinite network loss')
        opt.zero_grad();loss.backward();torch.nn.utils.clip_grad_norm_(net.parameters(),100.);opt.step()
        if step%cfg['validation_interval']==0 or step==1:
            with torch.no_grad():
                vals=[]
                for sub in range(0,len(valid_ids),1024):
                    ii=valid_ids[sub:sub+1024];c=cache['validation']
                    pa=acceleration(net,vf[sub:sub+1024],c['base_acc'][ii],c['Minv'][ii],model,s)
                    vals.append(((pa-data['validation']['a'][ii])/s['astd']).square())
                vl=float(torch.cat(vals).mean())
            logs.append({'step':step,'batch_loss':float(loss.detach()),'validation_acc_nmse':vl,'elapsed_seconds':time.perf_counter()-t})
            if vl<best-1e-10:
                best=vl;best_step=step;torch.save(net.state_dict(),dest/'best.pt')
            print(model,'step',step,'validation',round(vl,7),'elapsed',round(time.perf_counter()-t),flush=True)
            (dest/'training_log.json').write_text(json.dumps(logs,indent=2))
            if step-best_step>=cfg['patience_steps']:
                termination='validation_early_stop';break
    net.load_state_dict(torch.load(dest/'best.pt',weights_only=True))
    return dict(termination=termination,updates=step,best_step=best_step,best_validation_acc_nmse=best,training_seconds=time.perf_counter()-t)

def regime_masks(v,threshold,cfg):
    n,j=v.shape; low=np.abs(v)<=threshold; rev=np.zeros((n,j),dtype=bool); events=[]
    for a in range(j):
        signs=np.where(v[:,a]>threshold[a],1,np.where(v[:,a]<-threshold[a],-1,0))
        last=None
        for t in np.flatnonzero(signs):
            if last is not None and signs[t]!=signs[last] and t-last<=cfg['reversal_max_gap_samples']:
                c=last+int(np.argmin(np.abs(v[last:t+1,a])))
                half=cfg['reversal_half_window_samples'];rev[max(0,c-half):min(n,c+half+1),a]=True
                events.append({'joint':a+1,'index':c,'time_seconds':c*cfg['dt']})
            last=t
    return low,rev,events

def evaluate(net,model,data,params,s,cfg,dest):
    phy=core.load_physics();d=data['test'];lags=cfg['history_lags']
    starts=np.arange(max(lags),15000-cfg['horizon'],cfg['origin_stride'])
    idx=torch.tensor(starts)
    x=torch.cat([d['q'][idx],d['v'][idx]],1)
    hist=d['v'][idx[:,None]-torch.arange(max(lags)+1)[None,:]]
    us=d['u'][idx[:,None]+torch.arange(cfg['horizon'])[None,:]]
    def rhs(x,u,hist,c):
        if model=='ann_only':
            feat=(torch.cat([x[:,:6],x[:,6:],u],1)-s['fmean'])/s['fstd']
            a=net(feat)*s['astd']+s['amean']
            return torch.cat([x[:,6:],a],1)
        p=phy(x,u,params['dyn'],params['friction'],model=='physics',True)
        if torch.linalg.cholesky_ex(p['M'])[1].any():raise RuntimeError('Nonpositive inertia matrix during rollout')
        if model=='physics':return p['x_dot_result']
        if model=='history':raw=history_stage(hist,x[:,6:],lags,c)
        else:
            raw=x[:,6:,None]
            if model=='capacity_control':raw=raw.repeat(1,1,len(lags))
        feat=(raw-s['vmean'][None,:,None])/s['vstd'][None,:,None]
        tau=net(feat)*s['tstd']+s['tmean']
        a=p['x_dot_result'][:,6:]+torch.bmm(p['M_inverse'],tau[:,:,None])[:,:,0]
        return torch.cat([x[:,6:],a],1)
    with torch.no_grad():
        chunks=[]
        for k in range(0,len(starts),128):
            chunks.append(rollout(rhs,x[k:k+128],us[k:k+128],hist[k:k+128],lags,cfg['dt']))
        pred=torch.cat(chunks).numpy()
    target_ids=starts[:,None]+np.arange(1,cfg['horizon']+1)[None,:]
    ref=np.concatenate([d['q'].numpy(),d['v'].numpy()],axis=1)[target_ids]
    threshold=cfg['low_speed_fraction_of_train_p95']*np.quantile(np.abs(data['train']['v'].numpy()),.95,axis=0)
    low,rev,events=regime_masks(d['v'].numpy(),threshold,cfg)
    masks={'all':np.ones(pred[:,:,:6].shape,dtype=bool),'low_speed':low[target_ids],'reversal':rev[target_ids]}
    result={key:core.metric(pred[:,:,:6],ref[:,:,:6],s['qstd'].numpy(),mask) for key,mask in masks.items()}
    teststd=d['q'].numpy().std(0,ddof=1)
    result['legacy_endpoint_nmse_evaluation_scale']=float((((pred[:,-1,:6]-ref[:,-1,:6])/teststd)**2).mean())
    result['coverage']={'origins':len(starts),'low_speed_threshold_rad_s':threshold.tolist(),'events':events,'low_timestamp_counts':low.sum(0).tolist(),'reversal_timestamp_counts':rev.sum(0).tolist()}
    np.savez_compressed(dest/'predictions.npz',prediction=pred,reference=ref,starts=starts,target_ids=target_ids,low_speed_mask=masks['low_speed'],reversal_mask=masks['reversal'])
    (dest/'metrics.json').write_text(json.dumps(result,indent=2,allow_nan=False))
    print('TEST',model,{k:result[k]['nrmse'] for k in masks},flush=True)
    return result

def run(model,seed,attempt):
    cfg=json.loads((ROOT/'config.json').read_text());dest=ROOT/'runs'/f'{model}_seed{seed}_{attempt}';dest.mkdir(parents=True,exist_ok=False)
    started=now();start=time.perf_counter();set_seed(seed,cfg['threads'])
    src=dest/'source';src.mkdir()
    files=['run_model.py','core.py','networks.py','bootstrap.py','config.json']
    for file in files:shutil.copy2(ROOT/file,src/file)
    manifest=dict(model=model,seed=seed,attempt=attempt,started_at=started,status='running',config_sha256=sha(ROOT/'config.json'),code_sha256={f:sha(ROOT/f) for f in files},input_sha256=sha(ROOT/'preflight/prepared.npz'),physics_sha256=sha(ROOT/'physics_run/best.pt'),python=platform.python_version(),torch=torch.__version__,numpy=np.__version__,threads=cfg['threads'],dtype='float64',pythonhashseed=os.environ.get('PYTHONHASHSEED'),matrix_row=f'{model}:{seed}')
    (dest/'manifest.json').write_text(json.dumps(manifest,indent=2));shutil.copy2(ROOT/'实验协议.md',dest/'protocol.md')
    try:
        z=np.load(ROOT/'preflight/prepared.npz');data={k:{v:torch.tensor(z[k+'_'+v]) for v in ['q','v','a','u']} for k in ['train','validation','test']}
        cache=torch.load(ROOT/'physics_run/cache.pt',weights_only=True);params=torch.load(ROOT/'physics_run/best.pt',weights_only=True)
        s=scalers(data,cache);torch.save(s,dest/'scalers.pt')
        net=None
        if model!='physics':
            net=PlainNet(cfg['ann_hidden']) if model=='ann_only' else JointNet(1 if model=='velocity' else len(cfg['history_lags']),cfg['joint_hidden'])
            manifest['parameter_count']=sum(x.numel() for x in net.parameters());info=train(net,model,data,cache,s,cfg,dest);manifest.update(info);net.eval()
        else:manifest['termination']='fixed_shared_physics';manifest['parameter_count']=0
        evaluate(net,model,data,params,s,cfg,dest)
        manifest.update(status=manifest['termination'],artifact_complete=True,convergence_verified=False,ended_at=now(),elapsed_seconds=time.perf_counter()-start,prediction_sha256=sha(dest/'predictions.npz'),metrics_sha256=sha(dest/'metrics.json'))
    except Exception:
        (dest/'failure.txt').write_text(traceback.format_exc());manifest.update(status='failed',artifact_complete=False,ended_at=now(),elapsed_seconds=time.perf_counter()-start)
        raise
    finally:(dest/'manifest.json').write_text(json.dumps(manifest,indent=2))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--model',required=True);p.add_argument('--seed',type=int,default=9);p.add_argument('--attempt',default='a');args=p.parse_args();run(args.model,args.seed,args.attempt)
