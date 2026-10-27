function audit_variance_diagnostic(phase)
% Preserve frozen raw logs; correct the single-point covariance diagnostic.
root=fileparts(mfilename('fullpath'));folder=fullfile(root,'results',phase);
data=load(fullfile(folder,'aggregate.mat'));diagnostics=data.diagnostics;corrections={};
rows=find(ismember(data.runs.Variant,["candidate","legacy"]));
for i=rows'
    row=data.runs(i,:);path=fullfile(folder,sprintf('%s_%s_%d.mat',row.Problem,row.Variant,row.Seed));
    z=load(path,'result');r=z.result;
    % These benchmark problems are unconstrained: feasible count equals archive size.
    assert(~strcmp(r.problem,'PPAR') && all(r.evaluations(:,end-1)==0));
    singleton=r.history(2:end,7)==1;
    generations=find(singleton);stored=diagnostics(singleton,6,i);diagnostics(singleton,6,i)=0;
    for k=1:numel(generations)
        corrections{end+1}=table(row.Problem,row.Variant,row.Seed,generations(k),stored(k),0, ...
            'VariableNames',{'Problem','Variant','Seed','Generation','StoredVariance','CorrectedVariance'}); %#ok<AGROW>
    end
end
save(fullfile(folder,'corrected_variance_diagnostic.mat'),'diagnostics','corrections');
if ~isempty(corrections),writetable(vertcat(corrections{:}),fullfile(folder,'variance_diagnostic_corrections.csv'));end
fprintf('%s: corrected %d singleton archive diagnostic entries; frozen runs unchanged.\n',phase,numel(corrections));
end
