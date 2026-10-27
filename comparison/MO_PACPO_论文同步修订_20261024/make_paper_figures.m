function make_paper_figures()
root=fileparts(mfilename('fullpath'));folder=fullfile(root,'figures');
search=fullfile(fileparts(root),'MO_PACPO_搜索机制改进_20261024');
oldroot=fullfile(fileparts(root),'MO_PACPO_机构模型修正版_20261023');
addpath(search,fullfile(search,'reference'));
z=load(fullfile(root,'data','paper_physical_data.mat'));
main=load(fullfile(search,'results','confirmation','aggregate.mat'));
phys=load(fullfile(search,'results','physical','analysis.mat'));
old=load(fullfile(oldroot,'results','physical_summary_data.mat'),'refined','runs');
variants=["candidate","legacy","NSGAII","MOEAD","MOPSO"];
labels={'MO-PACPO','MO-PACPO (previous)','NSGA-II','MOEA/D-SBX','MOPSO-CD'};
tasks=["ZDT1","ZDT2","ZDT3","DTLZ1","DTLZ2"];colors=lines(5);
fig=figure('Visible','off','Color','w','Position',[100,100,1450,820]);tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
for i=1:5
 nexttile;hold on;
 for j=1:5
  k=string(main.runs.Problem)==tasks(i)&string(main.runs.Variant)==variants(j);
  values=main.runs.IGD(k);boxchart(repmat(j,numel(values),1),values,'BoxFaceColor',colors(j,:),'MarkerStyle','.');
 end
 set(gca,'YScale','log','XTick',1:5,'XTickLabel',{'P','P0','N','D','S'});title(tasks(i));ylabel('IGD (log scale)');grid on;
end
nexttile;axis off;hold on;
for j=1:5,plot(nan,nan,'s','MarkerFaceColor',colors(j,:),'Color',colors(j,:),'DisplayName',labels{j});end
legend('Location','northwest','Box','off');text(.06,.25,'P / P0 / N / D / S: algorithm order','Units','normalized');
saveFig(fig,folder,'Figure3_IGD');
fig=figure('Visible','off','Color','w','Position',[100,100,1450,850]);tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
for i=1:6
 nexttile;hold on;
 for j=1:5
  if i<=5,k=string(main.runs.Problem)==tasks(i)&string(main.runs.Variant)==variants(j);h=main.histories(:,k);
  else,k=string(phys.runs.Variant)==variants(j);h=phys.histories(:,k);end
  q=quantile(h,[.25,.5,.75],2);x=(100:100:25100)'/1000;
  fill([x;flipud(x)],[q(:,1);flipud(q(:,3))],colors(j,:),'FaceAlpha',.09,'EdgeColor','none','HandleVisibility','off');
  plot(x,q(:,2),'Color',colors(j,:),'LineWidth',1.5,'DisplayName',labels{j});
 end
 xlabel('Evaluations / 1000');ylabel('Normalized HV');grid on;
 if i<=5,title(tasks(i));else,title('2PPaPaR');legend('Location','southeast','FontSize',9);end
end
saveFig(fig,folder,'Figure4_Convergence');
fig=figure('Visible','off','Color','w','Position',[100,100,1450,580]);tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;hold on;
for j=1:5
 k=find(string(phys.runs.Variant)==variants(j));[~,ix]=sort(phys.runs.FineHV(k));row=k(ix(15));
 if j==1,r=phys.refined{row};else,r=old.refined{row-30};end
 f=r.F(r.keep,:);scatter3(-f(:,1)/1e6,f(:,2),-f(:,3),19,colors(j,:),'filled','DisplayName',labels{j});
end
xlabel('V_{work} / 10^6 cm^3');ylabel('E_{pos} / mm');zlabel('GCI');view(130,25);grid on;legend('Location','best');title('Median-HV archives');
nexttile;r=z.reps;scatter3(r.Volume/1e6,r.Error,r.GCI,85,r.TOPSISEqual,'filled');hold on;
text(r.Volume/1e6,r.Error,r.GCI,string(r.Scheme),'VerticalAlignment','bottom');
xlabel('V_{work} / 10^6 cm^3');ylabel('E_{pos} / mm');zlabel('GCI');view(130,25);grid on;colorbar;title('TOPSIS representatives');
saveFig(fig,folder,'Figure5_Engineering');
designs=[400,700,1000,150;table2array(z.reps(1,{'a','b','c','d'}))];
m=PPaPaRModel.config(65536);m.theta(:)=0;m.ct(:)=1;m.st(:)=0;data=cell(2,1);maxError=0;maxGCI=0;
for i=1:2
 [w,varPos,k,p]=PPaPaRModel.integrand(designs(i,:),m);good=w>0;
 data{i}=struct('p',p(good,:),'err',sqrt(varPos(good)),'k',k(good));
 maxError=max(maxError,max(data{i}.err));maxGCI=max(maxGCI,max(data{i}.k));
end
allPos=[data{1}.p;data{2}.p];yr=[min(allPos(:,2)),max(allPos(:,2))];zr=[min(allPos(:,3)),max(allPos(:,3))];
fig=figure('Visible','off','Color','w','Position',[100,100,1300,930]);tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
for i=1:2
 for j=1:2
  nexttile;a=data{i};
  if j==1,values=a.err;limits=[0,maxError];label='Position RMS / mm';else,values=a.k;limits=[0,maxGCI];label='Local k_F';end
  scatter(a.p(:,2),a.p(:,3),4,values,'filled');clim(limits);colorbar;
  xlabel('y / mm');ylabel('z / mm');axis equal;xlim(yr);ylim(zr);grid on;
  if i==1,title(['Baseline: ',label]);else,title(['TOPSIS choice: ',label]);end
 end
end
saveFig(fig,folder,'Figure6_WorkspaceSections');save(fullfile(root,'data','workspace_sections.mat'),'data','designs');
end
function saveFig(fig,folder,name)
set(findall(fig,'-property','FontName'),'FontName','Arial');set(findall(fig,'-property','FontSize'),'FontSize',14);
set(findall(fig,'Type','Legend'),'FontSize',10);
savefig(fig,fullfile(folder,[name,'.fig']));exportgraphics(fig,fullfile(folder,[name,'.png']),'Resolution',220);exportgraphics(fig,fullfile(folder,[name,'.pdf']),'ContentType','vector');close(fig);
end
