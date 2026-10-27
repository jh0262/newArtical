function report=MO_PACPO_Benchmark_Suite_Physical(mode)
% The benchmark solver is unchanged; verify exact-seed agreement before reusing runs.
if nargin<1, mode='regression'; end
root=fileparts(mfilename('fullpath')); addpath(root);
old=fullfile(root,'benchmark_reference'); addpath(old);
if ~strcmp(mode,'regression')
    assert(ismember(mode,{'all','main','ablation','sensitivity'}),'Unknown benchmark mode');
    report=PACPOExperiment.run(PACPOExperiment.jobs(mode),fullfile(root,'benchmark_reruns',mode),8);
    return;
end
tasks={'ZDT1','ZDT3','DTLZ2'}; algorithms={'PACPO','NSGAII','MOEAD','MOPSO'};
report=struct('problem',{},'algorithm',{},'equal',{});
for i=1:3
    for a=1:4
        c=PACPO.config(struct('N',20,'archiveSize',20,'G',6,'seed',8123+i));
        r1=PACPO.solve(PACPO.problem(tasks{i}),algorithms{a},c);
        r2=PACPOPhysical.solve(PACPOPhysical.problem(tasks{i}),algorithms{a},c);
        same=isequaln(r1.evaluations,r2.evaluations) && isequaln(r1.history,r2.history) && isequaln(r1.archive,r2.archive);
        assert(same,'Benchmark implementation drift');
        report(end+1)=struct('problem',tasks{i},'algorithm',algorithms{a},'equal',same); %#ok<AGROW>
    end
end
PhysicalExperiment.json(fullfile(root,'validation','benchmark_regression.json'),report);
end
