function tests=test_joint
tests=functiontests(localfunctions);
end
function setupOnce(t)
r=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(r,'code'),fullfile(r,'code','reference'));P5Experiment.root(r);t.TestData.root=r;
end
function testConfig(t)
a=P5Variants.config('Full',123);b=P5Variants.config('joint',123);names=fieldnames(a);changed={};
for i=1:numel(names),if ~isequal(a.(names{i}),b.(names{i})),changed{end+1}=names{i};end,end
verifyEqual(t,sort(changed),sort({'useLock','principalGain'}));verifyFalse(t,b.useLock);verifyEqual(t,b.principalGain,0);
end
function testOperatorAndRNG(t)
p=P5Core.problem('ZDT6');rng(9);pop=[rand(100,p.D),zeros(100,p.M+2)];pop(:,1)=.5;st=struct('sigma',.3,'success',.2);
a=P5Variants.config('noNoise',123);b=P5Variants.config('joint',123);
rng(4);x=P5Mechanism.propose(p,pop,pop,a,st,1,0);ra=rng;
rng(4);[y,s,ap]=P5Mechanism.propose(p,pop,pop,b,st,1,0);rb=rng;
verifyEqual(t,x,y);verifyEqual(t,ra,rb);verifyFalse(t,ap);verifyEqual(t,s.components([3,6,8]),[0,0,0]);
rng(4);[~,s,ap]=P5Mechanism.propose(p,pop,pop,b,st,1,10);verifyFalse(t,ap);verifyEqual(t,s.components([3,6,8]),[0,0,0]);
end
function testSmokeAndBudget(t)
for task=["ZDT6","DTLZ3","PPAR"]
 p=P5Core.problem(task);if task=="PPAR",p.model=PPaPaRModel.config(256);end
 c=P5Variants.config('joint',123);c.N=12;c.G=6;c.archiveSize=12;
 a=P5Core.solve(p,'PACPO',c);b=P5Core.solve(p,'PACPO',c);
 verifyEqual(t,a.evaluations,b.evaluations);verifyEqual(t,a.FE,84);verifyEqual(t,a.archive,a.evaluations(a.archiveIDs,:));verifyTrue(t,all(isfinite(a.evaluations),'all'));verifyEqual(t,sum(a.history(:,4)),0);
 verifyGreaterThanOrEqual(t,a.X,p.lb-1e-10);verifyLessThanOrEqual(t,a.X,p.ub+1e-10);
end
end
function testExactOldConfigurations(t)
for task=["ZDT6","DTLZ3","PPAR"]
 if task=="PPAR",seed=400001;elseif task=="ZDT6",seed=812001;else,seed=813001;end
 for mode=["Full","noNoise","noLock"]
  job=struct('problem',char(task),'mode',char(mode),'seed',seed,'id',sprintf('%s_%s_%d',task,mode,seed));a=P5Experiment.replay(job);verifyEqual(t,a.FE,25100);
 end
end
end
