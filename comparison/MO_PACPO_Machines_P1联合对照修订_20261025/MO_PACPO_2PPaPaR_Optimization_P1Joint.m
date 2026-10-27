function result=MO_PACPO_2PPaPaR_Optimization_P1Joint(variant,seed)
% One explicit 25100-evaluation mechanism search; final refinement is in P5Experiment.
if nargin<1,variant='Full';end
if nargin<2,seed=400001;end
R=fileparts(mfilename('fullpath'));addpath(fullfile(R,'code'),fullfile(R,'code','reference'));maxNumCompThreads(1);
result=P5Core.solve(P5Core.problem('PPAR'),'PACPO',P5Variants.config(variant,seed));
end
