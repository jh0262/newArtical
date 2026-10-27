function MO_PACPO_Benchmark_Suite_SearchRevised(phase)
% Default: repeat/resume the frozen 5-problem, 30-seed comparison.
if nargin<1,phase='confirmation';end
root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));
assert(ismember(phase,{'confirmation','external','ablation'}),'Unknown benchmark phase');
SearchExperiment.run(phase);
if ismember(phase,{'confirmation','external'}),audit_variance_diagnostic(phase);end
analyze_search(phase);
end
