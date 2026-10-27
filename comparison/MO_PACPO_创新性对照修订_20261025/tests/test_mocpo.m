function tests=test_mocpo
tests=functiontests(localfunctions);
end
function setupOnce(~)
r=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(r,'code'),fullfile(r,'code','reference'));
end
function testPaperFormulaExamples(t)
c=MOCPO2025.config('MOCPOF',1);x=[.2,.4];g=[.8,.6];r=[.6,.2];b=[.4,.8];
verifyEqual(t,MOCPO2025.branch(x,g,r,b,1,.4,[1,-1],c),[.32,.44],'AbsTol',1e-14);
verifyEqual(t,MOCPO2025.branch(x,g,r,b,2,.4,[1,-1],c),[.4,.3],'AbsTol',1e-14);
verifyEqual(t,MOCPO2025.branch(x,g,r,b,3,.4,[1,-1],c),[.21,.39],'AbsTol',1e-14);
verifyEqual(t,MOCPO2025.branch(x,g,r,b,4,.4,[1,-1],c),[.3,.6],'AbsTol',1e-14);
end
function testIFMWeights(t)
p=P4Core.problem('ZDT1');c=MOCPO2025.config('MOCPOF',1);
[q,w]=MOCPO2025.feedback(p,[0,1],[1,1],0,[1,0],[3,3],0,c);
verifyEqual(t,w,.75);verifyEqual(t,q,[.25,.75]);
c.mode='MOCPOR';[q,w]=MOCPO2025.feedback(p,[0,1],[1,1],0,[1,0],[3,3],0,c);
verifyEqual(t,w,2/3,'AbsTol',1e-14);verifyEqual(t,q,[1/3,2/3],'AbsTol',1e-14);
% Equal-quality incomparable objective vectors yield equal IFM weights.
[~,w]=MOCPO2025.feedback(p,[0,1],[1,2],0,[1,0],[2,1],0,c);verifyEqual(t,w,.5);
end
function testBudgetAndRepeatability(t)
p=P4Core.problem('ZDT6');
for mode=["MOCPOF","MOCPOR"]
 c=MOCPO2025.config(char(mode),100);c.N=12;c.budget=108;
 a=MOCPO2025.solve(p,c);b=MOCPO2025.solve(p,c);
 verifyEqual(t,a.evaluations,b.evaluations);verifyEqual(t,a.FE,108);verifyEqual(t,sum(a.evaluationStage==2),48);verifyEqual(t,sum(a.evaluationStage==3),48);
 verifyEqual(t,a.archive,a.evaluations(a.archiveIDs,:));verifyFalse(t,any(a.evaluationStage(a.archiveIDs)==2));
 verifyEqual(t,a.history(end,2),108);verifyTrue(t,all(a.branchAndWeightTrace(:,5)>=0 & a.branchAndWeightTrace(:,6)<=1));
end
end
function testEngineeringAndInitialization(t)
p=P4Core.problem('PPAR');p.model=PPaPaRModel.config(256);c=MOCPO2025.config('MOCPOF',3);c.N=12;c.budget=36;
a=MOCPO2025.solve(p,c);cp=P4Variants.config('DL',3);cp.N=12;cp.G=2;cp.archiveSize=12;b=P4Core.solve(p,'PACPO',cp);
verifyEqual(t,a.evaluations(1:12,:),b.evaluations(1:12,:));verifyTrue(t,all(isfinite(a.evaluations),'all'));verifyEqual(t,a.FE,36);
end
