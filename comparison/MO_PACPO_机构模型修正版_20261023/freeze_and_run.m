% Full authorized run. Creates a frozen source snapshot only after checks pass.
root=fileparts(mfilename('fullpath')); addpath(root);
addpath(fullfile(root,'benchmark_reference'));
r=runtests({'TestPPaPaRModel.m','TestPACPOPhysical.m','TestPhysicalSolver.m'});
assert(all([r.Passed]),'Verification failure');
regression=MO_PACPO_Benchmark_Suite_Physical();
load(fullfile(root,'validation','model_validation.mat'),'report');
error32768=max(report.relativeTo262144(:,:,report.powers==15),[],1);
assert(all(error32768<[.01,.03,.01]),'Quadrature precision not accepted');
assert(all([report.monteCarlo.covarianceRelativeError]<.03),'Covariance verification failed');
rng(721); shifts=rand(8,3); shifted=zeros(6,3,8);
for i=1:8, shifted(:,:,i)=PPaPaRModel.evaluate(report.designs,PPaPaRModel.config(32768,shifts(i,:))); end
shiftCV=std(shifted,0,3)./abs(mean(shifted,3));
assert(all(max(shiftCV,[],1)<[.01,.03,.01]),'Independent quadrature check failed');
source=struct(); names={'PACPOPhysical','PPaPaRModel','PhysicalExperiment'};
for i=1:numel(names), source.(names{i})=fileread(fullfile(root,[names{i},'.m'])); end
existing=fullfile(root,'results','configuration.mat');
if isfile(existing)
    previous=load(existing,'source');
    assert(isequal(previous.source,source),'Existing results use different code; choose a new output directory.');
end
freeze=struct('testsPassed',true,'passedCount',sum([r.Passed]),'testCount',numel(r), ...
    'regressionCases',numel(regression),'quadratureCount',32768,'relativeError',error32768, ...
    'independentShiftCV',shiftCV,'source',source,'version',version, ...
    'time',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
PhysicalExperiment.json(fullfile(root,'code_freeze.json'),freeze);
save(fullfile(root,'validation','frozen_verification.mat'),'r','regression','freeze','shifted');
summary=MO_PACPO_2PPaPaR_Optimization_Physical(8);
