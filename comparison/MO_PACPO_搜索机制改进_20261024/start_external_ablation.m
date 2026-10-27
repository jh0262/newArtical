function futures=start_external_ablation()
root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));
z=load(fullfile(root,'freeze.mat'),'source');source=SearchExperiment.source();assert(isequal(z.source,source));
tasks={'ZDT4','ZDT6','DTLZ3'};modes={'candidateDiagonal','candidateNoNoise','candidateNoLock','candidateNoEC','candidateFixed'};
jobs=struct('problem',{},'mode',{},'seed',{},'id',{});
for k=1:3
    for r=1:30
        for v=1:5
            seed=810000+1000*k+r;jobs(end+1)=struct('problem',tasks{k},'mode',modes{v},'seed',seed, ...
                'id',sprintf('%s_%s_%d',tasks{k},modes{v},seed)); %#ok<AGROW>
        end
    end
end
folder=fullfile(root,'results','external_ablation');if ~isfolder(folder),mkdir(folder);end
save(fullfile(folder,'plan.mat'),'source','jobs');SearchExperiment.json(fullfile(folder,'plan.json'),jobs);
pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',8);end
updateAttachedFiles(pool);futures=parallel.FevalFuture.empty(0,numel(jobs));
for i=1:numel(jobs),futures(i)=parfeval(pool,@SearchExperiment.one,1,jobs(i),folder,source);end
fprintf('Submitted external ablation: %d runs.\n',numel(jobs));
end
