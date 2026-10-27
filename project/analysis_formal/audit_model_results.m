function audit_model_results()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'matlab'),fullfile(root,'matlab','vendor'));
p=bs_config(); results=dir(fullfile(root,'formal_v01','*.mat')); assert(numel(results)==420);
maxF=0; maxCV=0; maxGfeasible=-inf; count=0; referenceExcluded=0;
for cy=[2.5,3,3.5]
    XX=[]; FF=[]; CC=[];
    for j=1:numel(results)
        d=load(fullfile(results(j).folder,results(j).name)); r=d.result;
        if r.cycle_limit_s~=cy, continue; end
        XX=[XX;r.X]; FF=[FF;r.F]; CC=[CC;r.CV]; %#ok<AGROW>
    end
    p.cycle_limit_s=cy; [F,CV,G]=bs_evaluate(XX,p);
    maxF=max(maxF,max(abs(F-FF),[],'all')); maxCV=max(maxCV,max(abs(CV-CC)));
    assert(max(abs(F-FF),[],'all')<1e-12 && max(abs(CV-CC))<1e-12);
    assert(isequal(CV==0,CC==0));
    maxGfeasible=max(maxGfeasible,max(G(CV==0,:),[],'all'));
    [~,excluded]=bs_hv(F(CV==0,:),p); referenceExcluded=referenceExcluded+excluded;
    count=count+size(XX,1);
end
report=struct('status','PASS','runs',numel(results),'reevaluated_designs',count, ...
    'scenario_evaluations',count*9,'max_objective_difference',maxF,'max_CV_difference',maxCV, ...
    'largest_raw_G_among_feasible_designs',maxGfeasible,'relative_constraint_tolerance',p.constraint_tolerance, ...
    'reference_excluded_total',referenceExcluded,'evidence','Saved optimizer outputs reevaluated; not new optimization or physical validation');
fid=fopen(fullfile(root,'analysis_formal','model_reevaluation_audit.json'),'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(report,PrettyPrint=true),'char'); disp(report);
end
