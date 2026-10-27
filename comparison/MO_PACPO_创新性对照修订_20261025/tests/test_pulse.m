function tests=test_pulse
tests=functiontests(localfunctions);
end
function setupOnce(t)
r=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(r,'code'),fullfile(r,'code','reference'));
old=fullfile(fileparts(r),'MO_PACPO_机构消融与P1修订_20261024');addpath(fullfile(old,'code'));t.TestData.root=r;
end
function testNormAndDirection(t)
c=P4Variants.config('DL',100);V=eye(4);P=diag([1,0,0,0]);lambda=[.001;1;2;3];
rng(100);[a,rows,ap,ld,g]=P4Pulse.draw(V,P,lambda,c,.1,6,100,4);rs=rng;
c.pulseDirection='random';rng(100);[b,rb,bp,bd,h]=P4Pulse.draw(V,P,lambda,c,.1,6,100,4);rt=rng;
verifyEqual(t,rs,rt);verifyEqual(t,rows,rb);verifyTrue(t,ap&&bp);verifyEqual(t,ld,bd);
verifyEqual(t,vecnorm(a,2,2),vecnorm(b,2,2),'AbsTol',1e-14);verifyEqual(t,a(:,2:4),zeros(10,3));verifyGreaterThan(t,norm(b(:,2:4),'fro'),0);
verifyEqual(t,g(6:7),h(6:7),'AbsTol',1e-14);
rng(100);b2=P4Pulse.draw(V,P,lambda,c,.1,6,100,4);verifyEqual(t,b,b2);
end
function testTriggerTruthTable(t)
for trigger=["double","single"]
 for hv=[false,true]
  for low=[false,true]
   c=P4Variants.config('DL',90);c.pulseTrigger=char(trigger);V=eye(4);lambda=ones(4,1);if low,lambda(1)=0;end
   P=diag([double(low),0,0,0]);[s,~,ap,~,g]=P4Pulse.draw(V,P,lambda,c,1,double(hv)*5,100,4);
   verifyEqual(t,ap,hv&&(low||trigger=="single"));verifyEqual(t,g(1:2),double([hv,low]));
   if ap,verifyEqual(t,size(s),[10,4]);end
  end
 end
end
end
function testOriginalProposalIdentity(t)
p=P4Core.problem('ZDT6');c=P4Variants.config('DL',3);cp=P3Variants.config('revised',3);
rng(7);pop=[rand(100,p.D),zeros(100,p.M+2)];archive=pop;archive(:,1)=.4;st=struct('sigma',.3,'success',.2);
for stagnation=[0,6]
 rng(9);[a,sa,pa,la]=P3Mechanism.propose(p,pop,archive,cp,st,1,stagnation);ra=rng;
 rng(9);[b,sb,pb,lb]=P4Mechanism.propose(p,pop,archive,c,st,1,stagnation);rb=rng;
 verifyEqual(t,a,b);verifyEqual(t,pa,pb);verifyEqual(t,la,lb);verifyEqual(t,ra,rb);sb=rmfield(sb,'gates');verifyEqual(t,sa,sb);
end
end
function testSmokeAndBudget(t)
for task=["ZDT6","PPAR"]
 p=P4Core.problem(task);if task=="PPAR",p.model=PPaPaRModel.config(256);end
 for mode=["DL","DR","SL","SR"]
  c=P4Variants.config(mode,300);c.N=12;c.G=8;c.archiveSize=12;c.window=1;c.hvTolerance=10;c.progressLock=false;
  z=P4Core.solve(p,'PACPO',c);verifyEqual(t,z.FE,108);verifyEqual(t,z.archive,z.evaluations(z.archiveIDs,:));verifyTrue(t,all(isfinite(z.evaluations),'all'));
  verifyGreaterThanOrEqual(t,z.X,p.lb-1e-10);verifyLessThanOrEqual(t,z.X,p.ub+1e-10);
 end
end
end
function testFullReplay(t)
r=t.TestData.root;z=load(fullfile(fileparts(r),'MO_PACPO_机构消融与P1修订_20261024','results','runs','PPAR_revised_400001.mat'),'result');
P4Tape.store('set',z.result.evaluations);cl=onCleanup(@()P4Tape.store('clear',[]));
a=P4Core.solve(P4Core.problem('PPAR'),'PACPO',P4Variants.config('DL',400001));
for f=["evaluations","history","archive","population","HV","Spacing"],verifyEqual(t,a.(f),z.result.(f));end
end
