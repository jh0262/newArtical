classdef MechanismContracts < matlab.unittest.TestCase
 properties(TestParameter)
  task={'PPAR','DTLZ3'};
  analytic={'DTLZ3','ZDT4'};
 end
 methods(TestClassSetup)
  function paths(t)
   here=fileparts(mfilename('fullpath'));root=fileparts(here);
   t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(here,'reference')));
   t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'code')));
   t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'code/reference')));
  end
 end
 methods(Test)
  function observerIsNeutral(t,task)
   p=ERCore.problem(task);p=MechanismContracts.small(p);c=ERStudy.config('B',2601027);c.N=20;c.G=12;c.archiveSize=20;c.captureGenerations=[1,7];
   old=PTStudy.default(c.seed);old.N=20;old.G=12;old.archiveSize=20;
   a=PTCore.solve(p,'PACPO',old);b=ERCore.solve(p,'PACPO',c);
   t.verifyEqual(b.evaluations,a.evaluations);t.verifyEqual(b.history,a.history);t.verifyEqual(b.finalRNG,a.finalRNG);t.verifyNumElements(b.snapshots,2);
  end
  function inactiveCap(t)
   c=ERStudy.config('B',1);c.pulseCap=.2;rng(14);[a,rows]=ERPulse.draw(eye(4),diag([1,0,0,0]),[.001;.1;.2;.3],c,.02,5,100,4);r1=rng;
   c.pulseCap=.05;rng(14);[b,other]=ERPulse.draw(eye(4),diag([1,0,0,0]),[.001;.1;.2;.3],c,.02,5,100,4);r2=rng;
   t.verifyEqual(a,b);t.verifyEqual(rows,other);t.verifyEqual(r1,r2);
  end
  function windowControlsEligibility(t)
   c=ERStudy.config('B',1);[~,~,on]=ERPulse.draw(eye(4),diag([1,0,0,0]),[.001;.1;.2;.3],c,.02,5,100,4);
   c.window=10;[~,~,off]=ERPulse.draw(eye(4),diag([1,0,0,0]),[.001;.1;.2;.3],c,.02,5,100,4);
   t.verifyTrue(on);t.verifyFalse(off);
  end
  function inactiveGateDiagnostic(t)
   c=ERStudy.config('B',1);rng(17);[a,~,pa,~,ga]=ERPulse.draw(eye(4),zeros(4),ones(4,1),c,.02,5,100,4);ra=rng;
   c.window=10;rng(17);[b,~,pb,~,gb]=ERPulse.draw(eye(4),zeros(4),ones(4,1),c,.02,5,100,4);rb=rng;
   t.verifyEqual(a,b);t.verifyFalse(pa||pb);t.verifyEqual(ra,rb);t.verifyNotEqual(ga(1),gb(1));
  end
  function noiseProduct(t)
   p=ERCore.problem('DTLZ3');c=ERStudy.config('B',111);c.N=20;c.G=1;c.archiveSize=20;r=ERCore.solve(p,'PACPO',c);s=r.snapshots{1};c.useLock=false;c.probeAudit=true;
   state=s.state;state.sigma=.02;rng(s.rng);[~,a]=ERMechanism.propose(p,s.population,s.archive,c,state,1,0);ra=rng;
   c.principalGain=.15;state.sigma=.1;rng(s.rng);[~,b]=ERMechanism.propose(p,s.population,s.archive,c,state,1,0);rb=rng;
   t.verifyEqual(b.proposalAudit.noise,15*a.proposalAudit.noise,'AbsTol',1e-14);t.verifyEqual(ra,rb);
  end
  function gaussianExpectation(t,analytic)
   [prediction,estimate,se]=MechanismContracts.monteCarlo(analytic);
   t.verifyLessThan(abs(prediction-estimate),4*se);
  end
 end
 methods(Static)
  function p=small(p)
   if strcmp(p.name,'PPAR'),p.model=PPaPaRModel.config(128);end
  end
  function [prediction,estimate,se]=monteCarlo(name)
   rng(2601027);n=100000;
   if strcmp(name,'DTLZ3'),x=[.2,.3,.503];v=[0,0,2.25e-6];else,x=[.2,.05];v=[0,2.25e-4];end
   p=struct('name',name);e=randn(n,numel(x)).*sqrt(v);[a,~,~]=ERTheory.landscape(p,x+e);[b,~,~]=ERTheory.landscape(p,x);delta=a-b;
   prediction=ERTheory.expectedG(name,x,v);estimate=mean(delta);se=std(delta)/sqrt(n);
  end
 end
end
