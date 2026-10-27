"""Scientific functions; contracts are tested before implementation."""
import bootstrap
import numpy as np
import ast, importlib.util, math, sys
from pathlib import Path
import torch
from torch import nn
ROOT=Path(__file__).resolve().parent
SOURCE=bootstrap.WORKSPACE/'05_evidence/20260928_robot_paper_selection/resources'
def spectral(q, u, dt, cutoff):
    q=np.asarray(q,dtype=np.float64); u=np.asarray(u,dtype=np.float64)
    w=2*np.pi*np.fft.rfftfreq(len(q),dt)
    fq=np.fft.rfft(q,axis=0); fu=np.fft.rfft(u,axis=0)
    fq[cutoff:]=0; fu[cutoff:]=0
    inv=lambda a:np.fft.irfft(a,n=len(q),axis=0)
    return inv(fq),inv(1j*w[:,None]*fq),inv(-w[:,None]**2*fq),inv(fu)
def metric(pred, ref, scale, mask=None):
    pred=np.asarray(pred); ref=np.asarray(ref); scale=np.asarray(scale)
    if not (np.isfinite(pred).all() and np.isfinite(ref).all() and np.isfinite(scale).all() and (scale>0).all()):
        raise ValueError('Nonfinite prediction/reference or invalid scale')
    if pred.shape!=ref.shape or pred.ndim!=3: raise ValueError('Expected origins x steps x joints')
    e2=(pred-ref)**2; z2=e2/scale**2
    m=np.ones_like(e2,dtype=bool) if mask is None else np.broadcast_to(mask,e2.shape)
    count=m.sum(axis=(0,1)); denom=np.maximum(count,1)
    mse=(e2*m).sum((0,1))/denom; nmse=(z2*m).sum((0,1))/denom
    valid=count>0
    end_count=m[:,-1,:].sum(0); end_valid=end_count>0
    end_mse=(z2[:,-1,:]*m[:,-1,:]).sum(0)/np.maximum(end_count,1)
    return dict(nrmse=float(np.sqrt(nmse[valid].mean())) if valid.any() else None,
                rmse_rad=float(np.sqrt(mse[valid].mean())) if valid.any() else None,
                endpoint_nrmse=float(np.sqrt(end_mse[end_valid].mean())) if end_valid.any() else None,
                joint_nrmse=[float(np.sqrt(nmse[j])) if valid[j] else None for j in range(len(scale))],
                joint_rmse_rad=[float(np.sqrt(mse[j])) if valid[j] else None for j in range(len(scale))],
                pair_counts=count.tolist())
def fit_scales(train):
    train=np.asarray(train)
    if not np.isfinite(train).all(): raise ValueError('Nonfinite training data')
    return train.mean(0),np.maximum(train.std(0),1e-12)
def lag_features(v, ids, lags):
    ids=np.asarray(ids); lags=np.asarray(lags)
    if np.min(ids)<np.max(lags) or np.min(lags)<0: raise ValueError('History unavailable')
    return v[ids[:,None]-lags[None,:]]
def load_physics():
    """Compile only audited pure model functions, never the original training entrypoint."""
    env=dict(torch=torch, nn=nn, math=math, from_exp_dir=False, exp_model_counter=0, sys=sys)
    for tag in ['M','C','g']:
        name=f'sympybotconv_{tag}_code'
        path=SOURCE/f'roblue__{name}.py'
        spec=importlib.util.spec_from_file_location(name,path)
        mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
        env[name]=mod
    tree=ast.parse((SOURCE/'roblue__roblue.py').read_text(encoding='utf-8'))
    cls=next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='F_robot_sympybotics')
    cls.body=[n for n in cls.body if isinstance(n,ast.FunctionDef) and n.name in ['x_dot','hydraulic_weight_counterbalance_hwc_params']]
    method=next(n for n in cls.body if n.name=='x_dot')
    # Remove unreachable plotting after the final top-level if/else return.
    stop=next(i for i,n in enumerate(method.body) if isinstance(n,ast.If) and ast.unparse(n.test)=='enable_parts_dict' and any(isinstance(t,ast.Return) for t in n.body))
    method.body=method.body[:stop+1]
    class Quiet(ast.NodeTransformer):
        def visit_Expr(self,node):
            if isinstance(node.value,ast.Call) and ast.unparse(node.value.func) in ['sys.stdout.write','sys.stdout.flush']: return None
            return self.generic_visit(node)
    cls=Quiet().visit(cls)
    module=ast.fix_missing_locations(ast.Module(body=[cls],type_ignores=[]))
    exec(compile(module,str(SOURCE/'roblue__roblue.py'),'exec'),env)
    fn=env['F_robot_sympybotics'].x_dot
    def call(x,tau,dyn,friction,include_friction=False,parts=False,inverse=False):
        return fn(x,tau,inverse,friction,torch.zeros(7),dyn,torch.zeros(6),include_friction,parts)
    return call
