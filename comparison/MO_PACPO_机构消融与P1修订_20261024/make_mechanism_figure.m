function make_mechanism_figure
R=fileparts(mfilename('fullpath'));c=readtable(fullfile(R,'data','curves.csv'),'TextType','string');
o=readtable(fullfile(R,'data','operator_trace.csv'),'TextType','string');s=readtable(fullfile(R,'data','paired_statistics.csv'),'TextType','string');
f=figure('Visible','off','Color','w','Position',[30,30,1100,900]);tiledlayout(2,2,'TileSpacing','compact','Padding','compact');colors=lines(4);names=["revised","Diagonal","noNoise","noLock"];labels={'Full','Diagonal','noNoise','noLock'};
nexttile;hold on
for i=1:4
 q=c(c.Variant==names(i),:);v=reshape(q.HV,251,30);x=q.FE(1:251);lo=prctile(v,25,2);hi=prctile(v,75,2);
 fill([x;flipud(x)],[lo;flipud(hi)],colors(i,:),'FaceAlpha',.08,'EdgeColor','none','HandleVisibility','off');plot(x,median(v,2),'Color',colors(i,:),'LineWidth',1.4,'DisplayName',labels{i});
end
xlabel('Function evaluations');ylabel('Search HV');title('(a) Search convergence');legend('Location','southeast');xlim([0,25100]);grid on
nexttile;hold on
for j=1:2
 count=262144*4^(j-1);q=s(s.Metric=="HV"&s.IntegrationPoints==count,:);
 for i=1:3
  r=q(q.Comparator==names(i+1),:);x=i+(j-1.5)*.18;
  errorbar(x,r.MeanDifference*1e4,(r.MeanDifference-r.CILow)*1e4,(r.CIHigh-r.MeanDifference)*1e4,'o','Color',colors(j,:),'LineWidth',1.3,'MarkerFaceColor',colors(j,:),'HandleVisibility','off');
 end
 plot(nan,nan,'o','Color',colors(j,:),'DisplayName',sprintf('%d integration points',count));
end
yline(0,'k:','HandleVisibility','off');xlim([.5,3.5]);xticks(1:3);xticklabels(labels(2:4));ylabel('Full minus ablation HV (10^{-4})');title('(b) Paired mean and 95% CI');legend('Location','northwest');grid on
nexttile;hold on
q=o(o.Variant=="revised",:);keys={'guideMasked','differenceMasked','noiseMasked','mutation'};labs={'Guidance','Difference','Principal noise','Polynomial mutation'};
for i=1:4
 v=reshape(q.(keys{i}),250,30);semilogy(1:250,median(v,2),'Color',colors(i,:),'LineWidth',1.3,'DisplayName',labs{i});
end
set(gca,'YScale','log');xlabel('Generation');ylabel('RMS step in normalized decisions');title('(c) Full component magnitudes');legend('Location','northoutside','NumColumns',2);grid on
nexttile;hold on
for i=1:3
 q=o(o.Variant==names(i),:);v=reshape(q.noiseMasked./q.combinedMasked*100,250,30);plot(1:250,median(v,2),'Color',colors(i,:),'LineWidth',1.3,'DisplayName',labels{i});
end
xlabel('Generation');ylabel('Noise / combined masked RMS (%)');title('(d) Relative regular noise magnitude');legend('Location','northeast');grid on
ax=findall(f,'Type','axes');set(ax,'FontName','Times New Roman','FontSize',14);set(findall(f,'Type','legend'),'FontName','Times New Roman','FontSize',12);exportgraphics(f,fullfile(R,'figures','mechanism_ablation.png'),'Resolution',300);exportgraphics(f,fullfile(R,'figures','mechanism_ablation.pdf'),'ContentType','vector');close(f);
end
