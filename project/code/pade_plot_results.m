function manifest = pade_plot_results(analysisDir, figureDir, opts)
%PADE_PLOT_RESULTS Publication figures from COMPLETE formal PADE-FE results.
% Does not run an optimiser or statistical reanalysis, and rejects partial
% or synthetic fixtures. Each panel has an editable FIG, 300-dpi PNG and a
% vector PDF. Source data CSVs and bilingual captions accompany the plots.
% Example (only after the formal queue and pade_analyze have completed):
% pade_plot_results(fullfile(pkg,'analysis'),fullfile(pkg,'figures'))
arguments
    analysisDir (1,1) string
    figureDir (1,1) string
    opts.Languages (1,:) string {mustBeMember(opts.Languages,["en","zh"])} = ["en","zh"]
    opts.ExpectedTotalRuns (1,1) double {mustBeInteger,mustBePositive} = 5640
    opts.ExpectedSeeds (:,1) double = (1001:1030)'
    opts.GridPoints (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(opts.GridPoints,2)} = 501
    opts.Visible (1,1) string {mustBeMember(opts.Visible,["on","off"])} = "off"
    opts.FontEnglish (1,1) string = "Arial"
    opts.FontChinese (1,1) string = "微软雅黑"
end
source=load(fullfile(analysisDir,'analysis.mat'),'analysis'); A=source.analysis;
source=load(fullfile(analysisDir,'raw.mat'),'raw'); raw=source.raw;
validateFormal(A,raw,opts);
if ~isfolder(figureDir), mkdir(figureDir); end
dataDir=fullfile(figureDir,'source_data'); if ~isfolder(dataDir), mkdir(dataDir); end
palette=struct('full',[0 0.4470 0.6980],'parent',[0.10 0.10 0.10],...
    'classic',[0.90 0.6240 0],'loss',[0.835 0.369 0],'neutral',[0.72 0.72 0.72]);
core=["F01","F03","F05","F08","F09","F23"];
engineering=["WB","CB","PV"];
curves=curveData(A,raw,[core,engineering],opts.GridPoints);
[activity,pvActivity]=activityData(A);
writetable(curves,fullfile(dataDir,'equal_FE_curves.csv'),'Encoding','UTF-8');
writetable(activity,fullfile(dataDir,'full_mechanism_activity.csv'),'Encoding','UTF-8');
writetable(pvActivity,fullfile(dataDir,'PV_mechanism_activity.csv'),'Encoding','UTF-8');
writetable(A.tests,fullfile(dataDir,'prespecified_effects.csv'),'Encoding','UTF-8');
writetable(A.runs(ismember(A.runs.problem_id,engineering),:),...
    fullfile(dataDir,'engineering_all_runs.csv'),'Encoding','UTF-8');
entries=repmat(struct('id',"",'language',"",'fig',"",'png',"",'pdf',"",'caption',""),0,1);
for language=unique(opts.Languages,'stable')
    if language=="zh", font=opts.FontChinese; else, font=opts.FontEnglish; end
    available=string(listfonts);
    assert(any(strcmpi(available,font)),'pade:FigureFont','Requested figure font unavailable: %s',font);
    flow=pade_plot_flow(figureDir,Language=language,Visible=opts.Visible);
    entries(end+1,1)=struct('id',"00_algorithm_flow",'language',language,...
        'fig',flow.fig,'png',flow.png,'pdf',flow.pdf,'caption',flow.caption); %#ok<AGROW>
    figures={@() benchmarkFigure(curves,core,language,font,palette,opts),...
        @() engineeringConvergence(curves,engineering,language,font,palette,opts),...
        @() mainFamilyFigure(A,language,font,palette,opts),...
        @() ablationFigure(A,language,font,opts),...
        @() activityFigure(activity,pvActivity,language,font,palette,opts),...
        @() distributionFigure(A,engineering,language,font,palette,opts)};
    ids=["01_equal_FE_benchmarks","02_equal_FE_engineering","03_main_comparisons",...
        "04_mechanism_ablation","05_mechanism_activity","06_engineering_distributions"];
    for k=1:numel(figures)
        fig=figures{k}(); cleanup=onCleanup(@() closeIfValid(fig));
        stem=fullfile(figureDir,ids(k)+"_"+language);
        savefig(fig,stem+".fig");
        drawnow;
        exportgraphics(fig,stem+".png",'Resolution',300,'BackgroundColor','white',...
            'Padding',0.2,'Units','centimeters');
        exportgraphics(fig,stem+".pdf",'ContentType','vector','BackgroundColor','white',...
            'Padding',0.2,'Units','centimeters');
        caption=figureCaption(k,language);
        writeText(stem+"_caption.txt",caption);
        entries(end+1,1)=struct('id',ids(k),'language',language,...
            'fig',stem+".fig",'png',stem+".png",'pdf',stem+".pdf",'caption',caption); %#ok<AGROW>
        clear cleanup
    end
