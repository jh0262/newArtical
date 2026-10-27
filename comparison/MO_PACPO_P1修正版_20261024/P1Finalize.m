function P1Finalize()
root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));maxNumCompThreads(1);
jobs=P1Experiment.jobs();timer=tic;
while true
    done=true;
    for j=1:numel(jobs)
        path=fullfile(root,'results','runs',[jobs(j).id,'_status.json']);
        if isfile(path),s=jsondecode(fileread(path));assert(s.ok,'%s',s.error);else,done=false;end
    end
    if done,break;end
    assert(toc(timer)<14400,'Optimization wait exceeded four hours');pause(20);
end
fprintf('All %d optimization jobs completed successfully.\n',numel(jobs));
while ~isfile(fullfile(root,'validation','completed.json')) || ~isfile(fullfile(root,'validation','extra','completed.json'))
    assert(toc(timer)<14400,'Validation wait exceeded four hours');pause(20);
end
% Additional workers sometimes finish a shared setting concurrently. Every
% duplicate staging result must equal the canonical result before reporting.
files=dir(fullfile(root,'validation','extra','archive_*.mat'));duplicateChecks=0;
for i=1:numel(files)
    a=load(fullfile(files(i).folder,files(i).name));b=load(fullfile(root,'validation',files(i).name));
    assert(isequaln(a.X,b.X)&&isequaln(a.allF,b.allF)&&isequaln(a.allCV,b.allCV)&&isequaln(a.allKeep,b.allKeep)&&isequaln(a.hv,b.hv));duplicateChecks=duplicateChecks+1;
end
P1Experiment.json(fullfile(root,'validation','duplicate_checks.json'),struct('checks',duplicateChecks,'identical',true));
z=load(fullfile(root,'freeze.mat'),'source');assert(isequal(z.source,P1Experiment.source()));
P1Stats.corrected_old();P1AreaValidate();
if isfile(fullfile(root,'audit','benchmark_completed.json'))
    P1Analyze.physical(root,fullfile(fileparts(root),'MO_PACPO_搜索机制改进_20261024'));P1Analyze.numerics(root);
    copyfile(fullfile(root,'audit','benchmark_completed.json'),fullfile(root,'audit','completion.json'));
else
    P1Analyze.run();
end
P1Figures();
P1Experiment.json(fullfile(root,'audit','analysis_completed.json'),struct('completed',true,'timestamp',char(datetime('now'))));
fprintf('P1 result analysis and figures complete.\n');
end
