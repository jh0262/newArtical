function result=MO_PACPO_Benchmark_Suite_P1Joint(problem,variant,seed)
% One explicit 25100-evaluation benchmark run. Use reproduce_joint for batch analysis.
if nargin<1,problem='ZDT6';end
if nargin<2,variant='Full';end
if nargin<3,seed=812001;end
R=fileparts(mfilename('fullpath'));addpath(fullfile(R,'code'),fullfile(R,'code','reference'));maxNumCompThreads(1);
p=P5Core.problem(problem);assert(~strcmp(p.name,'PPAR'),'Use the mechanism entry point.');
result=P5Core.solve(p,'PACPO',P5Variants.config(variant,seed));
end
