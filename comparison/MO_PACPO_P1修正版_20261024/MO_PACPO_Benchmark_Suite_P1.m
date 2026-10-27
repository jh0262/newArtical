function result=MO_PACPO_Benchmark_Suite_P1(problemName,variant,seed)
% One frozen, full-budget benchmark run. Batch reproduction: reproduce_p1.
% Example: r=MO_PACPO_Benchmark_Suite_P1('ZDT1','revised',711001);
if nargin<1,problemName='ZDT1';end
if nargin<2,variant='revised';end
if nargin<3,seed=711001;end
root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));
assert(~strcmpi(problemName,'PPAR'),'Use the engineering entry point for PPAR.');
p=PACPOP1.problem(problemName);c=P1Variants.config(variant,seed);
if strcmp(variant,'GDE3'),result=P1GDE3.solve(p,c);else,result=PACPOP1.solve(p,'PACPO',c);end
end
