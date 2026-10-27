import bootstrap
import os,sys,json,time,random,hashlib,platform,traceback,shutil
from pathlib import Path
from datetime import datetime
import numpy as np,torch
import core
ROOT=Path(__file__).resolve().parent
def now(): return datetime.now().astimezone().isoformat()
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def run():
    cfg=json.loads((ROOT/'config.json').read_text()); dest=ROOT/'physics_run'; dest.mkdir(exist_ok=False)
    source=dest/'source';source.mkdir()
    for name in ['run_physics.py','core.py','bootstrap.py','config.json','实验协议.md']:
        shutil.copy2(ROOT/name,source/name)
    start=now(); manifest={'started_at':start,'config_sha256':sha(ROOT/'config.json'),'code_sha256':{p.name:sha(p) for p in [Path(__file__),ROOT/'core.py',ROOT/'bootstrap.py']},'status':'running'}
    (dest/'manifest.json').write_text(json.dumps(manifest,indent=2))
    torch.set_default_dtype(torch.float64); torch.set_num_threads(cfg['threads']); torch.use_deterministic_algorithms(True)
    random.seed(101); np.random.seed(101); torch.manual_seed(101)
    z=np.load(ROOT/'preflight/prepared.npz'); names=['train','validation','test']
    data={k:{v:torch.tensor(z[k+'_'+v]) for v in ['q','v','a','u']} for k in names}
    phy=core.load_physics(); dyn=torch.nn.Parameter(torch.zeros(66)); f=torch.nn.Parameter(torch.zeros(30))
    scale=torch.tensor(core.fit_scales(z['train_a'])[1]); opt=torch.optim.Adam([dyn,f],lr=cfg['physical_lr'])
    best=float('inf'); best_state=None; logs=[]; t=time.perf_counter()
    for step in range(1,cfg['physical_steps']+1):
        ids=torch.randint(32,15000,(cfg['batch_size'],)); d=data['train']
        x=torch.cat([d['q'][ids],d['v'][ids]],dim=1)
        a=phy(x,d['u'][ids],dyn,f,True,False)[:,6:]
        loss=((a-d['a'][ids])/scale).square().mean()
        if not torch.isfinite(loss): raise RuntimeError('Nonfinite physical loss')
        opt.zero_grad();loss.backward();torch.nn.utils.clip_grad_norm_([dyn,f],100.);opt.step()
        with torch.no_grad():
            dyn.clamp_(-200,200);f.clamp_(-400,400);f[:12].clamp_(-99.9,400)
        if step%cfg['validation_interval']==0 or step==1:
            with torch.no_grad():
                d=data['validation']; x=torch.cat([d['q'],d['v']],dim=1)
                va=phy(x,d['u'],dyn,f,True,False)[:,6:]; vl=float(((va-d['a'])/scale).square().mean())
            logs.append({'step':step,'batch_loss':float(loss.detach()),'validation_acc_nmse':vl,'elapsed_s':time.perf_counter()-t})
            if vl<best:
                best=vl; best_state={'dyn':dyn.detach().clone(),'friction':f.detach().clone(),'step':step,'validation_acc_nmse':vl}
                torch.save(best_state,dest/'best.pt')
            print('PHYS',step,'validation',round(vl,6),'elapsed',round(time.perf_counter()-t),flush=True)
            (dest/'training_log.json').write_text(json.dumps(logs,indent=2))
    dyn=best_state['dyn']; f=best_state['friction']; cache={}; guards={}
    with torch.no_grad():
        for name,d in data.items():
            x=torch.cat([d['q'],d['v']],dim=1)
            p=phy(x,d['u'],dyn,f,False,True)
            eig=torch.linalg.eigvalsh(p['M']); guards[name]={'min_eigenvalue':float(eig.min()),'max_condition':float((eig[:,-1]/eig[:,0]).max())}
            if not torch.isfinite(eig).all() or eig.min()<=0: raise RuntimeError('Invalid inertia matrix on '+name)
            cache[name]={'base_acc':p['x_dot_result'][:,6:].detach(),'Minv':p['M_inverse'].detach(),'M':p['M'].detach()}
    torch.save(cache,dest/'cache.pt')
    manifest.update(ended_at=now(),status='budget_exhausted',artifact_complete=True,convergence_verified=False,best_step=best_state['step'],validation_acc_nmse=best,guards=guards,elapsed_seconds=time.perf_counter()-t)
    (dest/'manifest.json').write_text(json.dumps(manifest,indent=2)); print('PHYSICS_ARTIFACTS_READY',flush=True)

if __name__=='__main__':
    try: run()
    except Exception:
        p=ROOT/'physics_run';p.mkdir(exist_ok=True);(p/'failure.txt').write_text(traceback.format_exc());raise
