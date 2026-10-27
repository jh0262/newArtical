function evidence=analyze_physical_search()
root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));
folder=fullfile(root,'results','physical');oldroot=fullfile(fileparts(root),'MO_PACPO_机构模型修正版_20261023');
aggregate=load(fullfile(folder,'aggregate.mat'));old=load(fullfile(oldroot,'results','physical_summary_data.mat'),'runs','histories');
p=PACPOSearch.problem('PPAR');fine=PPaPaRModel.config(262144);refined=cell(30,1);records=cell(30,1);
checkpoint=fullfile(folder,'refined.mat');
if isfile(checkpoint)
    z=load(checkpoint);refined=z.refined;records=z.records;
else
    parfor i=1:30
        seed=400000+i;z=load(fullfile(folder,sprintf('PPAR_candidate_%d.mat',seed)),'result');r=z.result;
        original=load(fullfile(oldroot,'results','runs',sprintf('physical_PACPO_%d.mat',seed)),'result');
        assert(isequal(r.evaluations(1:100,:),original.result.evaluations(1:100,:)),'Initial population/model mismatch');
        [ff,cc]=PPaPaRModel.evaluate(r.X,p.model);
        assert(max(abs(ff-r.F),[],'all')<1e-9 && isequal(cc,r.CV),'Saved objective mismatch');
        [f,cv]=PPaPaRModel.evaluate(r.X,fine);keep=cv==0 & ~any(PACPOSearch.dominance(f,cv),1)';
        [~,hv,sp]=PACPOSearch.metrics(p,f(keep,:));
        refined{i}=struct('X',r.X,'F',f,'CV',cv,'keep',keep,'seed',seed,'evaluationIDs',r.archiveIDs);
        records{i}=table("candidate",seed,r.FE,r.HV,hv,sp,r.elapsed,sum(r.history(:,4)), ...
            'VariableNames',{'Variant','Seed','FE','SearchHV','FineHV','FineSpacing','Seconds','Pulses'});
    end
    save(checkpoint,'refined','records');
end
runs=vertcat(records{:});
prior=old.runs(:,{'Algorithm','Seed','FE','SearchHV','FineHV','FineSpacing','Seconds','Pulses'});
prior.Properties.VariableNames{1}='Variant';prior.Variant=string(prior.Variant);prior.Variant(prior.Variant=="PACPO")="legacy";
runs=[runs;prior];writetable(runs,fullfile(folder,'comparison_runs.csv'));
summary=groupsummary(runs,'Variant',{'mean','std','median'},{'FineHV','FineSpacing','Pulses'});writetable(summary,fullfile(folder,'comparison_summary.csv'));
a=sortrows(runs(runs.Variant=="candidate",:),'Seed');stats={};
for mode=["legacy","NSGAII","MOEAD","MOPSO"]
    b=sortrows(runs(runs.Variant==mode,:),'Seed');assert(isequal(a.Seed,b.Seed));
    for metric=["FineHV","FineSpacing"]
        delta=a.(metric)-b.(metric);nz=delta(delta~=0);
        if isempty(nz),pv=1;effect=0;
        else,pv=signrank(delta,0,'method','approximate');w=tiedrank(abs(nz));effect=sum(sign(nz).*w)/sum(w);end
        direction=1;if metric=="FineSpacing",direction=-1;end
        stats{end+1}=table(mode,metric,mean(delta),direction*effect,pv,'VariableNames',{'Comparator','Metric','MeanDifference','CandidateEffect','RawP'}); %#ok<AGROW>
    end
end
statistics=vertcat(stats{:});statistics.HolmP=zeros(height(statistics),1);statistics.Outcome=repmat("not_significant",height(statistics),1);
for metric=["FineHV","FineSpacing"]
    k=statistics.Metric==metric;statistics.HolmP(k)=PACPOSearch.holm(statistics.RawP(k));
end
statistics.Outcome(statistics.HolmP<.05 & statistics.CandidateEffect>0)="candidate_better";
statistics.Outcome(statistics.HolmP<.05 & statistics.CandidateEffect<0)="candidate_worse";
writetable(statistics,fullfile(folder,'paired_statistics.csv'));
evidence=struct('newRuns',30,'newFE',sum(a.FE),'reusedRuns',120,'model','unchanged PPaPaRModel', ...
    'searchIntegrationPoints',32768,'finalIntegrationPoints',262144,'summary',table2struct(summary),'statistics',table2struct(statistics));
SearchExperiment.json(fullfile(folder,'evidence.json'),evidence);
histories=[aggregate.histories,old.histories'];fig=figure('Visible','off','Position',[100,100,950,600]);hold on;colors=lines(5);modes=["candidate","legacy","NSGAII","MOEAD","MOPSO"];
for j=1:5
    h=histories(:,runs.Variant==modes(j));q=quantile(h,[.25,.5,.75],2);x=(100:100:25100)'/1000;
    fill([x;flipud(x)],[q(:,1);flipud(q(:,3))],colors(j,:),'FaceAlpha',.1,'EdgeColor','none','HandleVisibility','off');
    plot(x,q(:,2),'Color',colors(j,:),'LineWidth',1.5,'DisplayName',char(modes(j)));
end
xlabel('Function evaluations / 1000');ylabel('Normalized HV (search resolution)');title('2PPaPaR: median and interquartile range, 30 runs');legend('Location','southeast');grid on;
exportgraphics(fig,fullfile(root,'figures','physical_convergence.png'),'Resolution',200);exportgraphics(fig,fullfile(root,'figures','physical_convergence.pdf'),'ContentType','vector');savefig(fig,fullfile(root,'figures','physical_convergence.fig'));close(fig);
save(fullfile(folder,'analysis.mat'),'runs','summary','statistics','refined','histories');disp(summary);disp(statistics);
end
