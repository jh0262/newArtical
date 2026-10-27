function bs_run_study(max_seconds)
% Execute only after the user supplies the formal compute budget.
% Each completed run is saved; a time cap is checked between runs.
arguments
    max_seconds (1,1) double {mustBePositive,mustBeFinite}
end
p0=bs_config(); addpath(fullfile(p0.root,'matlab','vendor'));
manifest=fullfile(p0.root,'provenance','formal_manifest.json'); assert(isfile(manifest),'Freeze the protocol/source manifest before running.');
[verifyStatus,verifyText]=system(sprintf('python -X utf8 "%s" --check',fullfile(p0.root,'freeze_manifest.py')));
assert(verifyStatus==0,'BS:ChangedInputs','Frozen input check failed: %s',verifyText);
manifestText=fileread(manifest);
out=fullfile(p0.root,'formal_v01'); if ~isfolder(out), mkdir(out); end
names={'MODE-CD-G','MODE-EAR-G','MODE-CD-S','MODE-EAR-S','MV-NSGA-II','MV-SPEA2','CAT-QMC'};
cycles=[2.5,3,3.5]; seeds=93101:93120; start=tic; completed=0;
for cy=cycles
    p=p0; p.cycle_limit_s=cy;
    for seed=seeds
        for i=1:numel(names)
            name=names{i}; dest=fullfile(out,sprintf('cycle%.1f_%s_seed%d.mat',cy,name,seed));
            if isfile(dest), error('BS:NoOverwrite','Existing run: %s. Use an audited resume rather than overwrite.',dest); end
            if toc(start)>=max_seconds
                fprintf('TIME_CAP reached after %d runs; %.1f seconds.\n',completed,toc(start)); return;
            end
            if strcmp(name,'CAT-QMC'), result=bs_qmc(seed,64,500,p); else, result=bs_mode(name,seed,64,500,p); end
            assert(result.FE==32064 && result.max_coverage_excess<1e-10 && all(isfinite(result.F),'all'));
            result.manifest=manifestText; result.cycle_limit_s=cy;
            save(dest,'result');
            writematrix([result.X,result.F,result.CV],replace(dest,'.mat','_final.csv'));
            writematrix(result.trace,replace(dest,'.mat','_trace.csv'));
            completed=completed+1;
            fprintf('%d/420 cy %.1f seed %d %s: HV %.8f time %.3fs\n',completed,cy,seed,name,result.trace(end,3),result.seconds);
        end
    end
end
fprintf('COMPLETE: %d runs, %d FE, %.1f seconds.\n',completed,completed*32064,toc(start));
end
