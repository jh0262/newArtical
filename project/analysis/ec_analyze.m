function ec_analyze()
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root); ec_setup(); addpath(fullfile(root,'analysis'));
out=fullfile(root,'analysis','results'); figures=fullfile(out,'figures'); if ~isfolder(figures), mkdir(figures); end
audit=jsondecode(fileread(fullfile(out,'numerical_audit.json')));
assert(strcmp(audit.status,'PASS') && audit.runs==2080,'EC:Audit','Complete independent audit required.');
cfg=ec_config('formal'); S=readtable(fullfile(out,'verified_runs.csv'),'TextType','string');
names=string({cfg.algorithms.name}); problems=string({cfg.problems.name});
np=numel(problems); na=numel(names); ns=numel(cfg.seeds); ng=cfg.generations+1;
Y=nan(np,na,ns); H=Y; Rtime=Y; Wall=Y;
Icurve=nan(ng,np,na,ns); Hcurve=Icurve; traces=nan(500,3,np,ns);
finals=cell(np,na,ns); refs=cell(np,1);
for k=1:height(S)
    pi=find(problems==S.Problem(k)); ai=find(names==S.Algorithm(k)); si=find(cfg.seeds==S.Seed(k));
    Y(pi,ai,si)=S.IGDplus(k); H(pi,ai,si)=S.HV(k); Rtime(pi,ai,si)=S.AlgorithmSeconds(k); Wall(pi,ai,si)=S.WallSeconds(k);
    r=load(fullfile(root,S.RunPath(k),'raw.mat'),'HV','IGDplus','Telemetry','finalF','referenceF');
    Icurve(:,pi,ai,si)=r.IGDplus; Hcurve(:,pi,ai,si)=r.HV;
    finals{pi,ai,si}=r.finalF; refs{pi}=r.referenceF;
    if ai==8, traces(:,:,pi,si)=r.Telemetry(:,1:3); end
end
assert(all(isfinite(Y),'all'));
med=median(Y,3); medHV=median(H,3); medTime=median(Rtime,3); medWall=median(Wall,3);
rows=cell(np*na,11); k=0;
for pi=1:np
    for ai=1:na
        k=k+1; v=squeeze(Y(pi,ai,:));
        rows(k,:)={problems(pi),names(ai),mean(v),std(v),median(v),quantile(v,.25),quantile(v,.75),medHV(pi,ai),medTime(pi,ai),medWall(pi,ai),ns};
    end
end
summary=cell2table(rows,'VariableNames',{'Problem','Algorithm','MeanIGDplus','StdIGDplus','MedianIGDplus','Q25IGDplus','Q75IGDplus','MedianHV','MedianAlgorithmSeconds','MedianWallSeconds','Runs'});
writetable(summary,fullfile(out,'summary.csv'));
writetable(array2table(med,'VariableNames',cellstr(names),'RowNames',cellstr(problems)),fullfile(out,'median_igdplus.csv'),'WriteRowNames',true);
writetable(array2table(medHV,'VariableNames',cellstr(names),'RowNames',cellstr(problems)),fullfile(out,'median_hv.csv'),'WriteRowNames',true);
[friedmanP,~,fstats]=friedman(med,1,'off');
averageRanks=fstats.meanranks;
rankTable=table(names',averageRanks','VariableNames',{'Algorithm','AverageRank'});
rankTable=sortrows(rankTable,'AverageRank'); writetable(rankTable,fullfile(out,'friedman_ranks.csv'));
rng(730501,'twister'); % Analysis-only resampling stream, never used by optimizers.
others=setdiff(1:na,8,'stable'); statRows=cell(numel(others),10); pvalues=zeros(numel(others),1);
for k=1:numel(others)
    ai=others(k); delta=med(:,8)-med(:,ai); p=pairedp(delta); pvalues(k)=p;
    nonzero=abs(delta)>0; rr=tiedrank(abs(delta(nonzero)));
    rbc=0; if any(nonzero), rbc=sum(sign(delta(nonzero)).*rr)/sum(rr); end
    boot=median(delta(randi(np,np,20000)),1); interval=quantile(boot,[.025 .975]);
    statRows(k,:)={names(ai),p,0,median(delta),interval(1),interval(2),rbc,sum(delta<0),sum(delta==0),sum(delta>0)};
