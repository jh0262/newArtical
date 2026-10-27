function P1Figures()
root=fileparts(mfilename('fullpath'));folder=fullfile(root,'figures');if ~isfolder(folder),mkdir(folder);end
z=load(fullfile(root,'results','benchmark_analysis.mat'));r=z.runs;
modes=["revised","legacy","NSGAII","MOEAD","MOPSO","GDE3"];
labels={'MO-PACPO','MO-PACPO (previous)','NSGA-II','MOEA/D-SBX','MOPSO-CD','GDE3-adapted'};colors=lines(6);tasks=["ZDT1","ZDT2","ZDT3","DTLZ1","DTLZ2"];
fig=figure('Visible','off','Color','w','Position',[100,100,1500,850]);tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
for k=1:5
 nexttile;hold on;for j=1:6,values=r.IGD(r.Problem==tasks(k)&r.Variant==modes(j));boxchart(j*ones(size(values)),values,'BoxFaceColor',colors(j,:),'MarkerStyle','.');end
 set(gca,'YScale','log','XTick',1:6,'XTickLabel',{'P','P0','N','D','S','G'});title(tasks(k));ylabel('IGD');grid on;
end
nexttile;axis off;hold on;for j=1:6,plot(nan,nan,'s','Color',colors(j,:),'MarkerFaceColor',colors(j,:),'DisplayName',labels{j});end;legend('Location','northwest','Box','off');saveOne(fig,folder,'Figure3_IGD');
fig=figure('Visible','off','Color','w','Position',[100,100,1500,880]);tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
old=load(fullfile(fileparts(root),'MO_PACPO_搜索机制改进_20261024','results','physical','analysis.mat'));
for k=1:6
 nexttile;hold on;
 for j=1:6
  if k<=5,h=z.H(:,r.Problem==tasks(k)&r.Variant==modes(j));
  elseif j==6
   h=zeros(251,30);for i=1:30,a=load(fullfile(root,'results','runs',sprintf('PPAR_GDE3_%d.mat',400000+i)),'result');h(:,i)=a.result.history(:,3);end
  else,mode=modes(j);if j==1,mode="candidate";end;h=old.histories(:,old.runs.Variant==mode);end
  q=quantile(h,[.25,.5,.75],2);x=(100:100:25100)'/1000;fill([x;flipud(x)],[q(:,1);flipud(q(:,3))],colors(j,:),'FaceAlpha',.08,'EdgeColor','none','HandleVisibility','off');plot(x,q(:,2),'Color',colors(j,:),'LineWidth',1.5,'DisplayName',labels{j});
 end
 xlabel('Evaluations / 1000');ylabel('HV');grid on;if k<=5,title(tasks(k));else,title('2PPaPaR');legend('Location','southeast','FontSize',13);end
end
saveOne(fig,folder,'Figure4_Convergence');
pr=readtable(fullfile(root,'results','physical_runs.csv'),'TextType','string');oldphysical=load(fullfile(fileparts(root),'MO_PACPO_机构模型修正版_20261023','results','physical_summary_data.mat'),'refined','runs');
paper=load(fullfile(fileparts(root),'MO_PACPO_论文同步修订_20261024','data','paper_physical_data.mat'),'reps');
fig=figure('Visible','off','Color','w','Position',[100,100,1600,680]);tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;hold on;pmodes=[modes,"noLock"];plabels=[labels,{'noLock'}];pc=lines(7);
for j=1:7
 q=pr(pr.Variant==pmodes(j),:);[~,ix]=sort(q.FineHV);seed=q.Seed(ix(15));
 if j==1 || j>=6
  a=load(fullfile(root,'validation',sprintf('archive_%s_%d.mat',pmodes(j),seed)),'allF','allKeep');f=a.allF{1}(a.allKeep{1},:);
 else
  v=pmodes(j);if v=="legacy",v="PACPO";end
  id=find(string(oldphysical.runs.Algorithm)==v & oldphysical.runs.Seed==seed);a=oldphysical.refined{id};f=a.F(a.keep,:);
 end
 scatter3(-f(:,1)/1e6,f(:,2),-f(:,3),17,pc(j,:),'filled','DisplayName',plabels{j});
end
xlabel('V_{work} / 10^6 cm^3');ylabel('E_{pos} / mm');zlabel('GCI');view(130,25);grid on;legend('Location','best');title('Median-HV archives');
nexttile;rep=paper.reps;scatter3(rep.Volume/1e6,rep.Error,rep.GCI,85,rep.TOPSISEqual,'filled');hold on;text(rep.Volume/1e6,rep.Error,rep.GCI,string(rep.Scheme),'VerticalAlignment','bottom');xlabel('V_{work} / 10^6 cm^3');ylabel('E_{pos} / mm');zlabel('GCI');view(130,25);grid on;colorbar;title('TOPSIS representatives');saveOne(fig,folder,'Figure5_Engineering');
fig=figure('Visible','off','Color','w','Position',[100,100,1450,620]);tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile;v=load(fullfile(root,'validation','archive_analysis.mat'));gain=squeeze(mean(v.hv(:,:,1)-v.hv(:,:,2),1));plot(1:10,100*gain(1:10)./squeeze(mean(v.hv(:,1:10,2),1)),'o-','LineWidth',1.6);yline(0,'k:');xticks(1:10);xticklabels({'2^18','2^20','S1','S2','S3','S4','S5','S6','S7','S8'});xtickangle(30);ylabel('Mean HV gain over NSGA-II / %');grid on;
nexttile;a=readtable(fullfile(root,'results','area_statistics.csv'),'TextType','string');tasks2=["ZDT1","ZDT2","ZDT3","ZDT4","ZDT6"];vals=zeros(5,2);
for k=1:5,for j=1:2,m=["oldArea","noEC"];q=a(a.Problem==tasks2(k)&a.Comparator==m(j)&a.Metric=="HV",:);vals(k,j)=q.MeanDifference;end;end
bar(vals);yline(0,'k:');xticks(1:5);xticklabels(tasks2);ylabel('Paired mean HV difference');legend({'New area - old area','New area - crowding'},'Location','best');grid on;saveOne(fig,folder,'Figure7_Validation');
end
function saveOne(fig,folder,name)
set(findall(fig,'-property','FontName'),'FontName','Arial');set(findall(fig,'-property','FontSize'),'FontSize',18);set(findall(fig,'Type','Legend'),'FontSize',14);
savefig(fig,fullfile(folder,[name,'.fig']));exportgraphics(fig,fullfile(folder,[name,'.png']),'Resolution',220);exportgraphics(fig,fullfile(folder,[name,'.pdf']),'ContentType','vector');close(fig);
end
