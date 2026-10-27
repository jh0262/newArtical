import bootstrap
import torch
from torch import nn
import math
def rollout(rhs,x,u,hist,lags,dt):
    out=[]
    for k in range(u.shape[1]):
        tau=u[:,k]
        k1=rhs(x,tau,hist,0.)
        k2=rhs(x+.5*dt*k1,tau,hist,.5)
        k3=rhs(x+.5*dt*k2,tau,hist,.5)
        k4=rhs(x+dt*k3,tau,hist,1.)
        x=x+dt*(k1+2*k2+2*k3+k4)/6
        if not torch.isfinite(x).all() or x.abs().max()>1e6:
            raise RuntimeError('Nonfinite/divergent rollout at step '+str(k+1))
        hist=torch.cat([x[:,None,6:],hist[:,:-1,:]],dim=1)
        out.append(x.clone())
    return torch.stack(out,dim=1)
def history_stage(hist,current_v,lags,c):
    # Positive delays interpolate only previously available predicted/initial states.
    return torch.stack([current_v if lag==0 else (1-c)*hist[:,lag]+c*hist[:,lag-1] for lag in lags],dim=2)
class JointNet(nn.Module):
    def __init__(self,width=1,hidden=100):
        super().__init__()
        self.w1=nn.Parameter(torch.zeros((6,width,hidden)))
        with torch.no_grad(): self.w1[:,0,:].uniform_(-1.,1.)
        self.b1=nn.Parameter(torch.empty((6,1,hidden)).uniform_(-1.,1.))
        self.w2=nn.Parameter(torch.empty((6,hidden,hidden)).uniform_(-1/math.sqrt(hidden),1/math.sqrt(hidden)))
        self.b2=nn.Parameter(torch.empty((6,1,hidden)).uniform_(-1/math.sqrt(hidden),1/math.sqrt(hidden)))
        self.w3=nn.Parameter(torch.empty((6,hidden,1)).uniform_(-1/math.sqrt(hidden),1/math.sqrt(hidden)))
        self.b3=nn.Parameter(torch.empty((6,1,1)).uniform_(-1/math.sqrt(hidden),1/math.sqrt(hidden)))
        self.skip=nn.Parameter(torch.zeros((6,width,1)))
        with torch.no_grad(): self.skip[:,0,:].uniform_(-1.,1.)
    def forward(self,x):
        x=x.permute(1,0,2)
        z=torch.tanh(x.bmm(self.w1)+self.b1)
        z=torch.tanh(z.bmm(self.w2)+self.b2)
        y=z.bmm(self.w3)+self.b3+x.bmm(self.skip)
        return y[:,:,0].T

class PlainNet(nn.Module):
    def __init__(self,hidden=1000):
        super().__init__()
        self.mlp=nn.Sequential(nn.Linear(18,hidden),nn.Tanh(),nn.Linear(hidden,hidden),nn.Tanh(),nn.Linear(hidden,6))
        self.skip=nn.Linear(18,6,bias=False)
    def forward(self,x): return self.mlp(x)+self.skip(x)
