function analyze_innovation
R=fileparts(mfilename('fullpath'));addpath(fullfile(R,'code'),fullfile(R,'code','reference'));
tasks=["ZDT1","ZDT2","ZDT3","DTLZ1","DTLZ2","ZDT4","ZDT6","DTLZ3","PPAR"];
modes=["DL","DR","SL","SR","MOCPOF","MOCPOR"];
z=load(fullfile(R,'freeze.mat'),'source');assert(isequal(z.source,P4Experiment.source()));
base=load(fullfile(R,'baseline_freeze.mat'),'source');assert(isequal(base.source,MOCPOExperiment.source()));
records={};curves={};gates={};origins={};identities={};
for task=tasks
 k=find(tasks==task);if k==9,seedBase=400000;elseif k<=5,seedBase=710000+1000*k;else,seedBase=810000+1000*(k-5);end
 for seed=seedBase+(1:30)
  dl=load(fullfile(R,'results','runs',sprintf('%s_DL_%d.mat',task,seed)),'result');
  dr=[];
  for mode=modes
   id=sprintf('%s_%s_%d',task,mode,seed);path=fullfile(R,'results','runs',[id,'.mat']);
   state=jsondecode(fileread(fullfile(R,'results','runs',[id,'_status.json'])));assert(state.ok,'P4:MissingRun','%s failed',id);
   zz=load(path,'result');a=zz.result;
   
   assert(a.FE==25100&&numel(a.CV)==size(a.F,1)&&numel(a.archiveIDs)==size(a.F,1)&&all(a.archiveIDs>=1&a.archiveIDs<=a.FE));
   assert(strcmp(a.initialSHA256,dl.result.initialSHA256),'P4:Init','Initialization differs');
   if mode=="DR",dr=a;end
   if mode=="SL"||mode=="SR"
    if mode=="SL",first=dl.result;pair="DL_SL";else,first=dr;pair="DR_SR";end
    identities{end+1}=table(task,seed,pair,strcmp(a.evaluationSHA256,first.evaluationSHA256),isequal(a.history,first.history),strcmp(a.archiveSHA256,first.archiveSHA256),'VariableNames',{'Problem','Seed','Pair','EvaluationsIdentical','HistoryIdentical','ArchiveIdentical'}); %#ok<AGROW>
   end
   pulses=0;hEligible=NaN;lEligible=NaN;hWithoutL=NaN;normError=NaN;
   if isfield(a,'gateTrace')
    gt=a.gateTrace;pulses=sum(gt(:,5));hEligible=sum(gt(:,1));lEligible=sum(gt(:,2));hWithoutL=sum(gt(:,1)==1 & gt(:,2)==0);normError=max(abs(gt(:,6)-gt(:,7)));
    ng=size(gt,1);gates{end+1}=table(repmat(task,ng,1),repmat(mode,ng,1),repmat(seed,ng,1),(1:ng)',gt(:,1),gt(:,2),gt(:,3),gt(:,4),gt(:,5),gt(:,6),gt(:,7),'VariableNames',{'Problem','Variant','Seed','Generation','HVGate','LowGate','LowDimension','EffectiveDimension','Pulse','NormBefore','NormAfter'}); %#ok<AGROW>
   end
   if task=="PPAR"
    v=load(fullfile(R,'validation',[id,'.mat']));assert(isequal(v.X,a.X));points=[262144,1048576];
   else,points=0;end
   for j=1:numel(points)
    [igd,hv,sp]=P4Core.metrics(P4Core.problem(task),a.F(a.CV==0,:));count=a.archiveSize;
    if points(j)>0
     keep=v.allCV{j}==0&~any(P4Core.dominance(v.allF{j},v.allCV{j}),1)';assert(isequal(keep,v.allKeep{j}));
     [igd,hv,sp]=P4Core.metrics(P4Core.problem(task),v.allF{j}(keep,:));assert(isequaln(hv,v.hv(j))&&isequaln(sp,v.sp(j)));count=sum(keep);
    end
    kind="new_search";if mode=="DL",kind="reused_exact_replay";end
    records{end+1}=table(task,mode,seed,points(j),a.FE,igd,hv,sp,count,pulses,hEligible,lEligible,hWithoutL,normError,a.elapsed,kind, ...
     'VariableNames',{'Problem','Variant','Seed','IntegrationPoints','FE','IGD','HV','SP','ArchiveSize','Pulses','HVEligible','LowEligible','HVWithoutLow','NormMatchError','Seconds','SourceKind'}); %#ok<AGROW>
   end
   ng=size(a.history,1);curves{end+1}=table(repmat(task,ng,1),repmat(mode,ng,1),repmat(seed,ng,1),a.history(:,1),a.history(:,2),a.history(:,3),'VariableNames',{'Problem','Variant','Seed','Generation','FE','HV'}); %#ok<AGROW>
   origins{end+1,1}=path; %#ok<AGROW>
  end
 end
end
runs=vertcat(records{:});curves=vertcat(curves{:});gates=vertcat(gates{:});
writetable(runs,fullfile(R,'data','runs.csv'));writetable(curves,fullfile(R,'data','curves.csv'));writetable(gates,fullfile(R,'data','gate_trace.csv'));writetable(vertcat(identities{:}),fullfile(R,'data','trajectory_pairs.csv'));
summary=groupsummary(runs,{'Problem','Variant','IntegrationPoints'},{'mean','std','median'},{'IGD','HV','SP','Pulses','HVWithoutLow','Seconds'});writetable(summary,fullfile(R,'data','summary.csv'));
previous=rng;cl=onCleanup(@()rng(previous));rng(20261025,'twister');boot=randi(30,30,20000);writematrix(boot,fullfile(R,'data','bootstrap_indices.csv'));
factor={};external={};contrastNames=["DirectionDouble","DirectionSingle","TriggerLow","TriggerRandom","Interaction"];
for task=tasks
 if task=="PPAR",points=[262144,1048576];metrics=["HV","SP"];else,points=0;metrics=["IGD","HV","SP"];end
 for point=points
  q=runs(runs.Problem==task & runs.IntegrationPoints==point,:);
  for metric=metrics
   v=zeros(30,6);for m=1:6,t=sortrows(q(q.Variant==modes(m),:),'Seed');assert(height(t)==30);v(:,m)=t.(metric);end
   direction=1;if metric~="HV",direction=-1;end
   av=[v(:,1),v(:,3),v(:,1),v(:,2),v(:,1)-v(:,2)];bv=[v(:,2),v(:,4),v(:,3),v(:,4),v(:,3)-v(:,4)];part={};
   for j=1:5
    s=contrast(av(:,j),bv(:,j),direction,boot);s.Problem=task;s.Metric=metric;s.IntegrationPoints=point;s.Contrast=contrastNames(j);
    if j==5,s.RelativeGainPercent=NaN;end
    part{end+1}=s; %#ok<AGROW>
   end
   t=vertcat(part{:});t.HolmP=holmsafe(t.RawP);factor{end+1}=t; %#ok<AGROW>
   for j=5:6
    s=contrast(v(:,1),v(:,j),direction,boot);s.Problem=task;s.Metric=metric;s.IntegrationPoints=point;s.Comparator=modes(j);external{end+1}=s; %#ok<AGROW>
   end
  end
 end
end
factor=vertcat(factor{:});external=vertcat(external{:});external.HolmP=nan(height(external),1);
for metric=["IGD","HV","SP"]
 idx=external.Problem~="PPAR"&external.Metric==metric;external.HolmP(idx)=holmsafe(external.RawP(idx));
 for point=[262144,1048576]
  idx=external.Problem=="PPAR"&external.Metric==metric&external.IntegrationPoints==point;
  if any(idx),external.HolmP(idx)=holmsafe(external.RawP(idx));end
 end
end
writetable(factor,fullfile(R,'data','factorial_statistics.csv'));writetable(external,fullfile(R,'data','mocpo_statistics.csv'));
save(fullfile(R,'data','analysis.mat'),'runs','summary','factor','external','boot','origins','-v7');
audit=struct('newSearches',1350,'reusedExactReplays',270,'newFE',1350*25100,'allBudgetsExact',true,'allInitializationsPaired',true,'compactArchiveChecks',true,'fullSourcesStoredOnce',true,'runRows',height(runs));
P4Experiment.json(fullfile(R,'audit','analysis_validation.json'),audit);
disp(factor(factor.Problem=="PPAR"&factor.Metric=="HV",:));disp(external(external.Problem=="PPAR"&external.Metric=="HV",:));
end
function q=holmsafe(p)
bad=~isfinite(p);p(bad)=1;q=P4Core.holm(p);q(bad)=NaN;
end
function t=contrast(a,b,direction,boot)
t=struct2table(P4Stats.paired(a,b,direction));good=isfinite(a)&isfinite(b);delta=a(good)-b(good);n=numel(delta);
if n>0
 if n~=30
  stream=RandStream('mt19937ar','Seed',20261025);boot=randi(stream,n,n,20000);
  writematrix(boot,fullfile(fileparts(mfilename('fullpath')),'data',sprintf('bootstrap_indices_n%d.csv',n)));
 end
 ci=prctile(mean(delta(boot),1),[2.5,97.5]);relative=100*mean(delta)/mean(b(good));
else,ci=[NaN,NaN];relative=NaN;end
t.CILow=ci(1);t.CIHigh=ci(2);t.Positive=sum(delta>0);t.Negative=sum(delta<0);t.Zero=sum(delta==0);t.RelativeGainPercent=relative;
end
