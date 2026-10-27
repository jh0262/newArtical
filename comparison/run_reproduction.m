function run_reproduction(mode)
% Portable analysis of preserved raw runs. Does not start optimizers by default.
if nargin<1,mode='analysis';end
base=fileparts(mfilename('fullpath'));maxNumCompThreads(1);
p1=fullfile(base,'MO_PACPO_P1修正版_20261024');p3=fullfile(base,'MO_PACPO_机构消融与P1修订_20261024');p4=fullfile(base,'MO_PACPO_创新性对照修订_20261025');p5=fullfile(base,'MO_PACPO_Machines_P1联合对照修订_20261025');
if strcmp(mode,'analysis')
 addpath(p1,fullfile(p1,'reference'));P1Analyze.run();
 addpath(p3,fullfile(p3,'code'),fullfile(p3,'code','reference'));P3Experiment.root(p3);analyze_mechanisms;
 addpath(p4,fullfile(p4,'code'),fullfile(p4,'code','reference'));P4Experiment.root(p4);analyze_innovation;
 addpath(p5,fullfile(p5,'code'),fullfile(p5,'code','reference'));P5Experiment.root(p5);analyze_joint;
 fprintf('Portable recalculation completed. Run the independent Python verifier next.\n');
else,error('This compact entry point recalculates saved data. Use preserved application entry points for new searches.');end
end
