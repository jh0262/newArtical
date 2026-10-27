classdef MOCPO2025
 % Paper-derived fixed-population implementation of Adalja et al., 2025.
 % Equations 6--9 and 11; Algorithm 1. See BASELINE_PROTOCOL.md for every
 % underdetermined choice. F/R differ only in the IFM scalar fitness mapping.
 methods(Static)
  function c=config(mode,seed)
   assert(ismember(string(mode),["MOCPOF","MOCPOR"]));
   c=struct('mode',mode,'seed',seed,'N',100,'budget',25100,'alpha',.5,'beta',.5,'gamma',.01,'delta',.5,'neighborCount',10);
  end
  function y=branch(x,g,p,b,branch,u,z,c)
   switch branch
    case 1,y=x+c.alpha*u.*(g-x); % Eq. 6
    case 2,y=x+c.beta*(p-x);     % Eq. 7
    case 3,y=x+c.gamma*z;       % Eq. 8
    case 4,y=x+c.delta*(b-x);    % Eq. 9
   end
   y=max(0,min(1,y));
  end
  function [q,w]=feedback(p,u,fu,cu,xk,fk,ck,c)
   if strcmp(c.mode,'MOCPOF')
    su=max(1e-12,mean(P4Core.normalize(p,fu),2));sk=max(1e-12,mean(P4Core.normalize(p,fk),2));
   else
    rank=P4Core.ranks([fu;fk],[cu;ck]);su=rank(1:size(fu,1));sk=rank(size(fu,1)+1:end);
   end
   w=sk./(su+sk);q=w.*u+(1-w).*xk; % Eqs. 11/12
  end
  function result=solve(p,c)
   assert(mod(c.budget-c.N,2)==0&&c.budget>c.N,'MOCPO:Budget','Budget must support complete two-evaluation offspring pairs');
   previous=rng;cl=onCleanup(@()rng(previous));rng(c.seed,'twister');timer=tic;
   n=c.N;d=p.D;m=p.M;used=n;gen=0;
   raw=zeros(c.budget,d+m+2);[y,~]=P4Core.repair(p,rand(n,d));[f,cv]=P4Core.evaluate(p,p.lb+y.*(p.ub-p.lb));
   pop=[y,f,cv,(1:n)'];raw(1:n,:)=pop;kind=zeros(c.budget,1);kind(1:n)=1;
   archive=MOCPO2025.front(p,pop);history=[0,n,MOCPO2025.getHV(p,archive)];steps=zeros(0,6);
   while used<c.budget
    gen=gen+1;k=min(n,floor((c.budget-used)/2));parents=pop(1:k,:);
    ranks=P4Core.ranks(pop(:,d+1:d+m),pop(:,end-1));first=find(ranks==1);cd=P4Core.crowding(pop(:,d+1:d+m));
    nf=P4Core.normalize(p,pop(:,d+1:d+m));dist=pdist2(nf(1:k,:),nf);[~,near]=sort(dist,2);near=near(:,1:min(c.neighborCount,n));
    u=zeros(k,d);bs=zeros(k,1);
    for i=1:k
     leader=pop(first(randi(numel(first))),1:d);rp=pop(randi(n),1:d);
     nn=near(i,:);[~,ord]=sortrows([ranks(nn),-cd(nn),nn'],[1,2,3]);local=pop(nn(ord(1)),1:d);
     bs(i)=randi(4);u(i,:)=MOCPO2025.branch(parents(i,1:d),leader,rp,local,bs(i),rand,randn(1,d),c);
    end
    [fu,cu]=P4Core.evaluate(p,p.lb+u.*(p.ub-p.lb));mid=[u,fu,cu,(used+1:used+k)'];raw(used+1:used+k,:)=mid;kind(used+1:used+k)=2;used=used+k;
    ids=randi(n,k,1);xk=pop(ids,:);[q,w]=MOCPO2025.feedback(p,u,fu,cu,xk(:,1:d),xk(:,d+1:d+m),xk(:,end-1),c);
    [fq,cq]=P4Core.evaluate(p,p.lb+q.*(p.ub-p.lb));batch=[q,fq,cq,(used+1:used+k)'];raw(used+1:used+k,:)=batch;kind(used+1:used+k)=3;used=used+k;
    joined=[pop;batch];ix=P4Core.select(joined(:,d+1:d+m),joined(:,end-1),n);pop=joined(ix,:);
    archive=MOCPO2025.front(p,pop);history(end+1,:)=[gen,used,MOCPO2025.getHV(p,archive)]; %#ok<AGROW>
    steps(end+1,:)=[sum(bs==1),sum(bs==2),sum(bs==3),sum(bs==4),min(w),max(w)]; %#ok<AGROW>
   end
   good=archive(:,end-1)==0;[igd,hv,sp]=P4Core.metrics(p,archive(good,d+1:d+m));
   result=struct('problem',p.name,'variant',c.mode,'algorithm','MOCPO2025_paper_reconstruction','config',c,'seed',c.seed, ...
    'archive',archive,'population',pop,'history',history,'FE',used,'IGD',igd,'HV',hv,'Spacing',sp,'elapsed',toc(timer));
   result.X=p.lb+archive(:,1:d).*(p.ub-p.lb);result.F=archive(:,d+1:d+m);result.CV=archive(:,end-1);result.archiveIDs=archive(:,end);
   result.evaluations=raw;result.evaluationStage=kind;result.branchAndWeightTrace=steps;
   assert(used==c.budget&&all(kind>0)&&sum(kind==2)==sum(kind==3));
  end
  function a=front(p,pop)
   f=pop(:,p.D+1:p.D+p.M);cv=pop(:,end-1);keep=~any(P4Core.dominance(f,cv),1)';a=pop(keep,:);
   [~,ix]=unique(a(:,p.D+1:p.D+p.M),'rows','stable');a=a(ix,:);
  end
  function hv=getHV(p,a)
   good=a(:,end-1)==0;hv=P4Core.hv(P4Core.normalize(p,a(good,p.D+1:p.D+p.M)),p.ref)/prod(p.ref);
  end
 end
end
