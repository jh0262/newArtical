"""Independent full-horizon check of every currently failed H seed9 origin.
Posthoc diagnostic triggered by the prespecified maximum-difference failure;
does not overwrite the original two-tolerance predictions or their pass status.
"""
from pathlib import Path
import time,json,hashlib
from adaptive_integrator import R,REV,load,JointNet,FrozenRHS,robot_rollout,torch,np,dump,solve_ivp
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
cfg,data,cache,params,s=load();torch.set_num_threads(1);dest=R/'failed_origin_check';dest.mkdir(exist_ok=True)
lo=R/'adaptive/history_9_loose.npz';hi=R/'adaptive/history_9_tight.npz';a=np.load(lo);b=np.load(hi);scale=torch.cat([s['qstd'],s['vstd']]);diff=abs((a['prediction'][:,:,:6]-b['prediction'][:,:,:6])/s['qstd'].numpy());ii=np.where(diff.max((1,2))>1e-3)[0];assert len(ii)==1
selected=json.loads((REV/'results/selected.json').read_text());r=next(v for v in selected if v['model']=='history' and v['seed']==9);weight=REV/r['path']/'best.pt';net=JointNet(7);net.load_state_dict(torch.load(weight,weights_only=True));rhs=FrozenRHS(net,'history',params,s,cfg).eval();d=data['test'];starts=b['starts'][ii]
paths=[Path(__file__),lo,hi,weight,R/'adaptive_integrator.py',R/'numerical_refinement.py',R/'external_validation/semantic_dependencies.json'];hashes={str(p):sha(p) for p in paths};dump(dest/'inputs.json',hashes)
dump(dest/'protocol.json',dict(trigger='H seed9 original two-tolerance maximum-position criterion failure',selection='All origins with maximum normalized position difference above 1e-3; no error ranking or benefit selection',origins=starts.tolist(),array_indices=ii.tolist(),dp_rtol=1e-10,dp_atol_factor=1e-12,radau_rtol=1e-10,radau_atol_factor=1e-12,horizon=150,changes_to_original_results='none; retain original failure status'))
st=time.time();dp,stat=robot_rollout(rhs,d,cfg,starts,scale,1e-10,1e-12);np.savez_compressed(dest/'dp_refined.npz',prediction=dp,starts=starts);dump(dest/'dp_stats.json',stat);others=[];stats=[]
for start in starts:
 x=torch.cat([d['q'][start],d['v'][start]]).numpy();hist=d['v'][int(start)-torch.arange(33)][None,:,:].clone();part=[];calls=0;steps=0
 for k in range(150):
  u=d['u'][int(start)+k][None,:]
  def fun(t,y):
   with torch.no_grad():
    value,info=rhs(torch.tensor(y)[None,:],u,hist,torch.tensor(t/.004));assert not info.any();return value[0].numpy()
  sol=solve_ivp(fun,(0,.004),x,method='Radau',rtol=1e-10,atol=scale.numpy()*1e-12);assert sol.success,sol.message
  x=sol.y[:,-1];part.append(x.copy());hist=torch.cat([torch.tensor(x[6:])[None,None,:],hist[:,:-1]],1);calls+=sol.nfev;steps+=len(sol.t)-1
  if (k+1)%25==0:print('RADAU',int(start),'output',k+1,'seconds',round(time.time()-st,1),flush=True)
 others.append(part);stats.append(dict(start=int(start),nfev=calls,steps=steps))
radau=np.array(others);np.savez_compressed(dest/'radau.npz',prediction=radau,starts=starts)
def compare(p,q):
 z=abs((p-q)/scale.numpy());return dict(max_normalized_state_difference=float(z.max()),max_normalized_position_difference=float(z[:,:,:6].max()),position_difference_nrmse=float(np.sqrt(np.mean(z[:,:,:6]**2))))
for p,h in hashes.items():assert sha(p)==h,p
dump(dest/'verification.json',dict(status='complete',origins=starts.tolist(),dp_vs_radau=compare(dp,radau),original_tight_vs_radau=compare(b['prediction'][ii],radau),original_loose_vs_radau=compare(a['prediction'][ii],radau),stats=stats,seconds=time.time()-st,input_hashes_unchanged=True,scope='One selected-by-failure origin, full 0.6s. Original consistency failure is retained; no whole-dataset independent-solver claim.'))
print((dest/'verification.json').read_text())
