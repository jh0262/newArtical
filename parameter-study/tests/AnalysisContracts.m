classdef AnalysisContracts < matlab.unittest.TestCase
 methods(TestClassSetup)
  function paths(t)
   root=fileparts(fileparts(mfilename('fullpath')));t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'scripts')));
  end
 end
 methods(Test)
  function exactKnownDistribution(t)
   [p,e]=ERAnalysis.exact((1:5)');t.verifyEqual(p,1/16);t.verifyEqual(e,1);[p,e]=ERAnalysis.exact(zeros(16,1));t.verifyEqual(p,1);t.verifyEqual(e,0);
   [p,e]=ERAnalysis.exact([-1;-1;1;1]);t.verifyEqual(p,1);t.verifyEqual(e,0);
  end
  function effectsSeparateFactors(t)
   % Unit changes in eta levels, independent of sigma level.
   v=repmat([0,0,0,1,1,1,2,2,2,1,1,1,1],16,1);[d,~]=ERAnalysis.effects(v);t.verifyEqual(d(:,1:2),ones(16,2));t.verifyEqual(d(:,3:9),zeros(16,7));
   v=repmat([0,1,2,0,1,2,0,1,2,1,1,1,1],16,1);[d,~]=ERAnalysis.effects(v);t.verifyEqual(d(:,3:4),ones(16,2));t.verifyEqual(d(:,[1,2,5:9]),zeros(16,7));
  end
 end
end