end
manifest=struct('scope','Figures from complete formal PADE-FE v4 runs only',...
    'created_at',char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")),...
    'analysis_directory',analysisDir,'formal_run_count',height(A.runs),...
    'figure_count',numel(entries),'entries',entries,'options',opts,...
    'quantiles','R7 linear empirical quantiles; IQR is spread, not a confidence interval',...
    'convergence','FE-aligned last actual incumbent from lossless improvement log; no linear interpolation',...
    'effect_direction','Positive favours the prespecified a_id; never interpreted as equivalence when nonsignificant',...
    'display_variant_aliases',struct('Classic','CLASSIC_DE'),...
    'publication_fonts','Source axes 14pt, legends 13pt, panel titles 15pt; 26-27cm source width for 14.8cm insertion');
save(fullfile(figureDir,'FIGURE_MANIFEST.mat'),'manifest');
writeText(fullfile(figureDir,'FIGURE_MANIFEST.json'),jsonencode(manifest,'PrettyPrint',true));
writeText(fullfile(figureDir,'README_图表说明.md'),figureReadme());
end

function validateFormal(A,raw,opts)
assert(height(A.runs)==opts.ExpectedTotalRuns&&numel(raw)==height(A.runs),...
    'pade:IncompleteFigures','Formal run coverage is incomplete; do not plot partial results as final.');
assert(all(A.runs.status=="complete")&&all(A.summaries.complete)&&all(A.tests.complete));
assert(~A.options.AllowPartial,'pade:PartialAnalysis','Use the complete formal analysis.');
assert(all(A.runs.FE==A.runs.budget_FE),'pade:FigureBudget','Terminal FE does not equal budget.');
assert(numel(unique(A.runs.problem_id))==26,'pade:FigureCoverage','Expected all 26 problems.');
groups=unique(A.runs(:,{'problem_id','variant_id'}),'rows');
for k=1:height(groups)
    select=A.runs.problem_id==groups.problem_id(k)&A.runs.variant_id==groups.variant_id(k);
    assert(isequal(sort(A.runs.seed(select)),sort(opts.ExpectedSeeds)),...
        'pade:FigureSeeds','Formal seed set differs from the frozen protocol.');
end
for k=1:numel(raw)
    r=raw{k};
    assert(isfield(r,'algorithm_version')&&string(r.algorithm_version)=="PADE-FE-v4.0",...
        'pade:NotFormal','Not a formal PADE-FE v4 result; synthetic fixtures are prohibited.');
    assert(isfield(r,'code_hash')&&strlength(string(r.code_hash))>0);
end
end

function curves=curveData(A,raw,problems,nPoints)
rows=repmat(struct('problem_id',"",'variant_id',"",'FE',0,'n_runs',0,...
    'n_feasible',0,'feasible_rate',0,'median_feasible_f',NaN,...
    'q25_feasible_f',NaN,'q75_feasible_f',NaN,'mean_feasible_f',NaN),0,1);
for problem=problems
    for variant=[fullID(problem),"G0P0J0","CLASSIC_DE"]
        sub=A.runs(A.runs.problem_id==problem&A.runs.variant_id==variant,:);
        assert(~isempty(sub)); n=height(sub); first=inf; last=unique(sub.FE);
        assert(isscalar(last),'pade:CurveBudget','Unequal budgets within curve.');
        for j=1:n, first=min(first,raw{sub.raw_index(j)}.events.init_FE); end
        grid=unique(round(linspace(first,last,nPoints)));
        f=nan(n,numel(grid)); cv=f;
        for j=1:n
            r=raw{sub.raw_index(j)};
            assert(isfield(r,'improvement_log')&&~isempty(r.improvement_log));
            log=r.improvement_log; index=1;
            for g=1:numel(grid)
                while index<size(log,1)&&log(index+1,1)<=grid(g), index=index+1; end
                assert(log(index,1)<=grid(g));
                f(j,g)=log(index,2); cv(j,g)=log(index,3);
            end
            assert(f(j,end)==r.best_f&&cv(j,end)==r.best_cv);
        end
        for g=1:numel(grid)
            feasible=cv(:,g)==0; values=f(feasible,g);
            q=empiricalQuantile(values,[0.25 0.5 0.75]);
            row=struct('problem_id',problem,'variant_id',variant,'FE',grid(g),...
                'n_runs',n,'n_feasible',sum(feasible),'feasible_rate',mean(feasible),...
                'median_feasible_f',q(2),'q25_feasible_f',q(1),...
                'q75_feasible_f',q(3),'mean_feasible_f',mean(values));
            rows(end+1,1)=row; %#ok<AGROW>
        end
    end