end
q=ec_holm(pvalues);
for k=1:numel(others), statRows{k,3}=q(k); end
pairwise=cell2table(statRows,'VariableNames',{'Comparator','P','HolmP','MedianDifference','BootstrapCILow','BootstrapCIHigh','PairedRankBiserial','G111Wins','Ties','G111Losses'});
writetable(pairwise,fullfile(out,'g111_pairwise_holm.csv'));
% Full factorial contrasts: negative differences favor enabling a mechanism.
terms=string({'A','B','C','AB','AC','BC','ABC'}); E=nan(np,7,ns);
factorRows=cell(np*7,6); seedRows=cell(np*7*ns,4); k=0; ks=0;
for pi=1:np
    v=squeeze(Y(pi,1:8,:))'; effects=ec_factorial(v); E(pi,:,:)=effects';
    for j=1:7
        k=k+1; z=effects(:,j); boot=mean(z(randi(ns,ns,10000)),1); ci=quantile(boot,[.025 .975]);
        factorRows(k,:)={problems(pi),terms(j),mean(z),median(z),ci(1),ci(2)};
        for si=1:ns
            ks=ks+1; seedRows(ks,:)={problems(pi),cfg.seeds(si),terms(j),z(si)};
        end
    end
end
factor=cell2table(factorRows,'VariableNames',{'Problem','Effect','MeanContrast','MedianContrast','SeedBootstrapCILow','SeedBootstrapCIHigh'});
writetable(factor,fullfile(out,'factorial_effects_by_problem.csv'));
writetable(cell2table(seedRows,'VariableNames',{'Problem','Seed','Effect','Contrast'}),fullfile(out,'factorial_seed_effects.csv'));
meanE=mean(E,3); crossRows=cell(7,7); pp=zeros(7,1);
for j=1:7
    z=meanE(:,j); pp(j)=pairedp(z); boot=median(z(randi(np,np,20000)),1); ci=quantile(boot,[.025 .975]);
    crossRows(j,:)={terms(j),median(z),ci(1),ci(2),pp(j),0,sum(z<0)};
end
qq=ec_holm(pp); for j=1:7, crossRows{j,6}=qq(j); end
writetable(cell2table(crossRows,'VariableNames',{'Effect','MedianProblemContrast','ProblemBootstrapCILow','ProblemBootstrapCIHigh','P','HolmP','FavorableProblems'}),fullfile(out,'factorial_across_problems.csv'));
ec_jsonwrite(fullfile(out,'statistical_context.json'),struct('friedmanP',friedmanP,'primaryOutcome','IGD+','unitOfAnalysis','8 fixed benchmark problems, each represented by 20-run median','pairwiseFamilySize',12,'factorialFamilySize',7,'correction','Holm, separately for the declared algorithm and exploratory contrast families','test','two-sided exact Wilcoxon signed rank; symmetry assumption and small benchmark set limit interpretation','confidenceIntervals','descriptive percentile bootstrap; 20000 problem resamples, 10000 seed resamples for problem-specific mean contrasts','analysisRngSeed',730501,'rawMetricScale','objective-wise normalized IGD+; negative contrasts favor enabling mechanisms','qualification','Eight selected and related benchmarks are not a random independent sample of all optimization problems. Bootstrap intervals and p-values do not establish universal superiority. Factorial contrast significance is supplementary; raw problem-specific effects are central.'));
% Parallel runtime reflects eight shared-machine processes, not isolated timing.
selection=[1 8 9 10 11 12 13]; colors=lines(numel(selection));
f=figure('Visible','off','Color','w','Position',[50 50 1700 760]); tiledlayout(2,4,'Padding','compact');
for pi=1:np
    nexttile; hold on;
    for s=1:numel(selection)
        v=median(squeeze(Icurve(:,pi,selection(s),:)),2,'omitnan');
        semilogy(0:10:500,max(v(1:10:end),1e-16),'LineWidth',1.25,'Color',colors(s,:));
    end
    set(gca,'YScale','log'); grid on; title(problems(pi)); xlabel('Generation'); ylabel('Median IGD+');
    if pi==1, legend(cellstr(names(selection)),'Interpreter','none','FontSize',7,'Location','best'); end
