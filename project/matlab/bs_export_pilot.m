function bs_export_pilot()
p=bs_config(); addpath(fullfile(p.root,'matlab','vendor')); out=fullfile(p.root,'pilot_v02');
names={'MODE-CD-G','MODE-EAR-G','MODE-CD-S','MODE-EAR-S','MV-NSGA-II','MV-SPEA2','CAT-QMC'}; summary=[];
f=figure('Visible','off','Color','w','Position',[100,100,1100,430]); tiledlayout(1,2,'Padding','compact');
for i=1:numel(names)
    a=load(fullfile(out,[names{i},'_seed92102.mat'])); r=a.result; mask=r.CV==0;
    check=p; check.cycle_limit_s=r.config.cycle_limit_s;
    [FF,CC]=bs_evaluate(r.X,check); assert(max(abs(FF-r.F),[],'all')<1e-12 && max(abs(CC-r.CV))<1e-12);
    [hv,excluded]=bs_hv(r.F(mask,:),p); assert(abs(hv-r.trace(end,3))<1e-12);
    summary=[summary;table(string(names{i}),r.FE,r.seconds,hv,mean(mask),excluded,r.ear_calls,r.ear_fallbacks, ...
        'VariableNames',{'method','FE','seconds','HV','final_feasible_fraction','reference_excluded','ear_calls','ear_fallbacks'})]; %#ok<AGROW>
    nexttile(1); plot(r.trace(:,2),r.trace(:,3),'DisplayName',names{i}); hold on;
    nexttile(2); plot(r.F(mask,1),r.F(mask,2),'.','DisplayName',names{i}); hold on;
end
nexttile(1); xlabel('Design evaluations'); ylabel('Feasible HV'); title('Exploratory run: seed 92102'); grid on; set(gca,'FontSize',10);
nexttile(2); xlabel('Move time (s)'); ylabel('Worst-scenario residual envelope (\mum)'); title('Final feasible populations'); grid on; set(gca,'FontSize',10);
lg=legend('Orientation','horizontal','NumColumns',4); lg.Layout.Tile='south';
exportgraphics(f,fullfile(out,'pilot_comparison.png'),'Resolution',200); exportgraphics(f,fullfile(out,'pilot_comparison.pdf'),'ContentType','vector'); close(f);
writetable(summary,fullfile(out,'pilot_summary.csv')); disp(summary);
end
