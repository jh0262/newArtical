function make_innovation_figures
R=fileparts(mfilename('fullpath'));curves=readtable(fullfile(R,'data','curves.csv'),'TextType','string');runs=readtable(fullfile(R,'data','runs.csv'),'TextType','string');
stats=readtable(fullfile(R,'data','factorial_statistics.csv'),'TextType','string');
tasks=["ZDT1","ZDT2","ZDT3","DTLZ1","DTLZ2","ZDT4","ZDT6","DTLZ3","PPAR"];
colors=[.12,.33,.58;.85,.34,.13;.20,.57,.38;.55,.32,.65];styles={'-','--','-.',':'};
f=figure('Visible','off','Color','w','Units','centimeters','Position',[1,1,18,17]);t=tiledlayout(3,3,'TileSpacing','compact','Padding','compact');
for j=1:9
 ax=nexttile;hold(ax,'on');modes=["DL","MOCPOF","MOCPOR"];
 for k=1:3
  q=curves(curves.Problem==tasks(j)&curves.Variant==modes(k),:);fe=unique(q.FE);v=zeros(numel(fe),30);seeds=unique(q.Seed);
  for s=1:30,z=sortrows(q(q.Seed==seeds(s),:),'FE');assert(isequal(z.FE,fe));v(:,s)=z.HV;end
  med=median(v,2);lo=prctile(v,25,2);hi=prctile(v,75,2);
  fill([fe;flipud(fe)],[lo;flipud(hi)],colors(k,:),'FaceAlpha',.12,'EdgeColor','none','HandleVisibility','off');
  plot(fe,med,'Color',colors(k,:),'LineWidth',1.1,'LineStyle',styles{k});
 end
 title(tasks(j),'FontWeight','normal');xlim([100,25100]);xticks([100,12500,25100]);xticklabels({'0.1','12.5','25.1'});xlabel('FE / 10^3');ylabel('HV');box on;
 if tasks(j)=="DTLZ3",ylim([0,.02]);text(.5,.52,'Median and IQR: 0','Units','normalized','HorizontalAlignment','center','FontSize',9);end
 set(ax,'FontName','Times New Roman','FontSize',9,'LineWidth',.6);
end
lg=legend({'MO-PACPO','MOCPO-F','MOCPO-R'},'Orientation','horizontal','Box','off');lg.Layout.Tile='north';
exportgraphics(f,fullfile(R,'figures','mocpo_comparison.png'),'Resolution',400,'Padding',12,'Units','points');exportgraphics(f,fullfile(R,'figures','mocpo_comparison.pdf'),'ContentType','vector','Padding',12,'Units','points');savefig(f,fullfile(R,'figures','mocpo_comparison.fig'));close(f);

f=figure('Visible','off','Color','w','Units','centimeters','Position',[1,1,18,12.5]);t=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');modes=["DL","DR","SL","SR"];
ax=nexttile;hold on;
for k=1:4
 q=curves(curves.Problem=="PPAR"&curves.Variant==modes(k),:);fe=unique(q.FE);v=zeros(numel(fe),30);seeds=unique(q.Seed);
 for s=1:30,z=sortrows(q(q.Seed==seeds(s),:),'FE');v(:,s)=z.HV;end
 plot(fe,median(v,2),'Color',colors(k,:),'LineWidth',1.2,'LineStyle',styles{k});
end
xlabel('Function evaluations');ylabel('HV');xlim([100,25100]);title('(a) Search trajectories','FontWeight','normal');legend(modes,'Location','southeast','Box','off');box on;
ax=nexttile;hold on;q=stats(stats.Problem=="PPAR"&stats.Metric=="HV"&stats.IntegrationPoints==262144,:);
names=["DirectionDouble","DirectionSingle","TriggerLow","TriggerRandom","Interaction"];q=sortrows(q,'Contrast');
for j=1:5
 z=q(q.Contrast==names(j),:);mu=z.MeanDifference*1e4;lo=z.CILow*1e4;hi=z.CIHigh*1e4;
 errorbar(j,mu,mu-lo,hi-mu,'o','Color',colors(1,:),'MarkerFaceColor',colors(1,:),'LineWidth',1.1,'CapSize',6);
end
yline(0,':','Color',[.4,.4,.4]);xlim([.5,5.5]);xticks(1:5);xticklabels({'DL-DR','SL-SR','DL-SL','DR-SR','Interaction'});xtickangle(20);ylabel('Mean HV difference / 10^{-4}');title('(b) Paired means and 95% intervals','FontWeight','normal');box on;
q=runs(runs.Problem=="PPAR"&runs.IntegrationPoints==262144,:);
for part=1:2
 ax=nexttile;hold on;upper=1;
 for j=1:4
  z=q(q.Variant==modes(j),:);if part==1,v=z.Pulses;else,v=z.HVWithoutLow;end
  bar(j,mean(v),.6,'FaceColor',colors(j,:));errorbar(j,mean(v),std(v),'k.','CapSize',5);
  scatter(j+.12*sin((1:30)'),v,8,'k','filled','MarkerFaceAlpha',.25);
  upper=max(upper,max(v)+std(v));
 end
 xticks(1:4);xticklabels(modes);xlim([.4,4.6]);ylim([0,1.1*upper]);box on;
 if part==1,ylabel('Pulse generations');title('(c) Pulse frequency','FontWeight','normal');else,ylabel('Generations');title('(d) HV gate without variance gate','FontWeight','normal');end
end
axs=findall(f,'Type','axes');set(axs,'FontName','Times New Roman','FontSize',9,'LineWidth',.6);
exportgraphics(f,fullfile(R,'figures','pulse_factorial.png'),'Resolution',400,'Padding',12,'Units','points');exportgraphics(f,fullfile(R,'figures','pulse_factorial.pdf'),'ContentType','vector','Padding',12,'Units','points');savefig(f,fullfile(R,'figures','pulse_factorial.fig'));close(f);
end
