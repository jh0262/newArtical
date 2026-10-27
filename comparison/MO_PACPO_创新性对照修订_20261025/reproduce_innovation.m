function reproduce_innovation
R=fileparts(mfilename('fullpath'));addpath(R,fullfile(R,'code'),fullfile(R,'code','reference'));
% Source and plans are frozen before all formal runs. Matching files are reused.
z=load(fullfile(R,'freeze.mat'),'source');assert(isequal(z.source,P4Experiment.source()));
b=load(fullfile(R,'baseline_freeze.mat'),'source');assert(isequal(b.source,MOCPOExperiment.source()));
tests=runtests(fullfile(R,'tests'));assertSuccess(tests);
f=P4Experiment.start();g=MOCPOExperiment.start();
for k=1:numel(f),[~,s]=fetchNext(f);assert(s.ok,'P4:RunFailure','%s',s.error);end
for k=1:numel(g),[~,s]=fetchNext(g);assert(s.ok,'P4:RunFailure','%s',s.error);end
s=P4ReplayDL.all(R);assert(s.replayed==s.planned);
analyze_innovation;make_innovation_figures;
fprintf('MATLAB execution and analysis completed. Run verify_analysis.py before building the manuscript.\n');
end
