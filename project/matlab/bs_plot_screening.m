function bs_plot_screening()
p=bs_config(); out=fullfile(p.root,'verification_v02');
S=readmatrix(fullfile(out,'screening_samples.csv')); Q=readmatrix(fullfile(out,'time_slice.csv'));
f=figure('Visible','off','Color','w','Position',[100,100,1120,440]); tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
nexttile; hold on;
for c=unique(S(S(:,7)==0,1))'
    mask=S(:,7)==0&S(:,1)==c; scatter(S(mask,5),S(mask,6),24,'filled','DisplayName',p.catalog.model(c));
end
xlabel('Move time (s)'); ylabel('Worst-scenario residual envelope (\mum)'); title('Feasible samples: cycle limit 2.5 s'); legend('Location','northoutside'); grid on; set(gca,'FontSize',11);
nexttile; plot(Q(:,5),Q(:,6),'Color',[.65,.65,.65],'DisplayName','All sampled times'); hold on; mask=Q(:,7)==0;
plot(Q(mask,5),Q(mask,6),'b.','DisplayName','Feasible times'); xlabel('Move time (s)'); ylabel('Residual envelope (\mum)'); title('BTK2510V-5.3, r = 0.30, u = 0.25'); legend('Location','northoutside'); grid on; set(gca,'FontSize',11);
exportgraphics(f,fullfile(out,'model_screening_revised.png'),'Resolution',200);
exportgraphics(f,fullfile(out,'model_screening_revised.pdf'),'ContentType','vector'); close(f);
end
