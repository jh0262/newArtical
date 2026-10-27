import bootstrap
import unittest
import numpy as np
from numpy.testing import assert_allclose
import torch
import core

class Contracts(unittest.TestCase):
    def test_metric_gold_and_horizon(self):
        pred=np.ones((2,3,6)); ref=np.zeros_like(pred); scale=np.full(6,2.)
        self.assertAlmostEqual(core.metric(pred,ref,scale)['nrmse'],.5)
        pred[:,0:2]=0
        self.assertAlmostEqual(core.metric(pred,ref,scale)['nrmse'],np.sqrt(1/12))
        self.assertAlmostEqual(core.metric(pred,ref,scale)['endpoint_nrmse'],.5)

    def test_metric_scale_permutation_and_nan(self):
        rng=np.random.default_rng(17); a=rng.normal(size=(5,4,6)); b=rng.normal(size=a.shape); s=np.arange(1,7.)
        x=core.metric(a,b,s)['nrmse']
        self.assertAlmostEqual(x,core.metric(3*a,3*b,3*s)['nrmse'])
        self.assertAlmostEqual(x,core.metric(a[...,::-1],b[...,::-1],s[::-1])['nrmse'])
        a[0,0,0]=np.nan
        with self.assertRaises(ValueError): core.metric(a,b,s)

    def test_spectral_derivative_analytic(self):
        dt=.004; t=np.arange(500)*dt; w=2*np.pi*2
        q=np.sin(w*t)[:,None]*np.ones((1,6)); u=np.ones_like(q)
        qf,v,a,uf=core.spectral(q,u,dt,50)
        assert_allclose(qf,q,atol=1e-12)
        assert_allclose(v,w*np.cos(w*t)[:,None]*np.ones((1,6)),atol=1e-10)
        assert_allclose(a,-w*w*q,atol=1e-8)
        assert_allclose(uf,u,atol=1e-12)

    def test_train_only_scaler(self):
        train=np.arange(30.).reshape(5,6)
        mean,std=core.fit_scales(train)
        unrelated_test=np.full((5,6),1e10)
        mean2,std2=core.fit_scales(train)
        assert_allclose(mean,train.mean(0)); assert_allclose(mean2,mean)
        assert_allclose(std2,std); self.assertTrue(np.all(std>0))

    def test_empty_regime_is_unavailable(self):
        pred=np.ones((2,3,6)); ref=np.zeros_like(pred)
        m=np.zeros_like(pred,dtype=bool)
        r=core.metric(pred,ref,np.ones(6),m)
        self.assertIsNone(r['nrmse'])
        self.assertIsNone(r['endpoint_nrmse'])
        self.assertEqual(r['joint_nrmse'],[None]*6)

    def test_history_causality(self):
        v=np.arange(60.).reshape(10,6); ids=np.array([3,5]); lags=[0,1,3]
        h=core.lag_features(v,ids,lags)
        assert_allclose(h[:,0],v[ids]); assert_allclose(h[:,2],v[ids-3])
        v2=v.copy(); v2[6:]=1e8
        assert_allclose(h,core.lag_features(v2,ids,lags))
        with self.assertRaises(ValueError): core.lag_features(v,np.array([1]),lags)

    def test_physics_roundtrip_spd(self):
        phy=core.load_physics(); torch.set_default_dtype(torch.float64)
        x=torch.zeros((7,12)); x[:,:6]=torch.linspace(-.4,.4,7)[:,None]
        x[:,6:]=.1; tau=torch.ones((7,6))
        d=torch.zeros(66); f=torch.zeros(30)
        parts=phy(x,tau,d,f,True,True)
        M=parts['M']; assert_allclose(M.numpy(),M.transpose(1,2).numpy(),atol=1e-9)
        self.assertGreater(float(torch.linalg.eigvalsh(M).min()),0)
        a=parts['x_dot_result'][:,6:]
        ti=phy(x,a,d,f,True,False,inverse=True)
        assert_allclose(ti.numpy(),tau.numpy(),rtol=1e-9,atol=1e-9)

if __name__=='__main__': unittest.main(verbosity=2)