end
curves=struct2table(rows);
end

function [full,pv]=activityData(A)
problems=[compose("F%02d",1:23),"WB","CB","PV"];
rows=repmat(activityRow(),numel(problems),1);
for k=1:numel(problems)
    sub=A.runs(A.runs.problem_id==problems(k)&A.runs.variant_id==fullID(problems(k)),:);
    rows(k)=activitySummary(sub,problems(k),fullID(problems(k)));
end
full=struct2table(rows);
ids=unique(A.runs.variant_id(A.runs.problem_id=="PV"),'stable');
ids=ids(ids~="CLASSIC_DE"); rows=repmat(activityRow(),numel(ids),1);
for k=1:numel(ids)
    sub=A.runs(A.runs.problem_id=="PV"&A.runs.variant_id==ids(k),:);
    rows(k)=activitySummary(sub,"PV",ids(k));
end
pv=struct2table(rows);
end

function r=activityRow()
r=struct('problem_id',"",'variant_id',"",'n_runs',0,'rotation_trial_fraction',0,...
    'pulse_FE_fraction',0,'pulse_active_run_fraction',0,'pulse_acceptance',NaN,...
    'jitter_candidate_fraction',0,'jitter_effective_coordinate_fraction',0);
end

function r=activitySummary(sub,problem,variant)
r=activityRow(); r.problem_id=problem; r.variant_id=variant; r.n_runs=height(sub);
assert(~isempty(sub)); trials=sub.event_trial_FE;
r.rotation_trial_fraction=mean(sub.event_rot_trials./trials);
r.pulse_FE_fraction=mean(sub.event_pulse_FE./sub.FE);
r.pulse_active_run_fraction=mean(sub.event_pulse_trials>0);
active=sub.event_pulse_trials>0;
if any(active), r.pulse_acceptance=mean(sub.event_pulse_success(active)./sub.event_pulse_trials(active)); end
r.jitter_candidate_fraction=mean(sub.event_jitter_candidates./trials);
if problem=="PV"
    r.jitter_effective_coordinate_fraction=mean(sub.event_jitter_effective./(2*trials));
end
end

function fig=benchmarkFigure(curves,problems,language,font,palette,opts)
fig=newFigure(26,17,opts); layout=tiledlayout(fig,2,3,'TileSpacing','compact','Padding','loose');
for k=1:numel(problems)
    ax=nexttile(layout); hold(ax,'on');
    drawCurves(ax,curves,problems(k),language,palette);
    title(ax,sprintf('(%c) %s',char('a'+k-1),problems(k)),'Interpreter','none');
    xlabel(ax,tr(language,'Evaluations (10^3)','评价次数（千次）'));
    ylabel(ax,tr(language,'Median objective','目标中位数'));
    setAxes(ax,font); honestScale(ax,curves(curves.problem_id==problems(k),:));
end
sharedLegend(layout,ax,font);
title(layout,tr(language,'Equal-FE convergence on six benchmark problems',...
    '六个基准问题的相同 FE 收敛比较'),'FontName',font,'FontSize',16);
end

function fig=engineeringConvergence(curves,problems,language,font,palette,opts)
fig=newFigure(26,17,opts); layout=tiledlayout(fig,2,3,'TileSpacing','compact','Padding','loose');
for k=1:3
    ax=nexttile(layout,k); hold(ax,'on'); drawCurves(ax,curves,problems(k),language,palette);
    title(ax,sprintf('(%c) %s',char('a'+k-1),problems(k)),'Interpreter','none');
    xlabel(ax,tr(language,'Evaluations (10^3)','评价次数（千次）'));
    ylabel(ax,tr(language,'Feasible objective','可行目标值'));
    setAxes(ax,font);
    ax=nexttile(layout,k+3); hold(ax,'on');
    ids=[fullID(problems(k)),"G0P0J0","CLASSIC_DE"];
    for j=1:3
        s=curves(curves.problem_id==problems(k)&curves.variant_id==ids(j),:);
        [color,style,label]=curveStyle(j,language,palette);
        stairs(ax,s.FE/1000,s.feasible_rate,'Color',color,'LineStyle',style,...
            'LineWidth',1.5,'DisplayName',label);
    end
    ylim(ax,[-0.02 1.02]); yticks(ax,[0 0.25 0.5 0.75 1]);
    xlabel(ax,tr(language,'Evaluations (10^3)','评价次数（千次）'));
    ylabel(ax,tr(language,'Feasible fraction','可行运行比例')); setAxes(ax,font);
