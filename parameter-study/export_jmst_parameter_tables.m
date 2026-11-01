function export_jmst_parameter_tables
% Rebuild current main Table 10 from all saved engineering confirmation runs.
base=fileparts(mfilename('fullpath'));
r=readtable(fullfile(base,'data','confirm_runs.csv'),'TextType','string');
ref=jsondecode(fileread(fullfile(base,'publication_tables_JMST','Table10.json')));
refRows=cellfun(@(x)reshape(x,1,[]),ref,'UniformOutput',false);ref=vertcat(refRows{:});
cells=cell(4,5);cells(1,:)=ref(1,:);names=["B","N31","N32"];
for k=1:3
    q=r(r.Problem=="PPAR"&r.Variant==names(k),:);
    assert(height(q)==30&&numel(unique(q.Seed))==30&&all(q.FE==25100));
    label=sprintf('%.2f; %.3f',q.Eta(1),q.SigmaMin(1));
    if k==1,label=[label,' (default)'];end
    cells(k+1,:)={label,sprintf('%.8f ± %.8f',mean(q.MillionHV),std(q.MillionHV)),...
        sprintf('%.8f',mean(q.AUC)),sprintf('%.1f',mean(q.CappedTargetFE)),sprintf('%d/30',sum(q.Reached))};
end
assert(isequal(regexprep(string(cells),'\s',''),regexprep(string(ref),'\s','')),...
    'Current Table 10 differs from saved engineering confirmation runs.');
out=fullfile(base,'publication_tables_JMST','recomputed');if ~isfolder(out),mkdir(out);end
writecell(cells,fullfile(out,'Table10.csv'),'Encoding','UTF-8');
writelines(jsonencode(struct('table','Table10','runsPerSetting',30,'evaluationBudget',25100,...
    'finalIntegrationPoints',1048576,'matchesCurrentManuscript',true,'optimizerSearches',0)),...
    fullfile(out,'Table10_verification.json'));
fprintf('JMST Table 10 matches the engineering confirmation records.\n');
end
