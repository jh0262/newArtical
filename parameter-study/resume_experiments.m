function futures=resume_experiments(phase)
if nargin==0,phase='screen';end
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'),fullfile(root,'code/reference'));
pool=gcp('nocreate');
if ~isempty(pool)
 assert(isempty(pool.FevalQueue.RunningFutures)&&isempty(pool.FevalQueue.QueuedFutures),'ER:ActiveQueue','An active queue already exists. Wait for it before resuming to avoid duplicate writes.');
end
futures=ERStudy.start(phase);
end
