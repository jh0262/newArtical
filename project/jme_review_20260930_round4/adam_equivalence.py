"""Algebraic optimizer-path verification on training batches, not candidate retraining."""
from pathlib import Path
import sys,json,time,math,hashlib
R=Path(__file__).resolve().parent;BASE=R.parent;REV=BASE/'revision_v2_20260929'
sys.path.insert(0,str(REV))
from run_revision import load,JointNet,dump,write_csv
import run_model as rm
import torch,numpy as np

def main():
 cfg,data,cache,params,s=load();out=R/'optimizer_verification';out.mkdir(exist_ok=True)
 steps=200;K=7;eta=1e-4;lam=1e-5;clip=100.;rows=[];details=[];t0=time.time()
 # All cases use identical real training batches. Neither validation nor test is used.
 gen=torch.Generator().manual_seed(73019)
 batches=[torch.randint(32,15000,(256,),generator=gen) for _ in range(steps)]
 for case in ['matched_symmetric','wrong_uniform_lr','wrong_clip_norm','asymmetric_columns']:
  rm.set_seed(9,1);slim=JointNet(1);wide=JointNet(K)
  sd={k:v.detach().clone() for k,v in slim.state_dict().items()}
  wd={k:v.detach().clone() for k,v in sd.items()}
  for name in ['w1','skip']:
   wd[name]=sd[name].repeat(1,K,1)/K
   if case=='asymmetric_columns':wd[name].zero_();wd[name][:,0:1]=sd[name]
  wide.load_state_dict(wd)
  optw=torch.optim.Adam(wide.parameters(),lr=eta,weight_decay=lam)
  inp=[slim.w1,slim.skip];other=[p for name,p in slim.named_parameters() if name not in ['w1','skip']]
  opts=torch.optim.Adam([dict(params=inp,lr=eta*(1 if case=='wrong_uniform_lr' else K),weight_decay=lam/K),dict(params=other,lr=eta,weight_decay=lam)])
  maxout=maxpar=maxloss=0.;clips=0;last=None
  for step,ids in enumerate(batches,1):
   feat=(data['train']['v'][ids]-s['vmean'])/s['vstd'];xf=feat[:,:,None]
   yw=wide(xf.repeat(1,1,K));ys=slim(xf)
   lw=((rm.acceleration(wide,xf.repeat(1,1,K),cache['train']['base_acc'][ids],cache['train']['Minv'][ids],'capacity_control',s)-data['train']['a'][ids])/s['astd']).square().mean()
   ls=((rm.acceleration(slim,xf,cache['train']['base_acc'][ids],cache['train']['Minv'][ids],'velocity',s)-data['train']['a'][ids])/s['astd']).square().mean()
   optw.zero_grad();opts.zero_grad();lw.backward();ls.backward()
   nw=torch.nn.utils.clip_grad_norm_(wide.parameters(),clip)
   weights={name:(K if name in ['w1','skip'] and case!='wrong_clip_norm' else 1) for name,_ in slim.named_parameters()}
   ns=torch.sqrt(sum(weights[name]*p.grad.square().sum() for name,p in slim.named_parameters()))
   fac=torch.clamp(clip/(ns+1e-6),max=1.)
   for p in slim.parameters():p.grad.mul_(fac)
   optw.step();opts.step();clips+=int(nw>clip)
   with torch.no_grad():
    a=wide(xf.repeat(1,1,K));b=slim(xf)
    eo=float((a-b).abs().max())
    ep=max(float(((p.sum(1,keepdim=True) if name in ['w1','skip'] else p)-dict(slim.named_parameters())[name]).abs().max()) for name,p in wide.named_parameters())
   el=abs(float(lw.detach()-ls.detach()));maxout=max(maxout,eo);maxpar=max(maxpar,ep);maxloss=max(maxloss,el)
   details.append(dict(case=case,step=step,max_output_difference=eo,effective_parameter_difference=ep,loss_difference=el,wide_unclipped_grad_norm=float(nw),slim_weighted_grad_norm=float(ns)))
   last=eo
  rows.append(dict(case=case,steps=steps,max_normalized_output_difference=maxout,final_batch_output_difference=last,max_effective_parameter_difference=maxpar,max_loss_difference=maxloss,clipped_steps=clips))
  print(case,rows[-1],flush=True)
 assert rows[0]['max_normalized_output_difference']<1e-9
 assert rows[0]['max_effective_parameter_difference']<1e-9
 assert all(r['max_normalized_output_difference']>1e-9 for r in rows[1:])
 write_csv(out/'summary.csv',rows);write_csv(out/'per_step.csv',details)
 dump(out/'verification.json',dict(status='pass',scope='Optimizer algebra verified using copied, newly initialized networks and real training batches. No existing checkpoints modified, no validation/test selection, no predictive superiority claim.',cases=rows,steps=steps,optimizer_steps=steps*2*len(rows),K=K,lr=eta,coupled_L2=lam,clip=clip,batch_seed=73019,network_seed=9,seconds=time.time()-t0,python=sys.version,torch=torch.__version__,script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()))

if __name__=='__main__':main()
