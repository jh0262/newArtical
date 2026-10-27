function output=pade_reproduce(root,workers)
%PADE_REPRODUCE Resume frozen runs, audit, analyze and export actual figures.
% One command after addpath('code'): pade_reproduce
% Existing successful matching runs are reused; missing records are computed.
arguments
    root (1,1) string=string(fileparts(fileparts(mfilename('fullpath'))))
    workers (1,1) double {mustBeInteger,mustBePositive}=6
end
addpath(fullfile(root,'code'));
assert(isfolder(root),'pade:Root','Experiment package not found.');
frozen=pade_verify_frozen(root);
futures=pade_launch(root,workers);
wait(futures);
failed=false(size(futures));
for k=1:numel(futures), failed(k)=~isempty(futures(k).Error); end
assert(~any(failed),'pade:WorkerFailure','%d tasks failed; inspect failures and futures errors.',nnz(failed));
audit=pade_audit_runs(root);
assert(audit.passed,'pade:AuditFailure','Independent raw-run audit did not pass.');
config=jsondecode(fileread(fullfile(root,'CONFIG.json')));
expected=string({config.problems.id});
comparisons=readtable(fullfile(root,'comparisons.csv'),'TextType','string');
resultsDir=fullfile(root,'results');
stats=pade_analyze(fullfile(root,'raw'),resultsDir,comparisons,...
    ExpectedRuns=30,ExpectedSeeds=1001:1030,ExpectedProblems=expected,...
    FeasibilityTolerance=0,RequireEqualFE=true,AllowPartial=false);
engineering=pade_engineering_details(fullfile(root,'raw'),resultsDir);
plots=pade_plot_results(resultsDir,fullfile(root,'figures'));
output=struct('frozen',frozen,'audit',audit,'analysis',stats,...
    'engineering',engineering,'plots',plots);
save(fullfile(root,'qa','reproduction_summary.mat'),'output','-v7.3');
fprintf('Complete: %d successful formal runs. See results and figures.\n',height(stats.runs));
end
