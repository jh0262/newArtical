function ec_worker(worker,total)
root=ec_setup();
ec_assert_frozen(root);
cfg=ec_config('formal');
ec_jsonwrite(fullfile(root,'provenance',sprintf('worker_%02d_environment.json',worker)),struct('worker',worker,'matlab',version,'toolboxes',{ver},'computer',computer));
job=0; failed=0;
for pi=1:numel(cfg.problems)
    for seed=cfg.seeds
        % Rotation balances algorithms across processes without consuming optimization RNG.
        order=circshift(1:numel(cfg.algorithms),mod(seed,numel(cfg.algorithms)));
        for ai=order
            job=job+1; if mod(job-1,total)~=worker-1, continue; end
            parent=fullfile(root,'runs','formal_v1',cfg.problems(pi).name,cfg.algorithms(ai).name,sprintf('seed_%06d',seed));
            attempts=dir(fullfile(parent,'attempt_*')); done=false;
            for q=1:numel(attempts)
                mf=fullfile(parent,attempts(q).name,'manifest.json');
                if isfile(mf)
                    m=jsondecode(fileread(mf));
                    if strcmp(m.status,'completed') && m.FE==50100 && m.generations==500 && isfile(fullfile(parent,attempts(q).name,'raw.mat'))
                        done=true; break;
                    end
                end
            end
            if done, continue; end
            attempt=fullfile(parent,sprintf('attempt_%03d',numel(attempts)+1));
            try
                ec_run_one(cfg,pi,ai,seed,attempt);
            catch err
                failed=failed+1; fprintf(2,'FAILED job=%d %s %s\n',job,err.identifier,err.message);
            end
        end
    end
end
ec_jsonwrite(fullfile(root,'provenance',sprintf('worker_%02d_finished.json',worker)),struct('failed',failed,'finished_at',char(datetime('now','TimeZone','UTC'))));
assert(failed==0,'EC:WorkerFailures','Worker had %d failed runs; inspect preserved artifacts.',failed);
end
