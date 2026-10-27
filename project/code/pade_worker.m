function taskSummary=pade_worker(root,problemIndex,runIndex,manifest)
%PADE_WORKER One problem/seed task; each variant persists atomically.
maxNumCompThreads(1);
probs=pade_problems(); prob=probs(problemIndex);
variants=pade_variants(~isempty(prob.discrete_idx)); opts=pade_defaults(problemIndex);
opts.config_hash=manifest.config_hash; opts.code_hash=manifest.code_hash;
opts.problem_hash=manifest.problem_hash;
seed=1000+runIndex; nDone=0; nSkipped=0;
rawFolder=fullfile(root,'raw',prob.id);
if ~isfolder(rawFolder), mkdir(rawFolder); end
timer=tic;
for k=1:numel(variants)
    file=fullfile(rawFolder,sprintf('%s__%s__s%d.mat',prob.id,variants(k).id,seed));
    if isfile(file)
        old=load(file,'result');
        assert(strcmp(old.result.config_hash,opts.config_hash)&&strcmp(old.result.code_hash,opts.code_hash),...
            'pade:StaleOutput','Existing run belongs to different frozen code/config: %s',file);
        assert(old.result.FE==opts.maxFE && strcmp(old.result.status,'complete'));
        nSkipped=nSkipped+1; continue;
    end
    try
        result=pade_solve_fe(prob,variants(k),opts,seed);
        result.run_index=runIndex; result.problem_index=problemIndex;
        result.pulseFE=result.events.pulse_FE;
        temp=string(file)+".part"; save(temp,'result','-v7'); movefile(temp,file,'f');
        nDone=nDone+1;
    catch err
        failure=struct('problem',prob.id,'variant',variants(k).id,'seed',seed,...
            'identifier',err.identifier,'message',err.message,'stack',err.stack,...
            'report',getReport(err,'extended','hyperlinks','off'));
        if exist('result','var'), failure.consumed_FE=result.FE; end
        failedDir=fullfile(root,'failures'); if ~isfolder(failedDir), mkdir(failedDir); end
        save(fullfile(failedDir,sprintf('%s__%s__s%d_FAILURE.mat',prob.id,variants(k).id,seed)),'failure');
        rethrow(err);
    end
end
taskSummary=struct('problem_id',prob.id,'seed',seed,'produced',nDone,...
    'skipped',nSkipped,'run_seconds',toc(timer));
end
