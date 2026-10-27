function result=rerun_search(problem,variant,seed,destination)
% Genuine same-budget run, with preserved originals and new destination.
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'code'),fullfile(root,'code/reference'));
assert(~isfile(destination)&&isfolder(fileparts(destination)),'Choose a new file in an existing directory.');
frozen=load(fullfile(root,'freeze.mat'));assert(isequal(frozen.source,ERStudy.source()));maxNumCompThreads(1);ERTape.store('clear',[]);
c=ERStudy.config(variant,seed);c.failureFile=[destination,'.failure.mat'];p=ERCore.problem(problem);result=ERCore.solve(p,'PACPO',c);source=frozen.source;save(destination,'result','source','-v7');
end
