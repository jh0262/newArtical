function reproduce_mechanism_revision
% Reuse matching saved runs; execute missing predefined runs only.
R=fileparts(mfilename('fullpath'));addpath(R,fullfile(R,'code'),fullfile(R,'code','reference'));
if ~isfile(fullfile(R,'freeze.mat')),P3Experiment.verify();end
f=P3Experiment.start();
for k=1:numel(f)
 [~,status]=fetchNext(f);assert(status.ok,'P3:RunFailure','%s: %s',status.id,status.error);
end
analyze_mechanisms;verify_mask_covariance;make_mechanism_figure;
fprintf('MATLAB reproduction complete. Run verify_analysis.py, build_revision.py, render_word.ps1 and final_check.py next.\n');
end
