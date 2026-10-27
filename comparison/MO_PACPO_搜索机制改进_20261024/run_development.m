function run_development(batchName, mechanisms)
if nargin<1,batchName='dev01';end
if nargin<2,mechanisms={'legacy','scale','local','directional'};end
root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));
folder=fullfile(root,'results',batchName);if ~isfolder(folder),mkdir(folder);end
tasks={'ZDT1','ZDT2','ZDT3','DTLZ1','DTLZ2'};jobs={};
for k=1:5
    for r=1:5
        for v=1:numel(mechanisms),jobs(end+1,:)={tasks{k},610000+1000*k+r,mechanisms{v}};end %#ok<AGROW>
    end
end
if isempty(gcp('nocreate')),parpool('Processes',8);end
updateAttachedFiles(gcp);
source=struct('core',fileread(fullfile(root,'PACPOSearch.m')),'mechanism',fileread(fullfile(root,'SearchMechanism.m')), ...
    'variants',fileread(fullfile(root,'SearchVariants.m')));
mechanismPath=fullfile(root,'SearchMechanism.m');
save(fullfile(folder,'source.mat'),'source','jobs'); rows=cell(size(jobs,1),1);
parfor i=1:size(jobs,1)
    problem=jobs{i,1};seed=jobs{i,2};mode=jobs{i,3};path=fullfile(folder,sprintf('%s_%s_%d.mat',problem,mode,seed));
    if isfile(path),z=load(path,'result');result=z.result;
    else
        c=SearchVariants.config(mode,seed);
        if ismember(mode,{'NSGAII','MOEAD','MOPSO'}),algorithm=mode;else,algorithm='PACPO';end
        result=PACPOSearch.solve(PACPOSearch.problem(problem),algorithm,c);
        assert(strcmp(fileread(mechanismPath),source.mechanism),'Search:Source','Worker source mismatch');
        saveResult(path,result,source);
    end
    rows{i}=table(string(problem),string(mode),seed,result.IGD,result.HV,result.Spacing,result.FE,result.elapsed,...
        'VariableNames',{'Problem','Variant','Seed','IGD','HV','SP','FE','Seconds'});
end
runs=vertcat(rows{:});writetable(runs,fullfile(folder,'runs.csv'));
summary=groupsummary(runs,{'Problem','Variant'},{'mean','std'},{'IGD','HV','SP'});writetable(summary,fullfile(folder,'summary.csv'));
disp(summary(:,{'Problem','Variant','mean_IGD','mean_HV'}));
end
function saveResult(path,result,source)
save(path,'result','source');
end
