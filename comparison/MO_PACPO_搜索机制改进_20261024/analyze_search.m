function evidence=analyze_search(phase,makeFigures)
% Paired tests, predeclared thresholds, and curves from frozen raw runs.
root=fileparts(mfilename('fullpath'));folder=fullfile(root,'results',phase);
if nargin<2,makeFigures=true;end
data=load(fullfile(folder,'aggregate.mat'));runs=data.runs;histories=data.histories;
correctedFile=fullfile(folder,'corrected_variance_diagnostic.mat');
if isfile(correctedFile),fixed=load(correctedFile,'diagnostics');data.diagnostics=fixed.diagnostics;end
isAblation=contains(phase,'ablation');
if isAblation
    parent='confirmation';if strcmp(phase,'external_ablation'),parent='external';end
    full=load(fullfile(root,'results',parent,'aggregate.mat'));k=full.runs.Variant=="candidate";
    runs=[runs;full.runs(k,:)];histories=[histories,full.histories(:,k)];
end
tasks=unique(runs.Problem,'stable');modes=unique(runs.Variant,'stable');
comparators=setdiff(modes,"candidate",'stable');stats={};speed={};criteria={};diagrows={};
for k=1:numel(tasks)
    a=sortrows(runs(runs.Problem==tasks(k) & runs.Variant=="candidate",:),'Seed');
    for j=1:numel(comparators)
        b=sortrows(runs(runs.Problem==tasks(k) & runs.Variant==comparators(j),:),'Seed');
        assert(isequal(a.Seed,b.Seed),'Paired seeds differ');
        for metric=["IGD","HV","SP"]
            delta=a.(metric)-b.(metric);nz=delta(delta~=0);
            if isempty(nz),pv=1;effect=0;
            else,pv=signrank(delta,0,'method','approximate');w=tiedrank(abs(nz));effect=sum(sign(nz).*w)/sum(w);end
            direction=1;if metric~="HV",direction=-1;end
            stats{end+1}=table(tasks(k),comparators(j),metric,mean(delta),median(delta),direction*effect,pv, ...
                'VariableNames',{'Problem','Comparator','Metric','MeanDifference','MedianDifference','CandidateEffect','RawP'}); %#ok<AGROW>
        end
    end
    if ~isAblation
        baseline=groupsummary(runs(runs.Problem==tasks(k) & ismember(runs.Variant,["NSGAII","MOEAD","MOPSO"]),:),'Variant','mean','HV');
        target=.95*max(baseline.mean_HV);
        for j=1:numel(modes)
            rows=find(runs.Problem==tasks(k) & runs.Variant==modes(j));hits=nan(numel(rows),1);
            for r=1:numel(rows)
                idx=find(histories(:,rows(r))>=target,1);
                if ~isempty(idx),hits(r)=100*idx;end
            end
            speed{end+1}=table(tasks(k),modes(j),target,sum(isfinite(hits)),numel(hits),median(hits,'omitnan'), ...
                'VariableNames',{'Problem','Variant','HVTarget','Reached','Runs','MedianFEAmongReached'}); %#ok<AGROW>
        end
        mopso=runs(runs.Problem==tasks(k) & runs.Variant=="MOPSO",:);
        best=groupsummary(runs(runs.Problem==tasks(k) & ismember(runs.Variant,["NSGAII","MOEAD","MOPSO"]),:),'Variant','median','HV');
        criteria{end+1}=table(tasks(k),median(a.IGD),median(mopso.IGD),median(a.HV),median(mopso.HV),max(best.median_HV), ...
            median(a.IGD)<=1.1*median(mopso.IGD),median(a.HV)>=.95*median(mopso.HV),median(a.HV)>=.95*max(best.median_HV), ...
            'VariableNames',{'Problem','CandidateIGD','MOPSOIGD','CandidateHV','MOPSOHV','BestBaselineHV','IGDPass','HVPass','BestHVPass'}); %#ok<AGROW>
    end
    for mode=["candidate","legacy"]
        rows=find(data.runs.Problem==tasks(k) & data.runs.Variant==mode);
        if isempty(rows),continue;end
        for interval=[1,201]
            z=mean(data.diagnostics(interval:interval+49,:,rows),[1,3]);
            diagrows{end+1}=table(tasks(k),mode,interval,z(1),z(2),z(3),z(4),z(5),z(6),z(7), ...
                'VariableNames',{'Problem','Variant','FirstGeneration','DominanceRate','SurvivalRate','ArchiveEntryRate','BoundaryFraction','StepRMS','VarianceTrace','SigmaFactor'}); %#ok<AGROW>
        end
    end
