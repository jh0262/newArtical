function MO_PACPO_2PPaPaR_Optimization_SearchRevised()
% Same validated mechanism model, 30 seeds, 25100 FE each; refine all archives.
root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));
SearchExperiment.run('physical');analyze_physical_search();
end
