function update_paper_data()
root=fileparts(mfilename('fullpath')); out=fullfile(root,'data');
search=fullfile(fileparts(root),'MO_PACPO_搜索机制改进_20261024');
addpath(search,fullfile(search,'reference'));
z=load(fullfile(search,'results','physical','refined.mat'),'refined'); refined=z.refined;
p=PACPOSearch.problem('PPAR');fine=PPaPaRModel.config(262144);
pool=[];
for i=1:30
    r=refined{i}; good=r.keep;
    pool=[pool;r.X(good,:),r.F(good,:),repmat(r.seed,sum(good),1),r.evaluationIDs(good)]; %#ok<AGROW>
end
[~,u]=unique(pool(:,1:4),'rows','stable'); pool=pool(u,:);
keep=~any(PACPOSearch.dominance(pool(:,5:7),zeros(size(pool,1),1)),1)'; pool=pool(keep,:);
normalized=PACPOSearch.normalize(p,pool(:,5:7));
weights=[1/3,1/3,1/3;.5,.25,.25;.25,.5,.25;.25,.25,.5]; scores=zeros(size(pool,1),4); best=zeros(4,1);
for j=1:4, [scores(:,j),order]=PACPOSearch.topsis(normalized,weights(j,:)); best(j)=order(1); end
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
SearchExperiment.json(fullfile(out,'candidate_numerical_check.json'),uncertainty);
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
evidence=struct('decision',decision,'representatives',table2struct(reps),'uncertainty',uncertainty);
SearchExperiment.json(fullfile(out,'paper_physical_evidence.json'),evidence);
save(fullfile(out,'paper_physical_data.mat'),'refined','candidates','reps','decision','uncertainty');
fprintf('Candidates: %d\n',height(candidates));disp(reps);disp(max(uncertainty.relativeChange,[],1));
end
