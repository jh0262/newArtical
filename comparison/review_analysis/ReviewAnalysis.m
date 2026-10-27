classdef ReviewAnalysis
 methods(Static)
 function idx=nd(f)
  % Exact minimization, with duplicate objectives represented once.
  [a,ia]=unique(f,'rows','sorted');n=size(a,1);keep=false(n,1);
  if size(a,2)==2
   best=inf;for i=1:n,if a(i,2)<best,keep(i)=true;best=a(i,2);end;end
  else
   assert(size(a,2)==3);[~,~,rank]=unique(a(:,2));k=max(rank);tree=inf(k,1);low=(1:k)-bitand(1:k,(1:k)-1);
   for i=1:n
    j=rank(i);best=inf;while j>0,best=min(best,tree(j));j=j-low(j);end
    if a(i,3)<best,keep(i)=true;end
    j=rank(i);while j<=k,tree(j)=min(tree(j),a(i,3));j=j+low(j);end
   end
  end
  idx=ia(keep);
 end
 function ix=cap(f)
  % f is unique lexicographically ordered nondominated data.
  n=size(f,1);if n<=100,ix=(1:n)';return;end
  cd=zeros(n,1);for j=1:size(f,2)
   [s,o]=sortrows([f(:,j),(1:n)'],[1 2]);r=s(end,1)-s(1,1);
   if r>0,cd(o([1,end]))=inf;cd(o(2:end-1))=cd(o(2:end-1))+(s(3:end,1)-s(1:end-2,1))/r;end
  end
  [~,o]=sortrows([-cd,(1:n)'],[1 2]);ix=sort(o(1:100));
 end
 function tests()
  old=rng;clean=onCleanup(@()rng(old));rng(2601);
  for m=2:3
   for n=[1,2,17,111]
    for tied=[false,true]
     f=rand(n,m);if tied,f=round(f*5);end
     [u,~]=unique(f,'rows');expected=u(~any(P4Core.dominance(u,zeros(size(u,1),1)),1)',:);
     assert(isequal(f(ReviewAnalysis.nd(f),:),sortrows(expected)));
    end
   end
  end
  f=[(1:150)',(150:-1:1)'];ix=ReviewAnalysis.cap(f);assert(numel(ix)==100&&ix(1)==1&&ix(end)==150&&isequal(ix,ReviewAnalysis.cap(f)));
  fprintf('Nondominance / deterministic capacity tests passed.\n');
 end
 function h=sha(path)
  md=java.security.MessageDigest.getInstance('SHA-256');fid=fopen(path,'r');c=onCleanup(@()fclose(fid));
  while ~feof(fid),md.update(fread(fid,1048576,'*uint8'));end
  h=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[]));
 end
 function extract(root,out)
  p4=fullfile(root,'MO_PACPO_创新性对照修订_20261025');addpath(fullfile(p4,'code'),fullfile(p4,'code','reference'));ReviewAnalysis.tests();
  tasks=["ZDT1","ZDT2","ZDT3","DTLZ1","DTLZ2","ZDT4","ZDT6","DTLZ3","PPAR"];fronts={};diagnosis={};counter=0;
  for t=1:9
   if t<=5,base=710000+1000*t;elseif t<=8,base=810000+1000*(t-5);else,base=400000;end
   p=P4Core.problem(tasks(t));
   for mode=["DL","MOCPOF","MOCPOR"]
    for seed=base+(1:30)
     path=fullfile(p4,'results','runs',sprintf('%s_%s_%d.mat',tasks(t),mode,seed));z=load(path,'result');r=z.result;
     a=r.evaluations;assert(size(a,1)==25100&&r.FE==25100);ok=all(isfinite(a),2)&a(:,end-1)==0;ix=find(ok);ix=ix(ReviewAnalysis.nd(a(ix,p.D+1:p.D+p.M)));
     native=r.F(r.CV==0,:);native=native(ReviewAnalysis.nd(native),:);[ig,hv]=P4Core.metrics(p,native);
     assert(abs(hv-r.HV)<1e-10);if isfinite(r.IGD),assert(abs(ig-r.IGD)<1e-9*max(1,abs(ig)));end
     counter=counter+1;fronts{counter}=struct('problem',char(tasks(t)),'variant',char(mode),'seed',seed,'FE',r.FE,'ndF',a(ix,p.D+1:p.D+p.M),'ndIDs',a(ix,end),'nativeF',native,'source',strrep(path,[root,filesep],''),'sha256',ReviewAnalysis.sha(path),'feasibleCount',nnz(ok),'ndCount',numel(ix));
     if t==9&&mode=="DL"
      g=r.gateTrace;d=r.diagnostic;o=r.operatorTrace;
      diagnosis{seed-base}=struct('Seed',seed,'FeasibleFraction',nnz(ok)/25100,'StagnationEligibleGenerations',sum(g(:,1)>0),'LowVarianceEligibleGenerations',sum(g(:,2)>0),'PulseGenerations',sum(g(:,5)>0),'EarlyVariance',mean(d(1:50,6)),'LateVariance',mean(d(end-49:end,6)),'EarlyStepRMS',mean(d(1:50,5)),'LateStepRMS',mean(d(end-49:end,5)),'LateNoiseMasked',mean(o(end-49:end,6)),'LateDifferenceMasked',mean(o(end-49:end,5)));
     end
    end
   end
   fprintf('%s: complete native checks and common-front extraction (%d records).\n',tasks(t),counter);
  end
  fronts=vertcat(fronts{:});diagnosis=vertcat(diagnosis{:});save(fullfile(out,'common_front_inputs.mat'),'fronts','diagnosis','-v7');
  ReviewAnalysis.extractDecisions(root,out);
 end
 function extractDecisions(root,out)
  % Fine final sets; archived objective values, no objective evaluation calls.
  p4=fullfile(root,'MO_PACPO_创新性对照修订_20261025');p1=fullfile(root,'MO_PACPO_P1修正版_20261024');p5=fullfile(root,'MO_PACPO_Machines_P1联合对照修订_20261025');oldpath=fullfile(root,'MO_PACPO_机构模型修正版_20261023','results','physical_summary_data.mat');old=load(oldpath,'runs','refined');oldhash=ReviewAnalysis.sha(oldpath);designs={};c=0;
  for mode=["Full","NSGAII","MOEAD","MOPSO","GDE3","joint","MOCPOF","MOCPOR"]
   for seed=400001:400030
    if ismember(mode,["MOEAD","MOPSO"])
     q=find(string(old.runs.Algorithm)==mode&old.runs.Seed==seed);assert(isscalar(q));r=old.refined{q};f=r.F;x=r.X;cv=r.CV;path=oldpath;sha=oldhash;
    else
     if mode=="Full",path=fullfile(p4,'validation',sprintf('PPAR_DL_%d.mat',seed));
     elseif ismember(mode,["MOCPOF","MOCPOR"]),path=fullfile(p4,'validation',sprintf('PPAR_%s_%d.mat',mode,seed));
     elseif mode=="joint",path=fullfile(p5,'validation',sprintf('PPAR_joint_%d.mat',seed));
     else,path=fullfile(p1,'validation',sprintf('archive_%s_%d.mat',mode,seed));end
     r=load(path,'X','allF','allCV');x=r.X;f=r.allF{1};cv=r.allCV{1};sha=ReviewAnalysis.sha(path);
    end
    ok=all(isfinite(f),2)&cv==0;ix=find(ok);ix=ix(ReviewAnalysis.nd(f(ix,:)));assert(~isempty(ix));c=c+1;
    designs{c}=struct('variant',char(mode),'seed',seed,'X',x(ix,:),'F',f(ix,:),'source',strrep(path,[root,filesep],''),'sha256',sha);
   end
  end
  designs=vertcat(designs{:});save(fullfile(out,'decision_inputs.mat'),'designs','-v7');ReviewAnalysis.recompute(out);
 end
 function recompute(out)
  z=load(fullfile(out,'common_front_inputs.mat'));fronts=z.fronts;ReviewAnalysis.tests();rows=cell(numel(fronts),1);
  for i=1:numel(fronts)
   r=fronts(i);p=P4Core.problem(r.problem);
   if isfield(r,'selectedF'),common=r.selectedF;else,idx=ReviewAnalysis.cap(r.ndF);common=r.ndF(idx,:);end
   [ig,hv]=P4Core.metrics(p,common);[ni,nh]=P4Core.metrics(p,r.nativeF);
   rows{i}=table(string(r.problem),string(r.variant),r.seed,r.FE,r.feasibleCount,r.ndCount,size(common,1),ig,hv,ni,nh,'VariableNames',{'Problem','Variant','Seed','FE','FeasibleCount','AllNondominatedCount','CommonCount','IGD','HV','NativeIGD','NativeHV'});
  end
  runs=vertcat(rows{:});writetable(runs,fullfile(out,'common_front_runs.csv'));su=groupsummary(runs,{'Problem','Variant'},{'mean','std'},{'IGD','HV','NativeIGD','NativeHV','AllNondominatedCount'});writetable(su,fullfile(out,'common_front_summary.csv'));
  parts={};oldrng=rng;cl=onCleanup(@()rng(oldrng));rng(2601026);
  for task=unique(runs.Problem,'stable')'
   a=sortrows(runs(runs.Problem==task&runs.Variant=="DL",:),'Seed');
   for mode=["MOCPOF","MOCPOR"]
    b=sortrows(runs(runs.Problem==task&runs.Variant==mode,:),'Seed');assert(isequal(a.Seed,b.Seed));
    for metric=["IGD","HV"]
     if task=="PPAR"&&metric=="IGD",continue;end
     direction=1;if metric=="IGD",direction=-1;end
     row=struct2table(P4Stats.paired(a.(metric),b.(metric),direction));delta=a.(metric)-b.(metric);bs=mean(delta(randi(30,30,10000)),1);ci=prctile(bs,[2.5,97.5]);row.CILow=ci(1);row.CIHigh=ci(2);row.Problem=task;row.Comparator=mode;row.Metric=metric;parts{end+1}=row;
    end
   end
  end
  stats=vertcat(parts{:});stats.HolmP=nan(height(stats),1);
  for eng=[false,true],for metric=["IGD","HV"],ix=find((stats.Problem=="PPAR")==eng&stats.Metric==metric);if ~isempty(ix),stats.HolmP(ix)=P4Core.holm(stats.RawP(ix));end;end;end
  writetable(stats,fullfile(out,'common_front_statistics.csv'));writetable(struct2table(z.diagnosis),fullfile(out,'engineering_diagnostics.csv'));
  z=load(fullfile(out,'decision_inputs.mat'));ds=z.designs;X=vertcat(ds.X);F=vertcat(ds.F);[ux,ia,ic]=unique(X,'rows');uf=F(ia,:);assert(max(abs(F-uf(ic,:)),[],'all')<1e-8);p=P4Core.problem('PPAR');q=P4Core.normalize(p,uf);norms=sqrt(sum(q.^2,1));v=q./norms/3;ideal=min(v);nadir=max(v);record=cell(numel(ds),1);
  for i=1:numel(ds)
   d=ds(i);q=P4Core.normalize(p,d.F)./norms/3;dp=sqrt(sum((q-ideal).^2,2));dn=sqrt(sum((q-nadir).^2,2));scores=dn./max(dp+dn,eps);[~,ix]=sortrows([-scores,d.X],1:5);j=ix(1);
   record{i}=table(string(d.variant),d.seed,d.X(j,1),d.X(j,2),d.X(j,3),d.X(j,4),-d.F(j,1),d.F(j,2),-d.F(j,3),scores(j),'VariableNames',{'Variant','Seed','a','b','c','d','Volume','Error','GCI','Score'});
  end
  selected=vertcat(record{:});writetable(selected,fullfile(out,'common_decision_runs.csv'));parts={};
  for mode=unique(selected.Variant,'stable')'
   a=selected(selected.Variant==mode,:);s=struct('Variant',mode,'N',height(a));
   for name=["Volume","Error","GCI","Score"],v=a.(name);qt=prctile(v,[25,50,75]);s.(name+"Q1")=qt(1);s.(name+"Median")=qt(2);s.(name+"Q3")=qt(3);end
   parts{end+1}=struct2table(s);
  end
  writetable(vertcat(parts{:}),fullfile(out,'common_decision_summary.csv'));
  decision_basis=struct('uniqueCandidateCount',size(ux,1),'candidateCount',size(X,1),'origin',p.lower,'scale',p.scale,'columnNorms',norms,'idealWeighted',ideal,'nadirWeighted',nadir,'weights',[1,1,1]/3,'integrationPoints',262144);
  writelines(jsonencode(decision_basis,'PrettyPrint',true),fullfile(out,'common_decision_basis.json'));
  fprintf('Recomputed 810 common-front and 240 per-run engineering decisions; zero optimizer searches or new objective evaluations.\n');
 end
 function exportCompact(out,dest)
  if ~isfolder(dest),mkdir(dest);end
  z=load(fullfile(out,'common_front_inputs.mat'));fronts=z.fronts;diagnosis=z.diagnosis;
  for k=1:numel(fronts),ix=ReviewAnalysis.cap(fronts(k).ndF);fronts(k).selectedF=fronts(k).ndF(ix,:);fronts(k).selectedIDs=fronts(k).ndIDs(ix);end
  fronts=rmfield(fronts,{'ndF','ndIDs'});save(fullfile(dest,'common_front_inputs.mat'),'fronts','diagnosis','-v7');
  copyfile(fullfile(out,'decision_inputs.mat'),fullfile(dest,'decision_inputs.mat'));ReviewAnalysis.recompute(dest);
  for f=["common_front_runs","common_front_summary","common_front_statistics","engineering_diagnostics","common_decision_runs","common_decision_summary"]
   a=readtable(fullfile(out,f+".csv"));b=readtable(fullfile(dest,f+".csv"));assert(isequaln(a,b),'Compact recomputation differs: %s',f);
  end
  fprintf('Compact selected-front calculations exactly match complete-front calculations.\n');
 end
 end
end