end
statistics=vertcat(stats{:});statistics.HolmP=zeros(height(statistics),1);statistics.Outcome=repmat("not_significant",height(statistics),1);
for metric=["IGD","HV","SP"]
    k=statistics.Metric==metric;statistics.HolmP(k)=PACPOSearch.holm(statistics.RawP(k));
end
statistics.Outcome(statistics.HolmP<.05 & statistics.CandidateEffect>0)="candidate_better";
statistics.Outcome(statistics.HolmP<.05 & statistics.CandidateEffect<0)="candidate_worse";
writetable(statistics,fullfile(folder,'paired_statistics.csv'));
if ~isempty(diagrows),writetable(vertcat(diagrows{:}),fullfile(folder,'diagnostic_summary.csv'));end
evidence=struct('phase',phase,'runs',height(data.runs),'FE',sum(data.runs.FE),'holmFamily','all problems and comparators within each metric');
if ~isempty(criteria)
    criteria=vertcat(criteria{:});speed=vertcat(speed{:});writetable(criteria,fullfile(folder,'comparability.csv'));writetable(speed,fullfile(folder,'time_to_target.csv'));
    evidence.IGDPass=sum(criteria.IGDPass);evidence.HVPass=sum(criteria.HVPass);evidence.BestHVPass=sum(criteria.BestHVPass);
    if strcmp(phase,'confirmation')
        evidence.DTLZ1MeanIGD=mean(runs.IGD(runs.Problem=="DTLZ1" & runs.Variant=="candidate"));
        evidence.passed=evidence.IGDPass>=4 && evidence.HVPass>=4 && evidence.BestHVPass>=3 && evidence.DTLZ1MeanIGD<.5;
    end
end
SearchExperiment.json(fullfile(folder,'evidence.json'),evidence);
save(fullfile(folder,'analysis.mat'),'statistics','runs','histories');
if ~isAblation && makeFigures,makecurves(root,phase,tasks,modes,runs,histories);end
disp(evidence);
end
function makecurves(root,phase,tasks,modes,runs,histories)
fig=figure('Visible','off','Position',[100,100,1400,760]);tiledlayout(2,3,'TileSpacing','compact','Padding','compact');colors=lines(numel(modes));
for k=1:numel(tasks)
    nexttile;hold on;
    for j=1:numel(modes)
        h=histories(:,runs.Problem==tasks(k) & runs.Variant==modes(j));q=quantile(h,[.25,.5,.75],2);x=(100:100:25100)'/1000;
        fill([x;flipud(x)],[q(:,1);flipud(q(:,3))],colors(j,:),'FaceAlpha',.09,'EdgeColor','none','HandleVisibility','off');
        handles(j)=plot(x,q(:,2),'Color',colors(j,:),'LineWidth',1.4,'DisplayName',char(modes(j))); %#ok<AGROW>
    end
    title(tasks(k));xlabel('Function evaluations / 1000');ylabel('Normalized HV');grid on;
end
nexttile;axis off;hold on;
labels=replace(modes,["candidate","legacy","NSGAII","MOEAD","MOPSO"], ...
    ["MO-PACPO revised","MO-PACPO previous","NSGA-II","MOEA/D-SBX","MOPSO-CD"]);
for j=1:numel(modes),plot(nan,nan,'Color',colors(j,:),'LineWidth',1.5,'DisplayName',char(labels(j)));end
legend('Location','northwest','Interpreter','none');
text(.02,.35,'Lines: median; shaded: interquartile range','Units','normalized');
figdir=fullfile(root,'figures');if ~isfolder(figdir),mkdir(figdir);end
exportgraphics(fig,fullfile(figdir,[phase,'_convergence.png']),'Resolution',200);
exportgraphics(fig,fullfile(figdir,[phase,'_convergence.pdf']),'ContentType','vector');
savefig(fig,fullfile(figdir,[phase,'_convergence.fig']));close(fig);
end
