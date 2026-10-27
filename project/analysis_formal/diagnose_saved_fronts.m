function diagnose_saved_fronts()
% Post-hoc finite-pool truncation diagnostic; no objective evaluations.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'matlab'),fullfile(root,'matlab','vendor'));
p=bs_config(); out=fullfile(root,'analysis_formal'); S=readtable(fullfile(out,'all_final_designs.csv'),'TextType','string'); records=[];
for cy=[2.5,3,3.5]
    ok=S.CV==0 & S.cycle_limit_s<=cy; F=[S.T_s(ok),S.residual_um(ok)]; F=F(ec_nd_indices(F),:);
    Z=(F-min(F))./(max(F)-min(F)); D=hypot(Z(:,1)-Z(:,1)',Z(:,2)-Z(:,2)');
    t=tic; cd=ec_cd_subset(F,64); tcd=toc(t);
    t=tic; [ear,info]=ec_earclip(F,64); tear=toc(t);
    t=tic; pcd=(1:size(F,1))';
    while numel(pcd)>64
        kept=ec_cd_subset(F(pcd,:),numel(pcd)-1); pcd=pcd(kept);
    end
    tpcd=toc(t); groups={cd,ear,pcd}; names=["one_pass_CD","bounded_ear","iterative_CD"];
    times=[tcd,tear,tpcd]; baseline=max(min(D(:,cd),[],2));
    for j=1:3
        id=groups{j}; actual=max(min(D(:,id),[],2));
        records=[records;table(cy,names(j),size(F,1),numel(id),bs_hv(F(id,:),p),actual,baseline,times(j), ...
            'VariableNames',{'cycle_limit_s','selector','pool_size','retained','HV','normalized_pool_coverage','CD_coverage_bound','seconds'})]; %#ok<AGROW>
    end
    assert(info.coverage<=info.bound+1e-10);
end
writetable(records,fullfile(out,'saved_front_truncation_diagnostic.csv')); disp(records);
end