end
sgtitle('500-generation comparison: 20 runs per algorithm and problem'); savefigs(f,'convergence_igdplus');
f=figure('Visible','off','Color','w','Position',[50 50 1250 580]);
imagesc(log10(max(med(:,1:8),1e-16))); colorbar; colormap(parula);
xticks(1:8); xticklabels(names(1:8)); yticks(1:np); yticklabels(problems);
xlabel('A: ear selection; B: guide weighting; C: adaptive allocation'); title('Complete factorial ablation: log10 median IGD+ (lower is better)'); savefigs(f,'factorial_igdplus');
f=figure('Visible','off','Color','w','Position',[50 50 1250 580]);
relative=meanE./max(med(:,1),1e-15); imagesc(relative); colorbar;
limit=max(abs(relative),[],'all'); if limit==0, limit=1; end
clim([-limit limit]);
colormap([linspace(.15,1,128)' linspace(.35,1,128)' ones(128,1);ones(128,1) linspace(1,.25,128)' linspace(1,.15,128)']);
for rr=1:np
    for cc=1:7
        ink='k'; if abs(relative(rr,cc))>.65*limit, ink='w'; end
        text(cc,rr,sprintf('%.2g',relative(rr,cc)),'HorizontalAlignment','center','Color',ink,'FontSize',10);
    end
end
xticks(1:7); xticklabels(terms); yticks(1:np); yticklabels(problems);
title('Mean factorial contrast / G000 median IGD+ (negative favors enabling)'); xlabel('Main effects and interactions; visualization scaling only'); savefigs(f,'factorial_interactions');
f=figure('Visible','off','Color','w','Position',[50 50 1700 760]); tiledlayout(2,4,'Padding','compact');
for pi=1:np
    nexttile; hold on; plot(refs{pi}(:,1),refs{pi}(:,2),'.','Color',[.75 .75 .75],'MarkerSize',3);
    for s=1:numel(selection)
        ai=selection(s); [~,o]=sort(squeeze(Y(pi,ai,:))); si=o(ceil(ns/2)); front=finals{pi,ai,si};
        scatter(front(:,1),front(:,2),9,colors(s,:),'filled');
    end
    grid on; title(problems(pi)); xlabel('f1'); ylabel('f2');
    if pi==1, legend([{'Reference'} cellstr(names(selection))],'Interpreter','none','FontSize',7,'Location','best'); end
end
sgtitle('Representative runs selected by within-algorithm median IGD+ (not best runs)'); savefigs(f,'pareto_fronts');
f=figure('Visible','off','Color','w','Position',[50 50 1700 760]); tiledlayout(2,4,'Padding','compact');
for pi=1:np
    nexttile; plot(1:500,median(squeeze(traces(:,:,pi,:)),3),'LineWidth',1.1);
    ylim([0 1]); grid on; title(problems(pi)); xlabel('Generation'); ylabel('Median G111 parameter');
    if pi==1, legend('mean F','mean CR','local-arm probability','Location','best'); end
end
sgtitle('Adaptive parameters: all 20 G111 runs, per-generation medians'); savefigs(f,'adaptive_parameters');
f=figure('Visible','off','Color','w','Position',[50 50 1100 560]);
barh(rankTable.AverageRank); set(gca,'YDir','reverse'); yticks(1:na); yticklabels(rankTable.Algorithm); set(gca,'TickLabelInterpreter','none');
xlabel('Average Friedman rank (smaller is better)'); title(sprintf('IGD+ ranks on 8 problems; Friedman p = %.3g',friedmanP)); grid on; savefigs(f,'average_ranks');
save(fullfile(out,'analysis.mat'),'cfg','Y','H','Rtime','Wall','Icurve','Hcurve','traces','med','medHV','E','meanE','averageRanks','friedmanP','pairwise','-v7');
fprintf('ANALYSIS_COMPLETE runs=%d plots=6 CSV summaries written\n',height(S));
    function savefigs(fig,name)
        exportgraphics(fig,fullfile(figures,[name '.png']),'Resolution',180);
        exportgraphics(fig,fullfile(figures,[name '.pdf']),'ContentType','vector');
        close(fig);
    end
end

function p=pairedp(delta)
if all(delta==0), p=1; else, p=signrank(delta,0,'method','exact'); end
end
