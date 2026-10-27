function v2_study()
% Execute the exact approved 120-run diagnostic matrix, no automatic retry.
root=fileparts(fileparts(mfilename('fullpath'))); base=fileparts(root);
addpath(fullfile(base,'matlab'),fullfile(base,'matlab','vendor'));
[status,message]=system(sprintf('python -X utf8 "%s" --check',fullfile(root,'prepare.py')));
assert(status==0,'V2:Manifest','%s',message);
auth=jsondecode(fileread(fullfile(root,'provenance','authorization.json')));
assert(auth.authorized && auth.runs==120 && auth.max_FE==3847680 && auth.workers==1 && auth.max_seconds==1200);
manifest=fileread(fullfile(root,'provenance','manifest.json'));
assert(isfile(fullfile(root,'provenance','preflight.json')));
out=fullfile(root,'raw'); if ~isfolder(out), mkdir(out); end
assert(isempty(dir(fullfile(out,'*.mat'))),'V2:NoOverwrite','Non-empty raw directory. Audit before any resume.');
log=fullfile(root,'provenance','execution.log'); assert(~isfile(log)); fid=fopen(log,'w'); assert(fid>0); cleaner=onCleanup(@()fclose(fid)); %#ok<NASGU>
names={'D0','D1','D2','D3','D4','D5'}; pop={'cd','pcd','ear','cd','pcd','ear'}; arch={'cd','cd','cd','pcd','pcd','pcd'};
p0=bs_config(); seeds=104101:104110; batch=tic; done=0; totalFE=0;
for si=1:numel(seeds)
    cycles=[2.5,3.5]; if mod(si,2)==0, cycles=fliplr(cycles); end
    order=circshift(1:6,[0,-(si-1)]);
    for cy=cycles
        p=p0; p.cycle_limit_s=cy;
        for mi=order
            if toc(batch)>=auth.max_seconds, logline('TIME_CAP runs=%d FE=%d wall=%.3f\n',done,totalFE,toc(batch)); return; end
            dest=fullfile(out,sprintf('cycle%.1f_%s_seed%d.mat',cy,names{mi},seeds(si)));
            assert(~isfile(dest)); one=tic;
            try
                result=v2_run(names{mi},pop{mi},arch{mi},seeds(si),p,64,500);
                assert(result.FE==32064); result.manifest=manifest;
                save(dest,'result'); totalFE=totalFE+result.FE; done=done+1;
                writematrix(result.trace,replace(dest,'.mat','_trace.csv'));
                ids=double(result.population_ids(end,:));
                writematrix([ids',result.history_X(ids,:),result.history_F(ids,:),result.history_CV(ids)],replace(dest,'.mat','_final.csv'));
                totalSeconds=toc(one);
                logline('RUN %d/120 cycle=%.1f seed=%d method=%s FE=%d HV=%.12g compute=%.6f save_inclusive=%.6f wall=%.3f\n',done,cy,seeds(si),names{mi},result.FE,result.trace(end,3),result.compute_seconds,totalSeconds,toc(batch));
            catch err
                logline('FAILED cycle=%.1f seed=%d method=%s identifier=%s message=%s\n',cy,seeds(si),names{mi},err.identifier,err.message); rethrow(err);
            end
        end
    end
end
logline('COMPLETE runs=%d FE=%d wall=%.3f\n',done,totalFE,toc(batch));
    function logline(format,varargin)
        fprintf(fid,format,varargin{:}); fprintf(format,varargin{:});
    end
end
