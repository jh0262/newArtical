"""Post-review conditional linear friction diagnostics; never overwrite models."""
from pathlib import Path
import sys,json,hashlib,datetime,csv,time
D=Path(__file__).resolve().parent;R=D.parent;B=R.parent
sys.path.insert(0,str(B))
import bootstrap,core,numpy as np,torch,scipy
from scipy.optimize import lsq_linear

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def now():return datetime.datetime.now().astimezone().isoformat()
def main():
    assert not (D/'results.json').exists(),'Preserve existing diagnostic output'
    torch.set_default_dtype(torch.float64);torch.set_num_threads(1)
    inputs=[Path(__file__),D/'分析与冻结方案.md',B/'preflight/prepared.npz',B/'physics_run/best.pt',B/'physics_run/cache.pt',B/'physics_run/training_log.json',B/'core.py',B/'bootstrap.py',B/'run_physics.py',B/'config.json']
    inputs += list(core.SOURCE.glob('roblue__*.py'))
    hashes={str(p):sha(p) for p in inputs}
    manifest=dict(started_at=now(),status='running',input_hashes=hashes,scope='Post-review diagnostic; train-only conditional identification, no model replacement or new confirmation')
    (D/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    t=time.perf_counter();z=np.load(B/'preflight/prepared.npz');p=torch.load(B/'physics_run/best.pt',weights_only=True);cache=torch.load(B/'physics_run/cache.pt',weights_only=True)
    phy=core.load_physics();scale=z['train_a'].std(0);gear=np.array([256.85714285714283,267.42857142857144,252.33333333333334,221.,239.61904761904762,154.3231343283582])
    basevis=np.array([5000.,5000.,5000.,1000.,1000.,1000.])
    basecoul=np.array([2.265625,5.978125,5.359375,9.690625,.409375,7.834375])*20
    baseoffset=np.array([2.8125,-2.1875,-.3125,-4.0625,-.3125,-4.6875])*np.array([5,10,10,10,10,10])
    f=p['friction'].numpy();coef_original=np.r_[basevis*(1+.01*f[:6]),basecoul*(1+.01*f[6:12]),baseoffset*(1+.01*f[24:30])]
    checks={};data={};arrays={}
    with torch.no_grad():
      for split in ['train','validation','test']:
        q=z[split+'_q'];v=z[split+'_v'];u=z[split+'_u'];a=z[split+'_a'];x=torch.tensor(np.c_[q,v]);tt=torch.tensor(u)
        parts=phy(x,tt,p['dyn'],p['friction'],False,True)
        full=phy(x,tt,p['dyn'],p['friction'],True,True)
        mat=parts['M'].numpy();inv=parts['M_inverse'].numpy();a0=parts['x_dot_result'][:,6:].numpy();ap=full['x_dot_result'][:,6:].numpy()
        taufr=v*coef_original[:6]+np.tanh(v)*coef_original[6:12]+coef_original[12:]
        reconstructed=a0-np.einsum('tij,tj->ti',inv,taufr)
        # inverse_mode + parts=False is the source's valid inverse call.
        invtau=phy(x,torch.tensor(ap),p['dyn'],p['friction'],True,False,True).numpy()
        independent_net=u*gear-parts['G_hyd'].numpy()-np.einsum('tij,tj->ti',parts['C'].numpy(),v)
        solve=np.linalg.solve(mat,independent_net[...,None])[...,0]
        checks[split]=dict(M_symmetry_max=float(np.max(np.abs(mat-mat.swapaxes(-1,-2)))),M_inverse_residual_max=float(np.max(np.abs(mat@inv-np.eye(6)))),component_acceleration_max=float(np.max(np.abs(solve-a0))),friction_reconstruction_max=float(np.max(np.abs(reconstructed-ap))),inverse_motor_torque_max=float(np.max(np.abs(invtau-u))),cache_base_max=float(np.max(np.abs(cache[split]['base_acc'].numpy()-a0))),cache_M_max=float(np.max(np.abs(cache[split]['M'].numpy()-mat))),min_eigenvalue=float(np.linalg.eigvalsh(mat).min()))
        basis=np.concatenate([inv*v[:,None,:],inv*np.tanh(v)[:,None,:],inv],axis=2)
        design=-basis/scale[None,:,None]
        target=(a-a0)/scale
        data[split]=dict(a=a,a0=a0,ap=ap,design=design,target=target)
        arrays[split+'_reference']=a;arrays[split+'_base']=a0;arrays[split+'_original_physics']=ap
        print('components',split,checks[split],flush=True)
    active=np.arange(32,len(z['train_a']));A=data['train']['design'][active].reshape(-1,18);y=data['train']['target'][active].reshape(-1)
    lo=np.r_[.001*basevis,.001*basecoul,np.minimum(-3*baseoffset,5*baseoffset)]
    hi=np.r_[5*basevis,5*basecoul,np.maximum(-3*baseoffset,5*baseoffset)]
    fits={};coefficients={'original':coef_original};rows=[]
    singular=np.linalg.svd(A,compute_uv=False)
    for name,bounds in [('same_bounds',(lo,hi)),('nonnegative_relaxed',(np.r_[np.zeros(12),np.full(6,-np.inf)],np.full(18,np.inf)))]:
        fit=lsq_linear(A,y,bounds=bounds,method='bvls',tol=1e-12,max_iter=10000)
        assert fit.success,(name,fit.message)
        fits[name]=dict(success=bool(fit.success),status=int(fit.status),message=fit.message,optimality=float(fit.optimality),cost=float(fit.cost),nit=int(fit.nit),active_mask=fit.active_mask.tolist(),coef=fit.x.tolist())
        coefficients[name]=fit.x
        print('fit',name,fits[name],flush=True)
    mean=z['train_a'].mean(0)
    for split,d in data.items():
      ii=np.arange(32,len(d['a']))
      preds={'no_friction':d['a0'],'original':d['ap'],'training_mean':np.broadcast_to(mean,d['a'].shape)}
      for name in fits:
        preds[name]=d['a0']+np.einsum('tij,j->ti',d['design'],coefficients[name])*scale
      for name,pred in preds.items():
        arrays[split+'_'+name]=pred
        e=pred[ii]-d['a'][ii];nmse=(e/scale)**2
        rows.append(dict(split=split,model=name,n=len(ii),acc_nmse=float(nmse.mean()),joint_nmse=nmse.mean(0).tolist(),joint_rmse=np.sqrt((e*e).mean(0)).tolist(),joint_bias=e.mean(0).tolist()))
    original_train=np.array([r['acc_nmse'] for r in rows if r['split']=='train' and r['model']=='original'])[0]
    grad=A.T@(A@coef_original-y)/len(y)
    # Projected gradient in the physical coefficient box, a diagnostic only.
    projected=coef_original-np.clip(coef_original-grad,lo,hi)
    dyn=p['dyn'].numpy()
    boundary=dict(dyn_at_upper=np.flatnonzero(np.isclose(dyn,200,rtol=0,atol=1e-9)).tolist(),dyn_at_lower=np.flatnonzero(np.isclose(dyn,-200,rtol=0,atol=1e-9)).tolist(),friction_original_coef=coef_original.tolist(),friction_lower=lo.tolist(),friction_upper=hi.tolist(),inactive_friction_zero_based=list(range(12,24)),source_forced_zero_dyn_zero_based=list(range(55,63)),original_training_nmse=original_train,projected_gradient_inf_norm=float(np.max(np.abs(projected))),gradient_in_coefficient_units=grad.tolist())
    assert all(sha(p)==h for p,h in hashes.items()),'Source changed during diagnostic'
    result=dict(scope=manifest['scope'],completed_at=now(),checks=checks,fits=fits,metrics=rows,boundary=boundary,linear_design=dict(shape=list(A.shape),rank=int(np.linalg.matrix_rank(A)),singular_values=singular.tolist(),condition=float(singular[0]/singular[-1])),versions=dict(python=sys.version,numpy=np.__version__,torch=torch.__version__,scipy=scipy.__version__),input_hashes=hashes)
    np.savez_compressed(D/'predictions.npz',**arrays)
    (D/'results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    with (D/'metrics.csv').open('w',encoding='utf-8-sig',newline='') as file:
      w=csv.DictWriter(file,fieldnames=['split','model','n','acc_nmse']);w.writeheader();w.writerows({k:r[k] for k in w.fieldnames} for r in rows)
    manifest.update(status='complete',ended_at=now(),elapsed_seconds=time.perf_counter()-t,output_hashes={f:sha(D/f) for f in ['results.json','predictions.npz','metrics.csv']})
    (D/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('complete',manifest['elapsed_seconds'],[(r['split'],r['model'],r['acc_nmse']) for r in rows],flush=True)
if __name__=='__main__':main()
