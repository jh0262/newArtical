function futures=pade_launch(root,workers)
%PADE_LAUNCH Submit all 780 paired problem/seed blocks, never rerun successes.
arguments
    root (1,1) string
    workers (1,1) double {mustBeInteger,mustBePositive}=6
end
addpath(fullfile(root,'code'));
manifest=jsondecode(fileread(fullfile(root,'FROZEN_MANIFEST.json')));
pool=gcp('nocreate');
if isempty(pool), pool=parpool('Processes',workers);
else, assert(pool.NumWorkers==workers,'pade:PoolSize','Existing pool has a different size.'); end
files=dir(fullfile(root,'code','*.m'));
addAttachedFiles(pool,fullfile({files.folder},{files.name}));
futures=parallel.FevalFuture.empty(0,780);
for r=1:30
    for p=1:26
        futures(end+1)=parfeval(pool,@pade_worker,1,root,p,r,manifest); %#ok<AGROW>
    end
end
fprintf('Submitted %d problem/seed tasks on %d workers.\n',numel(futures),workers);
end
