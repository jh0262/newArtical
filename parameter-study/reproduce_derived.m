function reproduce_derived()
maxNumCompThreads(1);
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'),fullfile(root,'code/reference'),fullfile(root,'scripts'));
for phase=["screen","confirm"],ERAnalysis.summarize(char(phase));ERAnalysis.statistics(char(phase));end
ERFigures.run();
fprintf('Statistics and figures regenerated from saved run tables. Run scripts/independent_verify.py for independent checks.\n');
end
