import bootstrap
import unittest
import torch
from numpy.testing import assert_allclose
from networks import JointNet,rollout,history_stage
torch.set_default_dtype(torch.float64)
class NetworkContracts(unittest.TestCase):
    def test_capacity_initial_function_matches(self):
        torch.manual_seed(9); a=JointNet(1,10)
        torch.manual_seed(9); b=JointNet(7,10)
        x=torch.linspace(-1,1,30).reshape(5,6,1)
        assert_allclose(a(x).detach(),b(x.repeat(1,1,7)).detach(),atol=1e-12)
    def test_delayed_history_stage(self):
        hist=torch.arange(5.).reshape(1,5,1).repeat(1,1,6)
        v=torch.full((1,6),99.)
        out=history_stage(hist,v,[0,1,4],.5)
        assert_allclose(out[:,:,0],99.);assert_allclose(out[:,:,1],.5);assert_allclose(out[:,:,2],3.5)
    def test_rk4_analytic_and_predicted_history(self):
        hist=torch.zeros((2,5,6)); x=torch.zeros((2,12)); u=torch.ones((2,20,6)); seen=[]
        def rhs(x,u,h,c):
            seen.append(h.detach().clone())
            return torch.cat([x[:,6:],u],dim=1)
        pred=rollout(rhs,x,u,hist,[0,1,4],.01)
        assert_allclose(pred[:,-1,:6],.5*.2**2,atol=1e-12)
        assert_allclose(pred[:,-1,6:],.2,atol=1e-12)
        assert_allclose(seen[4][:,0,:],.01,atol=1e-12)
if __name__=='__main__':unittest.main(verbosity=2)
