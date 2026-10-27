function plot_formal()
root=fileparts(fileparts(mfilename('fullpath'))); out=fullfile(root,'analysis_formal');
R=readtable(fullfile(out,'run_metrics.csv'),'TextType','string');
C=readtable(fullfile(out,'convergence_summary.csv'),'TextType','string');
A=readtable(fullfile(out,'factorial_effects.csv'),'TextType','string');
names=["MODE-CD-G","MODE-EAR-G","MODE-CD-S","MODE-EAR-S","MV-NSGA-II","MV-SPEA2","CAT-QMC"];
short=["CD-G","EAR-G","CD-S","EAR-S","NSGA-II","SPEA2","CAT-QMC"]; colors=lines(7); cycles=[2.5,3,3.5];
f=figure('Visible','off','Color','w','Position',[100,100,1380,430]); tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
for k=1:3
    nexttile; hold on;
    for i=1:7
        rows=R(R.cycle_limit_s==cycles(k)&R.method==names(i),:); y=rows.HV; x=i+.14*sin((1:numel(y))*2.4);
        plot(x,y,'.','Color',colors(i,:),'MarkerSize',11); q=quantile(y,[.25,.5,.75]);
        plot([i i],[q(1) q(3)],'-','Color',colors(i,:),'LineWidth',3);
        plot(i+[-.22,.22],q([2 2]),'k-','LineWidth',1.4);
    end
    xticks(1:7); xticklabels(short); xtickangle(40); xlim([.5,7.5]); ylabel('Feasible HV'); grid on; title(sprintf('Cycle limit %.1f s',cycles(k))); set(gca,'FontSize',10);
end
export(f,out,'formal_hv_distribution');
f=figure('Visible','off','Color','w','Position',[100,100,1380,440]); tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
for k=1:3
    nexttile; hold on;
    for i=1:7
        rows=C(C.cycle_limit_s==cycles(k)&C.method==names(i),:); x=rows.FE;
        fill([x;flipud(x)],[rows.HV_q25;flipud(rows.HV_q75)],colors(i,:),'FaceAlpha',.07,'EdgeColor','none','HandleVisibility','off');
        plot(x,rows.HV_median,'Color',colors(i,:),'DisplayName',names(i),'LineWidth',1.2);
    end
    xlabel('Design evaluations'); ylabel('Median feasible HV'); title(sprintf('Cycle limit %.1f s',cycles(k))); grid on; set(gca,'FontSize',10);
end
lg=legend('Orientation','horizontal','NumColumns',4); lg.Layout.Tile='south'; export(f,out,'formal_convergence');
f=figure('Visible','off','Color','w','Position',[100,100,1150,390]); tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
effects=["A_ear","B_stratified","AB_interaction"];
for k=1:3
    nexttile; hold on;
    for i=1:3
        row=A(A.cycle_limit_s==cycles(k)&A.effect==effects(i),:);
        errorbar(i,row.mean_difference,row.mean_difference-row.ci95_mean_low,row.ci95_mean_high-row.mean_difference,'o','Color',colors(i,:),'LineWidth',1.5,'MarkerFaceColor',colors(i,:));
    end
    yline(0,'k:'); xticks(1:3); xticklabels({'A: ear','B: archive','Interaction'}); xlim([.5,3.5]); ylabel('Mean HV effect'); title(sprintf('Cycle limit %.1f s',cycles(k))); grid on; set(gca,'FontSize',10);
end
export(f,out,'formal_factorial');
end

function export(f,out,name)
exportgraphics(f,fullfile(out,[name,'.png']),'Resolution',200);
exportgraphics(f,fullfile(out,[name,'.pdf']),'ContentType','vector'); close(f);
end
