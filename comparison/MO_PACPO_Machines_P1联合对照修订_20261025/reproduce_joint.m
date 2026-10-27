function reproduce_joint(mode)
% Default re-analyzes frozen saved runs. 'experiments' resumes missing jobs.
if nargin<1,mode='analysis';end
R=fileparts(mfilename('fullpath'));addpath(R,fullfile(R,'code'),fullfile(R,'code','reference'));maxNumCompThreads(1);P5Experiment.root(R);
z=load(fullfile(R,'freeze.mat'),'source');assert(isequal(z.source,P5Experiment.source()));
if strcmp(mode,'experiments')
 t=runtests(fullfile(R,'tests'));assertSuccess(t);f=P5Experiment.start();
 for k=1:numel(f),[~,s]=fetchNext(f);assert(s.ok,'P5:RunFailure','%s',s.error);end
elseif ~strcmp(mode,'analysis'),error('Use analysis or experiments.');end
analyze_joint;
fprintf('Run scripts/verify_joint.py with Python 3.8+, NumPy, SciPy and pandas for the independent checks.\n');
end