end
sharedLegend(layout,ax,font);
title(layout,tr(language,'Engineering convergence and strict feasibility (CV = 0)',...
    '工程问题收敛与严格可行率（CV = 0）'),'FontName',font,'FontSize',16);
end

function drawCurves(ax,curves,problem,language,palette)
ids=[fullID(problem),"G0P0J0","CLASSIC_DE"];
for k=1:3
    s=curves(curves.problem_id==problem&curves.variant_id==ids(k),:);
    [color,style,label]=curveStyle(k,language,palette); x=s.FE'/1000;
    low=s.q25_feasible_f'; high=s.q75_feasible_f'; ok=isfinite(low)&isfinite(high);
    if any(ok)
        [stepX,stepLow]=stairs(x(ok),low(ok));
        [~,stepHigh]=stairs(x(ok),high(ok));
        stepX=stepX(:)'; stepLow=stepLow(:)'; stepHigh=stepHigh(:)';
        fill(ax,[stepX,fliplr(stepX)],[stepLow,fliplr(stepHigh)],color,...
            'FaceAlpha',0.12,'EdgeColor','none','HandleVisibility','off');
    end
    stairs(ax,x,s.median_feasible_f,'Color',color,'LineStyle',style,...
        'LineWidth',1.6,'DisplayName',label);
end
end

function honestScale(ax,sub)
% A logarithmic axis is used only when all plotted quartiles are positive.
% Exact zeros remain zeros: no floor or replacement is introduced.
values=[sub.q25_feasible_f;sub.q75_feasible_f]; values=values(isfinite(values));
if ~isempty(values)&&all(values>0)&&max(values)/min(values)>100
    set(ax,'YScale','log');
end
end

function fig=mainFamilyFigure(A,language,font,palette,opts)
fig=newFigure(27,21,opts); layout=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','loose');
families=["full_vs_parent","full_vs_classic","spectral_scaling",...
    "axis_with_pulse","pulse_with_geometry","jitter_pressure_vessel"];
