function export_jmst_tables
% Rebuild current main Table 5 from the frozen six-contrast statistics.
base=fileparts(mfilename('fullpath'));
folder=fullfile(base,'MO_PACPO_Machines_P1联合对照修订_20261025','data');
s=readtable(fullfile(folder,'joint_statistics.csv'),'TextType','string');
e=readtable(fullfile(folder,'joint_exact_sensitivity.csv'),'TextType','string');
s=s(s.Problem=="PPAR"&s.Metric=="HV"&s.IntegrationPoints==262144,:);
e=e(e.Problem=="PPAR"&e.Metric=="HV"&e.IntegrationPoints==262144,:);
names=["Full_joint","Full_noNoise","Full_noLock","noLock_joint","noNoise_joint","Interaction"];
display=["Full−joint","Full−noNoise","Full−noLock","noLock−joint","noNoise−joint","Interaction"];
ref=jsondecode(fileread(fullfile(base,'publication_tables_JMST','Table5.json')));
refRows=cellfun(@(x)reshape(x,1,[]),ref,'UniformOutput',false);ref=vertcat(refRows{:});
cells=cell(7,6);cells(1,:)=ref(1,:);
for k=1:6
    a=s(s.Contrast==names(k),:);b=e(e.Contrast==names(k),:);assert(height(a)==1&&height(b)==1);
    cells(k+1,:)={display(k),sprintf('%+.4f',a.MeanDifference*1e4),...
        sprintf('[%+.4f, %+.4f]',a.CILow*1e4,a.CIHigh*1e4),...
        sprintf('%.6f',a.HolmP),sprintf('%.6f',b.ExactHolmP),...
        sprintf('%d/%d/%d',a.Positive,a.Negative,a.Zero)};
end
assert(isequal(regexprep(string(cells),'\s',''),regexprep(string(ref),'\s','')),...
    'Current Table 5 differs from six-contrast source statistics.');
out=fullfile(base,'publication_tables_JMST','recomputed');if ~isfolder(out),mkdir(out);end
writecell(cells,fullfile(out,'Table5.csv'),'Encoding','UTF-8');
writelines(jsonencode(struct('table','Table5','integrationPoints',262144,'contrasts',6,...
    'primary','approximate signed-rank, six-comparison Holm',...
    'sensitivity','exact conditional signed-rank, six-comparison Holm','matchesCurrentManuscript',true,...
    'optimizerSearches',0)),fullfile(out,'Table5_verification.json'));
fprintf('JMST Table 5 matches the six-contrast analysis.\n');
end
