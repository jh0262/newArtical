function analyze_mechanisms
R=fileparts(mfilename('fullpath'));addpath(fullfile(R,'code'),fullfile(R,'code','reference'));
P=fullfile(fileparts(R),'MO_PACPO_P1修正版_20261024');modes=["revised","Diagonal","noNoise","noLock"];
z=load(fullfile(R,'freeze.mat'),'source');assert(isequal(z.source,P3Experiment.source()));
runs={};ops={};curves={};trace=cell(30,3);aud=struct('fullReplays',0,'newRuns',0,'evaluationBudget',25100,'pairedInitialization',true,'compactArchiveChecks',true,'modelIdentical',true);
for i=1:4
 for k=1:30
  seed=400000+k;id=sprintf('PPAR_%s_%d',modes(i),seed);
  if i<4
   stat=jsondecode(fileread(fullfile(R,'results','runs',[id,'_status.json'])));assert(stat.ok);
   f=fullfile(R,'results','runs',[id,'.mat']);d=load(f,'result');
   v=load(fullfile(R,'validation',[id,'.mat']));
   if i==1,aud.fullReplays=aud.fullReplays+1;else,aud.newRuns=aud.newRuns+1;end
  else
   f=fullfile(P,'results','runs',[id,'.mat']);d=load(f,'result');v=load(fullfile(P,'validation',sprintf('archive_noLock_%d.mat',seed)));
  end
  a=d.result;assert(a.FE==25100&&numel(a.CV)==size(a.F,1)&&numel(a.archiveIDs)==size(a.F,1)&&all(a.archiveIDs>=1&a.archiveIDs<=a.FE)&&isequal(a.X,v.X));
  searchSeconds=a.elapsed;replaySeconds=NaN;sourceKind="new_search";
  if i==1
   original=load(fullfile(fileparts(R),'MO_PACPO_搜索机制改进_20261024','results','physical',sprintf('PPAR_candidate_%d.mat',seed)),'result');
   searchSeconds=original.result.elapsed;replaySeconds=a.elapsed;sourceKind="reused_full_with_tape_replay";
  elseif i==4,sourceKind="reused_noLock";end
  base=load(fullfile(R,'results','runs',sprintf('PPAR_revised_%d.mat',seed)),'result');assert(strcmp(a.initialSHA256,base.result.initialSHA256));
  for j=1:2
   p=P3Core.problem('PPAR');keep=v.allCV{j}==0&~any(P3Core.dominance(v.allF{j},v.allCV{j}),1)';assert(isequal(keep,v.allKeep{j}));
   [~,hv,sp]=P3Core.metrics(p,v.allF{j}(keep,:));assert(isequaln(hv,v.hv(j))&&isequaln(sp,v.sp(j)));
   runs{end+1}=table(modes(i),seed,262144*4^(j-1),a.FE,hv,sp,sum(a.history(:,4)),searchSeconds,replaySeconds,sourceKind, ...
       'VariableNames',{'Variant','Seed','IntegrationPoints','FE','HV','SP','PulseGenerations','OriginalSearchSeconds','ReplaySeconds','SourceKind'}); %#ok<AGROW>
  end
  for g=1:size(a.history,1)
   curves{end+1}=table(modes(i),seed,a.history(g,1),a.history(g,2),a.history(g,3),'VariableNames',{'Variant','Seed','Generation','FE','HV'}); %#ok<AGROW>
  end
  if i<4
   t=a.operatorTrace;assert(all(isfinite(t),'all'));if i==3,assert(all(t(:,3)==0 & t(:,6)==0));end
   assert(all(t(:,12)>=.25&t(:,12)<=1));trace{k,i}=t;
   for g=1:250
    row=array2table(t(g,:),'VariableNames',a.operatorColumns);row.Variant=modes(i);row.Seed=seed;row.Generation=g;ops{end+1}=row; %#ok<AGROW>
   end
  end
 end
end
runs=vertcat(runs{:});writetable(runs,fullfile(R,'data','runs.csv'));
summary=groupsummary(runs,{'Variant','IntegrationPoints'},{'mean','std','median'},{'HV','SP','PulseGenerations'});writetable(summary,fullfile(R,'data','summary.csv'));
curves=vertcat(curves{:});writetable(curves,fullfile(R,'data','curves.csv'));ops=vertcat(ops{:});writetable(ops,fullfile(R,'data','operator_trace.csv'));
stats={};
for points=[262144,1048576]
 a=sortrows(runs(runs.Variant=="revised"&runs.IntegrationPoints==points,:),'Seed');parts={};
 for mode=modes(2:end)
  b=sortrows(runs(runs.Variant==mode&runs.IntegrationPoints==points,:),'Seed');assert(isequal(a.Seed,b.Seed));
  for met=["HV","SP"]
   direction=1;if met=="SP",direction=-1;end
   s=struct2table(P3Stats.paired(a.(met),b.(met),direction));s.Comparator=mode;s.Metric=met;s.IntegrationPoints=points;
   delta=a.(met)-b.(met);delta=delta(isfinite(delta));s.Positive=sum(delta>0);s.Negative=sum(delta<0);s.Zero=sum(delta==0);
   s.RelativeGainPercent=100*s.MeanDifference/mean(b.(met),'omitnan');
   rng(20261025,'twister');ix=randi(numel(delta),numel(delta),20000);ci=prctile(mean(delta(ix),1),[2.5,97.5]);s.CILow=ci(1);s.CIHigh=ci(2);parts{end+1}=s; %#ok<AGROW>
   if numel(delta)==30,writematrix(ix,fullfile(R,'data','bootstrap_indices.csv'));end
  end
 end
 stats{end+1}=P3Stats.adjust(vertcat(parts{:})); %#ok<AGROW>
end
stats=vertcat(stats{:});writetable(stats,fullfile(R,'data','paired_statistics.csv'));
phaseNames=["early","middle","late","all"];ranges={[1,50],[51,150],[151,250],[1,250]};phaseRows={};
for i=1:3
 for k=1:30
  t=trace{k,i};
  for j=1:4
   v=t(ranges{j}(1):ranges{j}(2),:);rr=sqrt(mean(v(:,1:11).^2,1));
   q=array2table(rr,'VariableNames',ops.Properties.VariableNames(1:11));q.Variant=modes(i);q.Seed=400000+k;q.Phase=phaseNames(j);
   q.NoiseToCombinedPercent=100*rr(6)/rr(7);q.MeanMask=mean(v(:,12));q.MeanSigma=mean(v(:,13));phaseRows{end+1}=q; %#ok<AGROW>
  end
 end
end
phaseRows=vertcat(phaseRows{:});writetable(phaseRows,fullfile(R,'data','operator_phases.csv'));
P3Experiment.json(fullfile(R,'audit','run_validation.json'),aud);
save(fullfile(R,'data','analysis.mat'),'runs','summary','stats','trace','aud','phaseRows','-v7');disp(stats(stats.Metric=="HV",:));
end
