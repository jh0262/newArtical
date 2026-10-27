function evidence=summarize_physical()
% Equal-resolution reevaluation of ALL final archives, then statistics/decisions.
root=fileparts(mfilename('fullpath')); addpath(root); out=fullfile(root,'results');
completion=jsondecode(fileread(fullfile(out,'completion.json')));
assert(completion.passed==120,'The full physical experiment must finish first');
load(fullfile(out,'configuration.mat'),'p','jobs');
fine=PPaPaRModel.config(262144); checkpoint=fullfile(out,'refined_archives.mat');
if isfile(checkpoint)
    cached=load(checkpoint); refined=cached.refined; records=cached.records; histories=cached.histories;
else
refined=cell(120,1); records=cell(120,1); histories=zeros(120,251);
parfor i=1:120
    z=load(fullfile(out,'runs',[jobs(i).id,'.mat']),'result'); r=z.result;
    assert(r.FE==25100 && size(r.evaluations,1)==25100,'Budget mismatch');
    assert(isequal(r.archive,r.evaluations(r.archiveIDs,:)),'Archive does not trace to saved evaluations');
    assert(isequal(r.history(:,2),(1:251)'*100),'History budget mismatch');
    [ff,cc]=PPaPaRModel.evaluate(r.X,p.model);
    assert(max(abs(ff-r.F),[],'all')<1e-9 && isequal(cc,r.CV),'Saved objectives do not reproduce');
    assert(~any(PACPOPhysical.dominance(r.F,r.CV),'all'),'Original archive dominance error');
    [fineF,fineCV]=PPaPaRModel.evaluate(r.X,fine);
    keep=fineCV==0 & ~any(PACPOPhysical.dominance(fineF,fineCV),1)';
    [~,hv,sp]=PACPOPhysical.metrics(p,fineF(keep,:));
    refined{i}=struct('X',r.X,'F',fineF,'CV',fineCV,'keep',keep,'seed',r.seed, ...
        'algorithm',r.algorithm,'evaluationIDs',r.archiveIDs);
    records{i}=struct('Algorithm',r.algorithm,'Seed',r.seed,'FE',r.FE,'SearchHV',r.HV, ...
        'FineHV',hv,'FineSpacing',sp,'Seconds',r.elapsed,'Pulses',sum(r.history(:,4)), ...
        'ECGenerations',sum(r.history(:,8)),'Repairs',sum(r.history(:,6)), ...
        'FinalCount',sum(keep),'MaximumVolumeRelativeChange',max(abs(fineF(:,1)./r.F(:,1)-1)), ...
        'MaximumErrorRelativeChange',max(abs(fineF(:,2)./r.F(:,2)-1)), ...
        'MaximumGCIRelativeChange',max(abs(fineF(:,3)./r.F(:,3)-1)));
    histories(i,:)=r.history(:,3)';
end
save(checkpoint,'refined','records','histories','-v7');
end
runs=struct2table(vertcat(records{:})); writetable(runs,fullfile(out,'physical_runs.csv'));
algorithms={'PACPO','NSGAII','MOEAD','MOPSO'}; aggregate=cell(4,1);
for a=1:4
    z=runs(strcmp(runs.Algorithm,algorithms{a}),:);
    aggregate{a}=struct('Algorithm',algorithms{a},'Runs',height(z),'HVMean',mean(z.FineHV), ...
        'HVStd',std(z.FineHV),'SPMean',mean(z.FineSpacing),'SPStd',std(z.FineSpacing), ...
        'SearchHVMean',mean(z.SearchHV),'PulsesTotal',sum(z.Pulses),'PulsesMean',mean(z.Pulses), ...
        'SecondsMean',mean(z.Seconds),'FEmin',min(z.FE),'FEmax',max(z.FE));
end
summary=struct2table(vertcat(aggregate{:})); writetable(summary,fullfile(out,'physical_summary.csv'));
a=sortrows(runs(strcmp(runs.Algorithm,'PACPO'),:),'Seed'); statisticsRows=cell(3,1);
for j=1:3
    b=sortrows(runs(strcmp(runs.Algorithm,algorithms{j+1}),:),'Seed'); assert(isequal(a.Seed,b.Seed));
    delta=a.FineHV-b.FineHV; nonzero=delta(delta~=0);
    if isempty(nonzero), rawp=1; effect=0;
    else, rawp=signrank(a.FineHV,b.FineHV,'method','approximate'); ranks=tiedrank(abs(nonzero)); effect=sum(sign(nonzero).*ranks)/sum(ranks); end
    statisticsRows{j}=struct('Comparator',algorithms{j+1},'N',30,'MeanDifference',mean(delta), ...
        'MedianDifference',median(delta),'RankBiserial',effect,'RawP',rawp,'HolmP',nan,'Outcome','not_significant');
end
tests=vertcat(statisticsRows{:});
adjusted=PACPOPhysical.holm([tests.RawP]);
for j=1:3
    tests(j).HolmP=adjusted(j);
    if adjusted(j)<.05 && tests(j).RankBiserial>0, tests(j).Outcome='PACPO_better';
    elseif adjusted(j)<.05 && tests(j).RankBiserial<0, tests(j).Outcome='PACPO_worse'; end
end
writetable(struct2table(tests),fullfile(out,'physical_statistics.csv'));
pool=[];
for i=find(strcmp(runs.Algorithm,'PACPO'))'
    r=refined{i}; good=r.keep;
    pool=[pool;r.X(good,:),r.F(good,:),repmat(r.seed,sum(good),1),r.evaluationIDs(good)]; %#ok<AGROW>
end
[~,u]=unique(pool(:,1:4),'rows','stable'); pool=pool(u,:);
keep=~any(PACPOPhysical.dominance(pool(:,5:7),zeros(size(pool,1),1)),1)'; pool=pool(keep,:);
normalized=PACPOPhysical.normalize(p,pool(:,5:7));
weights=[1/3,1/3,1/3;.5,.25,.25;.25,.5,.25;.25,.25,.5]; scores=zeros(size(pool,1),4); best=zeros(4,1);
for j=1:4, [scores(:,j),order]=PACPOPhysical.topsis(normalized,weights(j,:)); best(j)=order(1); end
candidates=array2table([pool(:,1:4),-pool(:,5),pool(:,6),-pool(:,7),scores,pool(:,8:9)], ...
    'VariableNames',{'a','b','c','d','Volume','Error','GCI','TOPSISEqual','TOPSISVolume','TOPSISError','TOPSISGCI','Seed','EvaluationID'});
writetable(candidates,fullfile(out,'physical_candidates.csv'));
[~,order]=sort(scores(:,1),'descend'); [~,extreme]=min(pool(:,5:7),[],1);
pick=unique([order(1),extreme,order(ceil(end/2)),order(2:6)'],'stable'); pick=pick(1:5);
reps=candidates(pick,:); reps.Scheme=(1:5)'; reps=movevars(reps,'Scheme','Before','a');
writetable(reps,fullfile(out,'physical_representatives.csv'));
% Higher accuracy checks and independent shifts for reported candidates/baseline.
designs=[400,700,1000,150;table2array(reps(:,{'a','b','c','d'}))];
ultra=PPaPaRModel.evaluate(designs,PPaPaRModel.config(1048576));
finereps=PPaPaRModel.evaluate(designs,fine);
rng(723,'twister'); shifts=rand(8,3); independent=zeros(6,3,8);
parfor j=1:8, independent(:,:,j)=PPaPaRModel.evaluate(designs,PPaPaRModel.config(262144,shifts(j,:))); end
uncertainty=struct('designs',designs,'objectives262144',finereps,'objectives1048576',ultra, ...
    'relativeChange',abs(finereps./ultra-1),'shiftMean',mean(independent,3), ...
    'shiftStd',std(independent,0,3),'shiftCV',std(independent,0,3)./abs(mean(independent,3)));
PhysicalExperiment.json(fullfile(out,'candidate_numerical_check.json'),uncertainty);
% Operational margin and uncertainty sensitivity on the baseline and chosen solution.
chosen=table2array(reps(1,{'a','b','c','d'})); threshold=[.01,.02,.04]; marginF=zeros(2,3,3);
for j=1:3, marginF(:,:,j)=PPaPaRModel.evaluate([designs(1,:);chosen],PPaPaRModel.config(262144,zeros(1,3),threshold(j))); end
errorScale=[.5,1,2]; errorF=zeros(2,3,3);
for j=1:3
    mm=fine; mm.sigmaQ=mm.sigmaQ*errorScale(j); mm.sigmaAlpha=mm.sigmaAlpha*errorScale(j); mm.sigmaG=mm.sigmaG*errorScale(j);
    errorF(:,:,j)=PPaPaRModel.evaluate([designs(1,:);chosen],mm);
end
decision=struct('weights',weights,'bestIndices',best,'bestRows',table2struct(candidates(best,:)), ...
    'candidateCount',height(candidates),'thresholds',threshold,'thresholdObjectives',marginF, ...
    'errorScales',errorScale,'errorObjectives',errorF);
evidence=struct('newRuns',120,'newFE',sum(runs.FE),'retainedBenchmarkRuns',810,'activeTotalRuns',930, ...
    'activeTotalFE',23343000,'batchSeconds',completion.seconds,'summary',table2struct(summary), ...
    'statistics',tests,'decision',decision,'representatives',table2struct(reps),'uncertainty',uncertainty, ...
    'searchIntegrationPoints',32768,'reportIntegrationPoints',262144,'verificationIntegrationPoints',1048576);
PhysicalExperiment.json(fullfile(out,'physical_evidence.json'),evidence);
save(fullfile(out,'physical_summary_data.mat'),'runs','summary','tests','refined','histories','candidates','reps','decision','uncertainty','-v7');
fprintf('Verified %d runs, %d FE, %d candidates.\n',height(runs),sum(runs.FE),height(candidates));
disp(summary); disp(struct2table(tests)); disp(reps);
end
