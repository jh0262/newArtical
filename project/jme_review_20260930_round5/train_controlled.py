"""Fixed-protocol post-hoc paired training. Never overwrites prior candidates."""
from pathlib import Path
import sys,json,time,hashlib,argparse,copy,traceback
R=Path(__file__).resolve().parent; B=R.parent
sys.path.insert(0,str(B/'revision_v2_20260929'))
from run_revision import load,JointNet,dump,write_csv
import run_model as rm
import torch,numpy as np

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
NAMES=['Ds','Vm','Cdelta','Hdelta']
def make(seed):
 rm.set_seed(seed,1);v=JointNet(1);sd=copy.deepcopy(v.state_dict());nets={'Vm':v}
 for name in ['Ds','Cdelta','Hdelta']:
  n=JointNet(7);wd=copy.deepcopy(sd)
  for k in ['w1','skip']:
   wd[k]=sd[k].repeat(1,7,1)/7 if name=='Ds' else torch.cat([sd[k],torch.zeros_like(sd[k]).repeat(1,6,1)],1)
  n.load_state_dict(wd);nets[name]=n
 return {name:nets[name] for name in NAMES}
def feats(d,s):
 ids=torch.arange(32,len(d['v']));x=(d['v'][ids]-s['vmean'])/s['vstd']
 h=d['v'][ids[:,None]-torch.tensor([0,1,2,4,8,16,32])[None,:]].permute(0,2,1)
 delta=(h-h[:,:,:1])/s['vstd'][None,:,None]
 return {'Vm':x[:,:,None],'Ds':x[:,:,None].repeat(1,1,7),'Cdelta':torch.cat([x[:,:,None],torch.zeros_like(delta[:,:,1:])],2),'Hdelta':torch.cat([x[:,:,None],delta[:,:,1:]],2)}
def prediction(n,x,c,s):
 return c['base_acc']+torch.bmm(c['Minv'],(n(x)*s['tstd']+s['tmean'])[:,:,None])[:,:,0]
def infer(n,x,c,s):
 with torch.no_grad():return torch.cat([prediction(n,x[i:i+1024],{k:v[i:i+1024] for k,v in c.items()},s) for i in range(0,len(x),1024)])
def pair_stats(nets,opts,features,cache,s):
 r={};passed=True
 with torch.no_grad():
  for split in ['train','validation']:
   a=infer(nets['Ds'],features[split]['Ds'],cache[split],s)/s['astd'];b=infer(nets['Vm'],features[split]['Vm'],cache[split],s)/s['astd']
   dif=(a-b).abs();bound=1e-9+1e-7*torch.maximum(a.abs(),b.abs());p=bool((dif<=bound).all());passed &=p
   r[split+'_max_acc_diff']=float(dif.max());r[split+'_rms_acc_diff']=float(dif.square().mean().sqrt());r[split+'_equivalence_pass']=p
  vp=dict(nets['Vm'].named_parameters());pd=md=vd=sym=0.
  for k,w in nets['Ds'].named_parameters():
   z=vp[k];inp=k in ['w1','skip'];fold=w.sum(1,keepdim=True) if inp else w
   pd=max(pd,float((fold-z).abs().max()))
   if inp:sym=max(sym,float((w-w[:,:1]).abs().max()))
   for state,label in [('exp_avg','m'),('exp_avg_sq','v')]:
    ws=opts['Ds'].state[w][state];vs=opts['Vm'].state[z][state]
    val=float(((ws[:,:1] if inp else ws)-vs).abs().max())
    if label=='m':md=max(md,val)
    else:vd=max(vd,val)
  r.update(effective_parameter_difference=pd,adam_first_moment_difference=md,adam_second_moment_difference=vd,column_symmetry_difference=sym,equivalence_pass=passed)
 return r
