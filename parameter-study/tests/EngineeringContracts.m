classdef EngineeringContracts < matlab.unittest.TestCase
 methods(TestClassSetup)
  function paths(t)
   root=fileparts(fileparts(mfilename('fullpath')));t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'code')));t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'code/reference')));
  end
 end
 methods(Test)
  function configurations(t)
   ids=ERStudy.variants();t.verifyNumElements(ids,13);v=zeros(13,4);
   for i=1:13,c=ERStudy.config(ids(i),1);v(i,:)=[c.principalGain,c.sigmaMin,c.window,c.pulseCap];t.verifyEqual(c.N*(c.G+1),25100);t.verifyTrue(c.useLock);end
   t.verifyEqual(size(unique(v,'rows'),1),13);t.verifyEqual(v(5,:),[.05,.02,5,.2]);t.verifyEqual(v(1,:),[.025,.005,5,.2]);t.verifyEqual(v(9,:),[.10,.05,5,.2]);
  end
  function activeCap(t)
   c=ERStudy.config('B',1);rng(14);[a,rows]=ERPulse.draw(eye(4),diag([1,0,0,0]),[.001;.1;.2;.3],c,.02,5,100,4);ra=rng;
   c.pulseCap=.005;rng(14);[b,other]=ERPulse.draw(eye(4),diag([1,0,0,0]),[.001;.1;.2;.3],c,.02,5,100,4);rb=rng;
   t.verifyEqual(b,.25*a,'AbsTol',1e-15);t.verifyEqual(rows,other);t.verifyEqual(ra,rb);
  end
  function pairedInitialAndBudget(t)
   p=ERCore.problem('DTLZ3');c=ERStudy.config('B',941001);c.N=20;c.G=3;c.archiveSize=20;a=ERCore.solve(p,'PACPO',c);
   c.principalGain=.1;b=ERCore.solve(p,'PACPO',c);t.verifyEqual(a.evaluations(1:20,:),b.evaluations(1:20,:));t.verifyEqual(a.FE,80);t.verifyEqual(b.FE,80);t.verifyEqual(a.evaluations(:,end),(1:80)');
  end
 end
end
