function summary=MO_PACPO_2PPaPaR_Optimization_Physical(workers)
% Full engineering experiment: 4 algorithms x 30 seeds x 25100 FE.
if nargin<1, workers=8; end
root=fileparts(mfilename('fullpath')); addpath(root);
summary=PhysicalExperiment.run(fullfile(root,'results'),workers);
end
