function reproduce_p1()
% Resumable reproduction using original preserved input packages plus P1 code.
% Existing validated runs are reused. To rerun from scratch, copy this package
% to a new sibling directory and remove only that copy's results/validation.
root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));
f=P1Experiment.start();wait(f);
for i=1:numel(f),status=fetchOutputs(f(i));assert(status.ok,'A run failed; inspect its status JSON file.');end
P1Numerics.run();
g=P1ExtendGDE.start();wait(g);
for i=1:numel(g),assert(fetchOutputs(g(i)),'GDE3 archive audit failed.');end
P1Replay();P1AreaValidate();P1Stats.corrected_old();P1Analyze.run();P1Figures();
end
