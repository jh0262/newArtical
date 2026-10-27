"""Independent Radau diagnostic with verified frozen RHS and per-interval checkpoints.

The original eager Radau attempt is retained. This diagnostic changes RHS execution,
not the chosen origin, tolerance, integration method, or original failure label.
"""
from pathlib import Path
import json,hashlib,time,io,traceback
from adaptive_integrator import R,load,torch,np,dump,solve_ivp,algorithm_signature
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 dest=R/'failed_origin_check_compiled';dest.mkdir(exist_ok=True)
 cfg,data,cache,params,s=load();torch.set_num_threads(1);scale=torch.cat([s['qstd'],s['vstd']]).numpy()
 check=R/'compiled_execution/verification.json';cv=json.loads(check.read_text());assert cv['status']=='pass' and cv['algorithm_signature']==algorithm_signature()
 row=next(x for x in cv['models'] if x['model']=='history' and x['seed']==9);gp=Path(row['path']);assert sha(gp)==row['sha256']
 for p,h in json.loads((R/'compiled_execution/verification_inputs.json').read_text()).items():assert sha(p)==h,p
 original=R/'failed_origin_check';prot=json.loads((original/'protocol.json').read_text());assert prot['origins']==[11982] and prot['radau_rtol']==1e-10
 dpfile=original/'dp_refined.npz';assert dpfile.exists()
 paths=[Path(__file__),check,gp,original/'protocol.json',dpfile,R/'adaptive/history_9_loose.npz',R/'adaptive/history_9_tight.npz']
 hashes={str(p):sha(p) for p in paths};dump(dest/'inputs.json',hashes)
 dump(dest/'protocol.json',dict(**prot,execution='verified frozen TorchScript graph',reason='Original eager Radau has not reached first 25-interval progress after 27 minutes; preserve that attempt and checkpoint this separately.',independent_method='SciPy Radau; numerical finite-difference Jacobian',original_failure_retained=True))
 rhs=torch.jit.load(io.BytesIO(gp.read_bytes())).eval();d=data['test'];start=11982
 x=torch.cat([d['q'][start],d['v'][start]]).numpy();hist=d['v'][start-torch.arange(33)][None,:,:].clone();part=[];statistics=[];beg=time.time()
 for k in range(150):
  u=d['u'][start+k][None,:]
  def fun(t,y):
   with torch.no_grad():
    value,info=rhs(torch.tensor(y)[None,:],u,hist,torch.tensor(t/.004));assert not info.any();return value[0].numpy()
  tic=time.time();sol=solve_ivp(fun,(0,.004),x,method='Radau',rtol=1e-10,atol=scale*1e-12);assert sol.success,sol.message
  x=sol.y[:,-1];part.append(x.copy());hist=torch.cat([torch.tensor(x[6:])[None,None,:],hist[:,:-1]],1)
  statistics.append(dict(output_step=k+1,nfev=sol.nfev,njev=sol.njev,nlu=sol.nlu,accepted_steps=len(sol.t)-1,seconds=time.time()-tic))
  np.savez_compressed(dest/'checkpoint.npz',prediction=np.array(part)[None,:,:],starts=np.array([start]));dump(dest/'progress.json',dict(status='running',completed_intervals=k+1,seconds=time.time()-beg,statistics=statistics))
  print('RADAU COMPILED',k+1,'nfev',sol.nfev,'seconds',round(time.time()-tic,1),flush=True)
 radau=np.array(part)[None,:,:];np.savez_compressed(dest/'radau.npz',prediction=radau,starts=np.array([start]))
 def compare(p,q):
  z=abs((p-q)/scale);return dict(max_normalized_state_difference=float(z.max()),max_normalized_position_difference=float(z[:,:,:6].max()),position_difference_nrmse=float(np.sqrt(np.mean(z[:,:,:6]**2))))
 lo=np.load(R/'adaptive/history_9_loose.npz');hi=np.load(R/'adaptive/history_9_tight.npz');assert np.array_equal(lo['starts'],hi['starts']);idx=np.where(hi['starts']==start)[0];assert len(idx)==1
 for p,h in hashes.items():assert sha(p)==h,p
 dump(dest/'verification.json',dict(status='complete',origins=[start],dp_vs_radau=compare(np.load(dpfile)['prediction'],radau),original_tight_vs_radau=compare(hi['prediction'][idx],radau),original_loose_vs_radau=compare(lo['prediction'][idx],radau),stats=statistics,seconds=time.time()-beg,input_hashes_unchanged=True,scope='One origin selected by original failure criterion; independent Radau with verified compiled RHS. Original failure unchanged.'))
 print((dest/'verification.json').read_text(),flush=True)
if __name__=='__main__':
 try:main()
 except Exception:
  (R/'failed_origin_check_compiled/failure.txt').write_text(traceback.format_exc(),encoding='utf-8');raise
