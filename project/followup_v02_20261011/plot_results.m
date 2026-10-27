function plot_results()
root=fileparts(mfilename('fullpath')); out=fullfile(root,'analysis');
R=readtable(fullfile(out,'run_metrics.csv'),'TextType','string');
C=readtable(fullfile(out,'paired_comparisons.csv'),'TextType','string');
H=readtable(fullfile(out,'retention_summary.csv'),'TextType','string');
names="D"+(0:5); colors=lines(6); cycles=[2.5,3.5];
f=figure('Visible','off','Color','w','Position',[100 100 1120 440]); tiledlayout(1,2,'TileSpacing','compact');
for k=1:2
    nexttile;hold on;
    for j=1:6
        y=R.HV(R.cycle_limit_s==cycles(k)&R.method==names(j)); q=quantile(y,[.25,.5,.75]);
        plot(j+.14*sin((1:numel(y))*2.4),y,'.','Color',colors(j,:),'MarkerSize',15);
        plot([j j],q([1 3]),'-','Color',colors(j,:),'LineWidth',3);plot(j+[-.22,.22],q([2 2]),'k-','LineWidth',1.5);
    end
    xticks(1:6);xticklabels({'CD/CD','PCD/CD','EAR/CD','CD/PCD','PCD/PCD','EAR/PCD'});xtickangle(30);xlim([.5 6.5]);
    ylabel('Final feasible HV');xlabel('Population / guide archive selector');title(sprintf('Cycle cap %.1f s; n = 10',cycles(k)));grid on;
end
savefigures(f,out,'final_HV');
f=figure('Visible','off','Color','w','Position',[100 100 1120 440]);tiledlayout(1,2,'TileSpacing','compact');
contrasts=["D1-D0","D3-D0","D4-D0","D5-D4","D2-D1"];
for k=1:2
    nexttile;hold on;
    for j=1:5
        v=C(C.cycle_limit_s==cycles(k)&C.contrast==contrasts(j),:);
        errorbar(j,v.mean_difference,v.mean_difference-v.ci95_mean_low,v.ci95_mean_high-v.mean_difference,'o','Color',colors(j,:),'MarkerFaceColor',colors(j,:),'LineWidth',1.5);
    end
    yline(0,'k:');xticks(1:5);xticklabels(contrasts);xlim([.5 5.5]);ylabel('Mean paired HV difference');title(sprintf('Cycle cap %.1f s; individual 95%% CIs',cycles(k)));grid on;
end
savefigures(f,out,'paired_effects');
f=figure('Visible','off','Color','w','Position',[100 100 1120 440]);tiledlayout(1,2,'TileSpacing','compact');
for k=1:2
    nexttile;hold on; pool=H(H.cycle_limit_s==cycles(k),:);
    low=min([pool.final_HV;pool.history_HV]);high=max([pool.final_HV;pool.history_HV]);pad=max(.001,(high-low)*.06);
    plot([low-pad high+pad],[low-pad high+pad],'k:','HandleVisibility','off');
    for j=1:6
        v=pool(pool.method==names(j),:);plot(v.history_HV,v.final_HV,'o','Color',colors(j,:),'MarkerSize',5,'DisplayName',names(j));
    end
    xlim([low-pad high+pad]);ylim([low-pad high+pad]);axis square;grid on;
    xlabel('All evaluated feasible candidates: HV');ylabel('Final population (64): HV');title(sprintf('Cycle cap %.1f s',cycles(k)));
end
lg=legend('Orientation','horizontal','NumColumns',6);lg.Layout.Tile='south';savefigures(f,out,'history_vs_final');
end
function savefigures(f,out,name)
exportgraphics(f,fullfile(out,[name '.png']),'Resolution',200);exportgraphics(f,fullfile(out,[name '.pdf']),'ContentType','vector');close(f);
end