def run(seed,steps,preflight):
 out=R/('preflight' if preflight else 'training')/f'seed{seed}';out.mkdir(parents=True,exist_ok=False)
 paths=[Path(__file__),R/'冻结实验协议.md',B/'preflight/prepared.npz',B/'physics_run/cache.pt',B/'physics_run/best.pt',B/'run_model.py',B/'networks.py',B/'core.py',B/'bootstrap.py',B/'config.json',B/'revision_v2_20260929/run_revision.py']
 inputs={str(p):sha(p) for p in paths};dump(out/'inputs.json',inputs)
 cfg,data,cache,params,s=load();torch.set_num_threads(1)
 fs={sp:feats(d,s) for sp,d in data.items()};cs={sp:{k:c[k][32:] for k in ['base_acc','Minv']} for sp,c in cache.items()};ys={sp:d['a'][32:] for sp,d in data.items()}
 nets=make(seed);g=torch.Generator().manual_seed(73000+seed);batches=torch.randint(0,len(ys['train']),(steps,256),generator=g);np.save(out/'batch_indices.npy',batches.numpy()+32)
 opts={}
 for name,n in nets.items():
  if name=='Vm':opts[name]=torch.optim.Adam([dict(params=[n.w1,n.skip],lr=.007,weight_decay=1e-5/7),dict(params=[p for k,p in n.named_parameters() if k not in ['w1','skip']],lr=.001,weight_decay=1e-5)],betas=(.9,.999),eps=1e-8)
  else:opts[name]=torch.optim.Adam(n.parameters(),lr=.001,weight_decay=1e-5,betas=(.9,.999),eps=1e-8)
 initial={}; ref=infer(nets['Cdelta'],fs['train']['Cdelta'],cs['train'],s)
 for name,n in nets.items():
  torch.save(n.state_dict(),out/f'{name}_initial.pt');initial[name]=float((infer(n,fs['train'][name],cs['train'],s)-ref).abs().max())
 assert max(initial.values())<1e-10
 dump(out/'initial_check.json',dict(max_acceleration_difference=initial,H_C_parameters_equal=all(torch.equal(nets['Hdelta'].state_dict()[k],v) for k,v in nets['Cdelta'].state_dict().items())))
 logs=[];checks=[];best={n:float('inf') for n in NAMES};selection={};t0=time.time();clipped={n:0 for n in NAMES};firstfail=None
 for step,ids in enumerate(batches,1):
  row=dict(step=step)
  for name,n in nets.items():
   opt=opts[name];opt.zero_grad();a=prediction(n,fs['train'][name][ids],{k:v[ids] for k,v in cs['train'].items()},s);loss=((a-ys['train'][ids])/s['astd']).square().mean()
   if not torch.isfinite(loss):raise RuntimeError(f'Nonfinite loss {name} at {step}')
   loss.backward()
   if name=='Vm':
    norm=torch.sqrt(sum((7 if k in ['w1','skip'] else 1)*p.grad.square().sum() for k,p in n.named_parameters()));factor=torch.clamp(100/(norm+1e-6),max=1.)
    for p in n.parameters():p.grad.mul_(factor)
   else:norm=torch.nn.utils.clip_grad_norm_(n.parameters(),100);factor=torch.clamp(100/(norm+1e-6),max=1.)
   opt.step();clipped[name]+=int(norm>100);row[name+'_loss']=float(loss.detach());row[name+'_grad_norm']=float(norm);row[name+'_clip_factor']=float(factor)
  logs.append(row)
  if step%100==0 or step==steps:
   check=dict(step=step,**pair_stats(nets,opts,fs,cs,s))
   if not check['equivalence_pass'] and firstfail is None:firstfail=step
   for name,n in nets.items():
    for split in ['train','validation']:
     a=infer(n,fs[split][name],cs[split],s);check[name+'_'+split+'_nmse']=float(((a-ys[split])/s['astd']).square().mean())
   for name in ['Ds','Cdelta','Hdelta']:
    val=check[name+'_validation_nmse']
    if val<best[name]:
     best[name]=val;selection[name]=dict(step=step,validation_nmse=val);torch.save(nets[name].state_dict(),out/f'{name}_best.pt')
     if name=='Ds':selection['Vm']=dict(step=step,validation_nmse=check['Vm_validation_nmse'],selection='shared Ds checkpoint');torch.save(nets['Vm'].state_dict(),out/'Vm_best.pt')
   checks.append(check);write_csv(out/'checkpoints.csv',checks);dump(out/'progress.json',dict(seed=seed,step=step,seconds=time.time()-t0,selection=selection,first_equivalence_failure=firstfail,clip_counts=clipped))
   if step%1000==0 or step==steps:print(seed,step,{n:round(check[n+'_validation_nmse'],6) for n in NAMES},'equivalence',check['equivalence_pass'],'seconds',round(time.time()-t0),flush=True)
 metrics=[]
 for name,n in nets.items():
  torch.save(n.state_dict(),out/f'{name}_final.pt');torch.save(opts[name].state_dict(),out/f'{name}_optimizer_final.pt')
  for which in ['final','best']:
   n.load_state_dict(torch.load(out/f'{name}_{which}.pt',weights_only=True))
   for sp in data:
    a=infer(n,fs[sp][name],cs[sp],s);err=a-ys[sp];np.save(out/f'{name}_{which}_{sp}_acc.npy',a.numpy())
    mse=err.square().mean(0);metrics.append(dict(seed=seed,model=name,checkpoint=which,split=sp,nmse=float((mse/s['astd'].square()).mean()),rmse=mse.sqrt().tolist(),joint_nmse=(mse/s['astd'].square()).tolist()))
 for p,h in inputs.items():assert sha(p)==h,p
 write_csv(out/'per_step.csv',logs);dump(out/'metrics.json',metrics);dump(out/'selection.json',selection);torch.save(s,out/'scalers.pt')
 dump(out/'completion.json',dict(status='complete',seed=seed,steps=steps,total_optimizer_updates=steps*4,preflight=preflight,selection=selection,first_equivalence_failure=firstfail,equivalence_pass=firstfail is None,clip_counts=clipped,seconds=time.time()-t0,python=sys.version,torch=torch.__version__,numpy=np.__version__,inputs_unchanged=True,outputs={p.name:sha(p) for p in out.iterdir() if p.is_file()}))
 print('COMPLETE',seed,round(time.time()-t0),flush=True)
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--seed',type=int,required=True);ap.add_argument('--preflight',action='store_true');args=ap.parse_args()
 run(args.seed,20 if args.preflight else 10000,args.preflight)
