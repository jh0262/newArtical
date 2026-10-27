function analyze_joint
R=fileparts(mfilename('fullpath'));addpath(fullfile(R,'code'),fullfile(R,'code','reference'));
P5Experiment.root(R);frozen=load(fullfile(R,'freeze.mat'),'source');assert(isequal(frozen.source,P5Experiment.source()));
tasks=["ZDT6","DTLZ3","PPAR"];modes=["Full","noNoise","noLock","joint"];records={};curves={};gates={};checks={};
for task=tasks
 if task=="ZDT6",base=812000;elseif task=="DTLZ3",base=813000;else,base=400000;end
 for seed=base+(1:30)
  first=load(fullfile(R,'results','runs',sprintf('%s_Full_%d.mat',task,seed)),'result');
  for mode=modes
   id=sprintf('%s_%s_%d',task,mode,seed);state=jsondecode(fileread(fullfile(R,'results','runs',[id,'_status.json'])));assert(state.ok);
   z=load(fullfile(R,'results','runs',[id,'.mat']));a=z.result;assert(a.FE==25100);
   assert(strcmp(a.initialSHA256,first.result.initialSHA256));
   assert(numel(a.CV)==size(a.F,1)&&numel(a.archiveIDs)==size(a.F,1)&&all(a.archiveIDs>=1&a.archiveIDs<=a.FE));
   assert(isequal(a.config,P5Variants.config(mode,seed)));
   if mode=="joint",assert(all(a.history(:,4)==0)&&all(a.operatorTrace(:,[3,6,8])==0,'all'));end
   pulses=sum(a.history(:,4));noiseRMS=mean(a.operatorTrace(:,6));pulseRMS=mean(a.operatorTrace(:,8));
   if task=="PPAR",points=[262144,1048576];v=load(fullfile(R,'validation',[id,'.mat']));assert(isequal(v.X,a.X));else,points=0;end
   for j=1:numel(points)
    [igd,hv,sp]=P5Core.metrics(P5Core.problem(task),a.F(a.CV==0,:));count=a.archiveSize;
    if points(j)>0
     keep=v.allCV{j}==0&~any(P5Core.dominance(v.allF{j},v.allCV{j}),1)';assert(isequal(keep,v.allKeep{j}));
     [igd,hv,sp]=P5Core.metrics(P5Core.problem(task),v.allF{j}(keep,:));
     assert(isequaln(hv,v.hv(j))&&isequaln(sp,v.sp(j)));count=sum(keep);
    end
    kind=string(a.sourceKind);records{end+1}=table(task,mode,seed,points(j),a.FE,igd,hv,sp,count,pulses,noiseRMS,pulseRMS,a.elapsed,kind,...
     'VariableNames',{'Problem','Variant','Seed','IntegrationPoints','FE','IGD','HV','SP','ArchiveSize','Pulses','NoiseRMS','PulseRMS','Seconds','SourceKind'}); %#ok<AGROW>
   end
   h=a.history;curves{end+1}=table(repmat(task,size(h,1),1),repmat(mode,size(h,1),1),repmat(seed,size(h,1),1),h(:,1),h(:,2),h(:,3),h(:,4),'VariableNames',{'Problem','Variant','Seed','Generation','FE','HV','Pulse'}); %#ok<AGROW>
   checks{end+1}=table(task,mode,seed,string(a.sourceKind),a.FE,pulses,'VariableNames',{'Problem','Variant','Seed','SourceKind','FE','Pulses'}); %#ok<AGROW>
  end
 end
end
runs=vertcat(records{:});curves=vertcat(curves{:});writetable(runs,fullfile(R,'data','joint_runs.csv'));writetable(curves,fullfile(R,'data','joint_curves.csv'));writetable(vertcat(checks{:}),fullfile(R,'audit','run_checks.csv'));
summary=groupsummary(runs,{'Problem','Variant','IntegrationPoints'},{'mean','std','median'},{'IGD','HV','SP','Pulses','NoiseRMS','PulseRMS','Seconds'});writetable(summary,fullfile(R,'data','joint_summary.csv'));
previous=rng;cl=onCleanup(@()rng(previous));rng(20261025,'twister');boot=randi(30,30,20000);writematrix(boot,fullfile(R,'data','bootstrap_indices.csv'));
names=["Full_joint","Full_noNoise","Full_noLock","noLock_joint","noNoise_joint","Interaction"];parts={};
for task=tasks
 if task=="PPAR",points=[262144,1048576];metrics=["HV","SP"];else,points=0;metrics=["IGD","HV","SP"];end
 for point=points
  q=runs(runs.Problem==task & runs.IntegrationPoints==point,:);
  for metric=metrics
   v=zeros(30,4);
   for m=1:4,t=sortrows(q(q.Variant==modes(m),:),'Seed');assert(height(t)==30);v(:,m)=t.(metric);end
   av=[v(:,1),v(:,1),v(:,1),v(:,3),v(:,2),v(:,1)-v(:,2)];bv=[v(:,4),v(:,2),v(:,3),v(:,4),v(:,4),v(:,3)-v(:,4)];family={};
   direction=1;if metric~="HV",direction=-1;end
   for j=1:6
    a=av(:,j);b=bv(:,j);assert(all(isfinite(a)&isfinite(b)));d=a-b;
    s=struct2table(P5Stats.paired(a,b,direction));ci=prctile(mean(d(boot),1),[2.5,97.5]);s.CILow=ci(1);s.CIHigh=ci(2);s.Positive=sum(d>0);s.Negative=sum(d<0);s.Zero=sum(d==0);
    s.RelativeDifferencePercent=100*mean(d)/mean(b);if j==6,s.RelativeDifferencePercent=NaN;end
    s.Problem=task;s.IntegrationPoints=point;s.Metric=metric;s.Contrast=names(j);family{end+1}=s; %#ok<AGROW>
   end
   t=vertcat(family{:});t.HolmP=P5Core.holm(t.RawP);parts{end+1}=t; %#ok<AGROW>
  end
 end
end
statistics=vertcat(parts{:});writetable(statistics,fullfile(R,'data','joint_statistics.csv'));save(fullfile(R,'data','analysis.mat'),'runs','summary','statistics','boot','-v7');
audit=struct('newSearches',90,'reusedExactReplays',270,'newSearchFE',2259000,'allBudgetsExact',true,'allInitializationsPaired',true,'compactArchiveChecks',true,'fullSourcesStoredOnce',true,'runRows',height(runs),'contrastRows',height(statistics));
P5Experiment.json(fullfile(R,'audit','analysis_validation.json'),audit);
disp(statistics(statistics.Contrast=="Full_joint"|statistics.Contrast=="Interaction",:));
end