observed=unique(A.tests.family_id,'stable');
families=families(ismember(families,observed));
% Preserve unforeseen frozen family names rather than silently omitting them.
families=[families,setdiff(observed',families,'stable')];
counts=zeros(numel(families),3);
for k=1:numel(families)
    s=A.tests(A.tests.family_id==families(k),:);
    counts(k,:)=[sum(s.decision=="a_better"),sum(s.decision=="not_significant"),sum(s.decision=="b_better")];
end
ax=nexttile(layout); bars=barh(ax,1:numel(families),counts,'stacked');
bars(1).FaceColor=palette.full; bars(2).FaceColor=palette.neutral; bars(3).FaceColor=palette.loss;
ax.YDir='reverse'; yticks(ax,1:numel(families)); yticklabels(ax,familyLabels(families,language));
xlabel(ax,tr(language,'Number of prespecified problem/contrast tests','预设问题/对照检验数'));
title(ax,tr(language,'(a) Holm decisions by family','(a) 各 family 的 Holm 结果'));
legend(ax,tr(language,{'Better','No detected difference','Worse'},...
    {'显著更优','未检出显著差异','显著更差'}),'Location','southoutside','Box','off','FontSize',13); setAxes(ax,font);
for k=1:size(counts,1)
    offset=0;
    for j=1:3
        if counts(k,j)>0
            text(ax,offset+counts(k,j)/2,k,string(counts(k,j)),...
                'HorizontalAlignment','center','FontName',font,'FontSize',13,'Color',[0 0 0]);
        end
        offset=offset+counts(k,j);
    end
end
ax=nexttile(layout); effectHeatmap(ax,A.tests,["full_vs_parent","full_vs_classic"],language,font);
title(ax,tr(language,'(b) Paired effects (Holm markers)',...
    '(b) 配对效应（圆圈为 Holm 显著）'));
title(layout,tr(language,'Prespecified main comparisons and mechanism families',...
    '预设主要对照与机制 family'),'FontName',font,'FontSize',16);
end

function fig=ablationFigure(A,language,font,opts)
fig=newFigure(27,21,opts); layout=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','loose');
ax=nexttile(layout); effectHeatmap(ax,A.tests,...
    ["axis_with_pulse","spectral_scaling","pulse_with_geometry"],language,font);
title(ax,tr(language,'(a) Mechanism contrasts', '(a) 固定条件的机制对照'));
ax=nexttile(layout); hold(ax,'on');
s=A.tests(A.tests.problem_id=="PV"&~ismember(A.tests.family_id,...
    ["full_vs_parent","full_vs_classic","axis_with_pulse","spectral_scaling","pulse_with_geometry"]),:);
assert(height(s)==6,'pade:JitterFigure','Expected the six prespecified PV trial-jitter contrasts.');
for k=1:height(s)
    if s.reject_holm(k), face=[0 0.447 0.698]; else, face=[1 1 1]; end
    plot(ax,s.effect(k),k,'o','MarkerFaceColor',face,'MarkerEdgeColor',[0 0 0],'MarkerSize',7);
    text(ax,1.08,k,sprintf('p_H = %.3g',s.p_holm(k)),'FontName',font,'FontSize',13,'Interpreter','none');
end
xline(ax,0,':','Color',[0.5 0.5 0.5]); xlim(ax,[-1.05 1.80]); xticks(ax,[-1 -0.5 0 0.5 1]);
ylim(ax,[0.5 height(s)+0.5]); ax.YDir='reverse'; yticks(ax,1:height(s));
labels=extractBefore(string(s.a_id),"J")+": J1 / J0"; yticklabels(ax,labels);
xlabel(ax,tr(language,'Paired effect (+ favours J1)','配对效应（正值有利于 J1）'));
title(ax,tr(language,'(b) PV trial-jitter contrasts','(b) PV trial 离散抖动对照'));
setAxes(ax,font);
title(layout,tr(language,'Core mechanism ablation at equal evaluation budgets',...
    '相同评价预算下的核心机制消融'),'FontName',font,'FontSize',16);
end

function effectHeatmap(ax,tests,families,language,font)
problems=[compose("F%02d",1:23),"WB","CB","PV"];
effect=nan(numel(problems),numel(families)); significant=false(size(effect));
for j=1:numel(families)
    for k=1:numel(problems)
        s=tests(tests.family_id==families(j)&tests.problem_id==problems(k),:);
        assert(height(s)==1,'pade:EffectCoverage','Expected one frozen contrast per problem/family.');
        effect(k,j)=s.effect; significant(k,j)=s.reject_holm;
    end
end
handle=imagesc(ax,effect,[-1 1]); handle.AlphaData=isfinite(effect);
colormap(ax,divergingMap()); cb=colorbar(ax); cb.FontName=font; cb.FontSize=14; hold(ax,'on');
[yy,xx]=find(significant); plot(ax,xx,yy,'o','MarkerSize',5,...
    'MarkerFaceColor','none','MarkerEdgeColor','k','LineWidth',1);
xticks(ax,1:numel(families)); xticklabels(ax,compactFamilyLabels(families,language));
xtickangle(ax,0); yticks(ax,1:numel(problems)); yticklabels(ax,problems);
ax.YDir='reverse'; setAxes(ax,font); ax.XGrid='off'; ax.YGrid='off';
end

function fig=activityFigure(activity,pv,language,font,palette,opts)
fig=newFigure(26,26,opts); layout=tiledlayout(fig,4,1,'TileSpacing','compact','Padding','loose');
fields=["rotation_trial_fraction","pulse_FE_fraction","pulse_active_run_fraction"];
english=["(a) Rotation attempts / ordinary trial FE","(b) Pulse FE / total FE",...
    "(c) Runs with at least one pulse / 30"];
chinese=["(a) 旋转候选数 / 普通候选 FE","(b) 脉冲 FE / 总 FE",...
    "(c) 至少触发一次脉冲的运行比例"];
for k=1:3
    ax=nexttile(layout); bar(ax,activity.(fields(k)),'FaceColor',palette.full,'EdgeColor','none');
    xticks(ax,1:height(activity)); xticklabels(ax,activity.problem_id); xtickangle(ax,90);
    ylabel(ax,tr(language,'Fraction','比例')); title(ax,tr(language,english(k),chinese(k)));
    setAxes(ax,font);
    if fields(k)=="pulse_FE_fraction", floorMax=1e-4; else, floorMax=0.02; end
    ylim(ax,[0 max(floorMax,max(activity.(fields(k)))*1.15)]);
end
ax=nexttile(layout); bar(ax,pv.jitter_effective_coordinate_fraction,...
    'FaceColor',palette.full,'EdgeColor','none');
xticks(ax,1:height(pv)); xticklabels(ax,pv.variant_id); xtickangle(ax,90);
ylabel(ax,tr(language,'Effective jitter fraction','有效抖动比例'));
title(ax,tr(language,'(d) PV jitter activity across all ablations','(d) PV 各消融配置的抖动活动'));
setAxes(ax,font);
ylim(ax,[0 max(0.25,max(pv.jitter_effective_coordinate_fraction)*1.15)]);
title(layout,tr(language,'Observed mechanism activity and evaluation cost',...
    '实际机制活动及函数评价代价'),'FontName',font,'FontSize',16);
end

function fig=distributionFigure(A,problems,language,font,palette,opts)
fig=newFigure(26,25,opts); layout=tiledlayout(fig,3,2,'TileSpacing','compact','Padding','loose');
for p=1:3
    runs=A.runs(A.runs.problem_id==problems(p),:);
    variants=pade_variants(problems(p)=="PV"); ids=string({variants.id});
    ax=nexttile(layout,2*p-1); hold(ax,'on'); feasibleRates=zeros(numel(ids),1);
    for k=1:numel(ids)
        group=sortrows(runs(runs.variant_id==ids(k),:),'seed');
        feasible=group.best_cv==0; values=group.best_f(feasible);
        feasibleRates(k)=mean(feasible); color=palette.neutral;
        if ids(k)==fullID(problems(p)), color=palette.full;
        elseif ids(k)=="G0P0J0", color=palette.parent;
        elseif ids(k)=="CLASSIC_DE", color=palette.classic; end
        drawEmpiricalBox(ax,k,values,color);
    end
    xticks(ax,1:numel(ids)); xticklabels(ax,displayVariants(ids)); xtickangle(ax,90);
    xlim(ax,[0.4 numel(ids)+0.6]); title(ax,sprintf('(%c) %s',char('a'+p-1),problems(p)));
    ylabel(ax,tr(language,'Final feasible objective','最终可行目标值')); setAxes(ax,font);
    ax=nexttile(layout,2*p); bars=bar(ax,feasibleRates,'FaceColor','flat','EdgeColor','none');
    bars.CData=repmat(palette.neutral,numel(ids),1);
    bars.CData(ids==fullID(problems(p)),:)=palette.full;
    xticks(ax,1:numel(ids)); xticklabels(ax,displayVariants(ids)); xtickangle(ax,90); ylim(ax,[0 1.4]);
    yticks(ax,[0 0.25 0.5 0.75 1]);
    for k=1:numel(ids)
        text(ax,k,feasibleRates(k)+0.025,sprintf('%d/30',round(feasibleRates(k)*30)),...
            'Rotation',90,'FontSize',13,'HorizontalAlignment','left','FontName',font);
    end
    ylabel(ax,tr(language,'Feasible fraction','严格可行运行比例')); setAxes(ax,font);
    title(ax,tr(language,problems(p)+": feasibility",problems(p)+"：可行率"));
end
title(layout,tr(language,'Engineering distributions over all 30 prespecified seeds',...
    '全部 30 个预设种子的工程结果分布'),'FontName',font,'FontSize',16);
end

function drawEmpiricalBox(ax,x,values,color)
values=sort(values(:));
if isempty(values), return; end
q=empiricalQuantile(values,[0.25 0.5 0.75]); spread=q(3)-q(1);
inside=values(values>=q(1)-1.5*spread&values<=q(3)+1.5*spread);
whisker=[min(inside),max(inside)]; width=0.28;
plot(ax,[x x],whisker,'-','Color',color,'LineWidth',1);
plot(ax,x+[-0.12 0.12],[whisker(1) whisker(1)],'-','Color',color);
plot(ax,x+[-0.12 0.12],[whisker(2) whisker(2)],'-','Color',color);
patch(ax,x+[-width width width -width],[q(1) q(1) q(3) q(3)],color,...
    'FaceAlpha',0.18,'EdgeColor',color,'LineWidth',1);
plot(ax,x+[-width width],[q(2) q(2)],'-','Color',color,'LineWidth',1.4);
% Deterministic offsets show every observed value without drawing RNGs.
offset=linspace(-0.13,0.13,numel(values))';
plot(ax,x+offset,values,'.','Color',color,'MarkerSize',5);
end

function q=empiricalQuantile(values,probability)
values=sort(values(isfinite(values))); values=values(:);
q=nan(size(probability)); n=numel(values); if n==0, return; end
for k=1:numel(probability)
    h=1+(n-1)*probability(k); low=floor(h); high=ceil(h);
    q(k)=values(low)+(h-low)*(values(high)-values(low));
end
end

function id=fullID(problem)
if problem=="PV", id="G2P1J1"; else, id="G2P1J0"; end
end

function labels=displayVariants(ids)
labels=string(ids); labels(labels=="CLASSIC_DE")="Classic";
end

function sharedLegend(layout,ax,font)
legendHandle=legend(ax,'Orientation','horizontal','Box','off','FontSize',13,'FontName',font);
legendHandle.Layout.Tile='south';
end

function [color,style,label]=curveStyle(index,language,palette)
switch index
    case 1, color=palette.full; style='-'; label=tr(language,'Full PADE-FE','完整 PADE-FE');
    case 2, color=palette.parent; style='--'; label=tr(language,'Adaptive DE parent','同父自适应 DE');
    case 3, color=palette.classic; style=':'; label=tr(language,'Classical DE','经典 DE');
end
end

function labels=familyLabels(families,language)
labels=strings(size(families));
for k=1:numel(families)
    switch families(k)
        case "full_vs_parent", labels(k)=tr(language,'Full / adaptive parent','完整 / 自适应父算法');
        case "full_vs_classic", labels(k)=tr(language,'Full / classical DE','完整 / 经典 DE');
        case "axis_with_pulse", labels(k)=tr(language,'Axis crossover | P1','主轴交叉 | P1');
        case "spectral_scaling", labels(k)=tr(language,'Spectral scale | G1P1','谱尺度 | G1P1');
        case "pulse_with_geometry", labels(k)=tr(language,'Pulse | G2','双锁脉冲 | G2');
        case "jitter_pressure_vessel", labels(k)=tr(language,'PV trial jitter','PV trial 离散抖动');
        otherwise, labels(k)=strrep(families(k),'_',' ');
    end
end
end

function map=divergingMap()
orange=[0.835 0.369 0]; white=[1 1 1]; blue=[0 0.447 0.698];
t=linspace(0,1,129)'; left=(1-t).*orange+t.*white; right=(1-t).*white+t.*blue;
map=[left;right(2:end,:)];
end

function labels=compactFamilyLabels(families,language)
% Short, horizontal labels keep the first heatmap label within the figure.
labels=strings(size(families));
for k=1:numel(families)
    switch families(k)
        case "full_vs_parent", labels(k)=tr(language,'Full / parent','完整 / 父算法');
        case "full_vs_classic", labels(k)=tr(language,'Full / classic','完整 / 经典');
        case "axis_with_pulse", labels(k)=tr(language,'Axis|P1','主轴|P1');
        case "spectral_scaling", labels(k)=tr(language,'Scale|G1P1','尺度|G1P1');
        case "pulse_with_geometry", labels(k)=tr(language,'Pulse|G2','脉冲|G2');
        otherwise, labels(k)=strrep(families(k),'_',' ');
    end
end
end

function fig=newFigure(width,height,opts)
fig=figure('Visible',opts.Visible,'Color','white','Units','centimeters',...
    'Position',[2 2 width height],'Renderer','painters');
end

function setAxes(ax,font)
set(ax,'FontName',font,'FontSize',14,'LineWidth',0.7,'Box','on',...
    'TickLabelInterpreter','none','XGrid','on','YGrid','on','GridAlpha',0.12);
ax.Title.FontName=font; ax.Title.FontSize=15;
ax.XLabel.FontName=font; ax.YLabel.FontName=font;
end

function value=tr(language,english,chinese)
if language=="zh", value=chinese; else, value=english; end
end

function closeIfValid(fig)
if isgraphics(fig), close(fig); end
end

function writeText(path,value)
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0,'pade:FigureWrite','Cannot write %s.',path);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',value);
end

function caption=figureCaption(index,language)
english=[...
    "Equal-FE convergence on the six benchmark problems selected before result analysis. Lines are median best-so-far objectives over all 30 seeds; bands are empirical interquartile ranges, not confidence intervals. Each checkpoint is reconstructed by holding the most recent actual improvement. Exact zero objectives are preserved; a log axis is used only when all plotted quartiles are positive.",...
    "Engineering convergence under identical per-problem FE budgets. Upper panels condition objective distributions on runs strictly feasible at that checkpoint (CV=0), with median and interquartile range. Lower panels show the changing feasible-run denominator explicitly. All initialization, trial and pulse evaluations count towards FE.",...
    "All prespecified comparison families are retained. The left panel counts Holm-significant improvements, no detected differences and Holm-significant degradations (a relative to b). The right panel displays signed paired effects for the two primary families; circles indicate within-family Holm significance. Effects are matched rank-biserial coefficients for signed-rank tests, or win-loss balances for mixed-feasibility sign tests. Positive effects favour the prespecified a variant.",...
    "Conditional core mechanism contrasts preserve the same remaining configuration. Axis crossover compares G1P1 with G0P1; spectral scaling compares G2P1 with G1P1; pulse compares G2P1 with G2P0. PV uses the frozen jitter setting in those families. The right panel retains all six PV J1 versus J0 contrasts; filled points indicate Holm significance. No confidence interval is implied by a point.",...
    "Observed intervention activity, averaged over the 30 runs. Rotation rate uses ordinary trial FE as denominator; pulse cost uses all FE, including initialization. Pulse activation shows the fraction of runs containing a pulse. PV jitter activity counts effective coordinate changes divided by twice the number of ordinary trial FE. Zero activity is retained and does not establish mechanism efficacy.",...
    "Final engineering results for every frozen configuration, with one row per problem. Left panels show only strictly feasible final objectives: boxes span empirical quartiles, centres are medians, whiskers extend to observed values within 1.5 IQR, and dots show every feasible run using deterministic horizontal offsets. Right panels retain all 30 runs and give feasible counts. Classic denotes the CLASSIC_DE configuration; G/P/J identifiers retain their frozen meaning. No infeasible low objective is presented as a feasible optimum. Quartiles use R7 linear empirical quantiles."];
chinese=[...
    "在结果分析前选定的六个基准问题的相同 FE 收敛比较。曲线为 30 个种子的真实 best-so-far 目标中位数，带状区域为经验四分位距，不是置信区间。检查点由最近一次实际改进前向保持重建，不做线性插值。零值保留；仅当所有显示四分位数均为正时使用对数轴。",...
    "工程问题在相同单题 FE 预算下的收敛。上排只统计该 FE 已严格可行（CV=0）的运行，显示其中位数与四分位距；下排明确给出随 FE 变化的可行运行比例。初始化、普通候选及脉冲候选均计入总 FE。",...
    "完整保留预设比较 family。左图统计 a 相对 b 的 Holm 显著更优、未检出差异及显著更差数量；右图给出两个主要 family 的有向配对效应，圆圈表示 family 内 Holm 显著。符号秩检验使用配对秩二列相关效应，混合可行性符号检验使用胜负平衡效应。正值有利于预设 a 配置。",...
    "固定其余配置的核心机制消融：主轴交叉比较 G1P1 与 G0P1，谱尺度比较 G2P1 与 G1P1，双锁脉冲比较 G2P1 与 G2P0；PV 按冻结协议保留对应 J 设置。右图保留全部六组 PV 的 J1/J0 对照，实心点表示 Holm 显著；单个点不表示置信区间。",...
    "30 次运行的实际干预活动均值。旋转率以普通候选 FE 为分母，脉冲评价占比以包含初始化的全部 FE 为分母；脉冲激活率为至少发生一次脉冲的运行比例。PV 抖动活动为有效坐标变更数除以普通候选 FE 的两倍。零活动按实保留，活动本身不等于性能贡献。",...
    "全部冻结配置的最终工程结果，每行一个问题。左列仅显示严格可行的最终目标：箱体为经验四分位距，中线为中位数，须延伸到 1.5 倍四分位距范围内的实际观测，点展示每个可行运行并采用确定水平偏移。右列以全部 30 次为分母给出可行率及计数。Classic 对应 CLASSIC_DE，G/P/J 标识保留冻结定义；不把不可行低目标当作可行最优。四分位数采用 R7 线性经验分位数。"];
if language=="zh", caption=chinese(index); else, caption=english(index); end
end

function text=figureReadme()
text=join(["# PADE-FE 正式结果图表",...
    "全部图来自完整正式 analysis.mat 与 raw.mat。绘图函数拒绝部分结果和统计人工夹具，不运行优化或重算主检验。",...
    "每图提供可编辑 .fig、300 dpi PNG、矢量 PDF 及中英文独立图注；source_data 保存绘图数值。英文使用 Arial，中文使用微软雅黑；图中用颜色与线型共同区分算法。00_algorithm_flow 是无结果数据的冻结实现流程图。",...
    "收敛由原始无损改进日志在共同 FE 网格前向保持，带状区域为四分位距而非置信区间。工程收敛图上排为可行子集目标、下排为全部运行可行率；工程分布图每行一题，左列为可行目标、右列为可行率。",...
    "效应方向为正有利于预设 a_id。效应图的两种统计效应名称见图注，不能把未显著解释为等价。机制活动和性能增益分别展示。",...
    "基准收敛图固定 F01/F03/F05/F08/F09/F23；未按结果优劣挑选。工程分布保留所有配置及全部可行观测，箱线采用 R7 分位数。"],newline+newline);
end

