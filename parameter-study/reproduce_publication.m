function reproduce_publication()
% Rebuild publication outputs from the completed parameter study; no search.
root=fileparts(mfilename('fullpath'));
savedPath=path;savedThreads=maxNumCompThreads;
cleanup=onCleanup(@()restoreEnvironment(savedPath,savedThreads)); %#ok<NASGU>
addpath(root,fullfile(root,'scripts'));
reproduce_derived();
make_parameter_figure();
fprintf('Publication Figure 10 and original derived tables/figures regenerated.\n');
end
function restoreEnvironment(savedPath,savedThreads)
path(savedPath);maxNumCompThreads(savedThreads);
end
