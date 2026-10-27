function make_figures
base=fileparts(mfilename('fullpath'));out=fullfile(base,'figures');if ~isfolder(out),mkdir(out);end
src=fullfile(base,'figure_sources');files=dir(fullfile(src,'*.fig'));checks=struct('figure',{},'coordinatesUnchanged',{});
colors=[0,.447,.698;.45,.45,.45;.55,.337,.294;.494,.184,.556;0,.62,.45;0,.50,.55];styles={'-','--','-.',':','--','-.'};markers={'o','s','^','d','v','>'};
for k=1:numel(files)
 f=openfig(fullfile(src,files(k).name),'invisible');name=erase(files(k).name,'.fig');strip_legacy_presentation(f,name);coords=coordinates(f);
 set(findall(f,'-property','FontName'),'FontName','Arial');
 if strcmp(name,'Fig3')
  lines=findall(f,'Type','line');
  for j=1:numel(lines)
   h=lines(j);lab=string(h.DisplayName);idx=0;
   if lab=="MO-PACPO",idx=1;elseif contains(lab,'previous')||lab=="P0",idx=2;elseif contains(lab,'NSGA'),idx=3;elseif contains(lab,'MOEA'),idx=4;elseif contains(lab,'MOPSO'),idx=5;elseif contains(lab,'GDE3'),idx=6;end
   if idx>0 && numel(h.XData)>10
    old=h.Color;h.Color=colors(idx,:);h.LineStyle=styles{idx};h.Marker=markers{idx};h.MarkerIndices=1:35:numel(h.XData);h.MarkerSize=4;
    patches=findall(h.Parent,'Type','patch');for p=patches',if isnumeric(p.FaceColor)&&isequal(p.FaceColor,old),p.FaceColor=colors(idx,:);end;end
   end
  end
 end
 if strcmp(name,'Fig6')
  lg=findall(f,'Type','legend');set(lg,'Location','southoutside','NumColumns',2,'FontSize',15,'Box','off');
 end
 if ismember(name,{'Fig2','Fig6'})
  objects=findall(f,'-property','DisplayName');
  for h=objects'
   lab=string(h.DisplayName);idx=0;
   if lab=="MO-PACPO",idx=1;elseif contains(lab,'previous')||lab=="P0",idx=2;elseif contains(lab,'NSGA'),idx=3;elseif contains(lab,'MOEA'),idx=4;elseif contains(lab,'MOPSO'),idx=5;elseif contains(lab,'GDE3'),idx=6;end
   if idx>0
    if isprop(h,'Color'),h.Color=colors(idx,:);end
    if isa(h,'matlab.graphics.chart.primitive.Scatter'),h.CData=colors(idx,:);end
    if isprop(h,'MarkerFaceColor')&&isnumeric(h.MarkerFaceColor),h.MarkerFaceColor=colors(idx,:);end
   elseif lab=="noLock"&&isa(h,'matlab.graphics.chart.primitive.Scatter'),h.CData=[.835,.369,0];end
  end
  boxes=findall(f,'-property','BoxFaceColor');for h=boxes',j=round(h.XData(1));if strcmp(name,'Fig2'),map=[1,3,4,5,6];j=map(j);end;if j>=1&&j<=6,h.BoxFaceColor=colors(j,:);if isprop(h,'MarkerColor'),h.MarkerColor=colors(j,:);end;end;end
 end
 assert(isequaln(coords,coordinates(f)),'Figure coordinate data changed');
 checks(end+1)=struct('figure',name,'coordinatesUnchanged',true);
 exportgraphics(f,fullfile(out,[name,'.pdf']),'ContentType','vector');exportgraphics(f,fullfile(out,[name,'.png']),'Resolution',600,'BackgroundColor','white');close(f);
end
for n=["Fig1","Fig5"]
 copyfile(fullfile(src,n+".pdf"),fullfile(out,n+".pdf"));copyfile(fullfile(src,n+".png"),fullfile(out,n+".png"));
end
make_compact_mechanism(base);make_joint(base);make_validation(base);
writelines(jsonencode(checks),fullfile(out,'coordinate_preservation.json'));
end
function data=coordinates(f)
data={};for prop={'XData','YData','ZData'},hs=findall(f,'-property',prop{1});for h=hs',data{end+1}=get(h,prop{1});end;end
end
function make_joint(base)
R=fullfile(base,'MO_PACPO_Machines_P1联合对照修订_20261025','data');r=readtable(fullfile(R,'joint_runs.csv'),'TextType','string');s=readtable(fullfile(R,'joint_statistics.csv'),'TextType','string');
f=figure('Visible','off','Color','w','Units','centimeters','Position',[1,1,18,15]);tiledlayout(2,2,'TileSpacing','compact','Padding','compact');modes=["Full","noNoise","noLock","joint"];colors=[0 .447 .698;0 .62 .45;.835 .369 0;.4 .4 .4];
for k=1:3
 nexttile;hold on;tasks=["ZDT6","DTLZ3","PPAR"];mets=["IGD","IGD","HV"];pts=[0,0,262144];mult=[1000,1,1];q=r(r.Problem==tasks(k)&r.IntegrationPoints==pts(k),:);
 for j=1:4
  z=sortrows(q(q.Variant==modes(j),:),'Seed');y=z.(mets(k))*mult(k);boxchart(j*ones(30,1),y,'BoxFaceColor',colors(j,:),'MarkerStyle','none');scatter(j+linspace(-.15,.15,30)',y,9,colors(j,:),'filled');
 end
 xticks(1:4);xticklabels(modes);title(sprintf('(%c) %s','a'+k-1,replace(tasks(k),'PPAR','2PPaPaR')));ylabel(mets(k));if k==1,ylabel('IGD (10^{-3})');end;grid on;ax=gca;ax.YAxis.Exponent=0;
end
nexttile;hold on;
for j=1:2
 pts=262144*4^(j-1);q=s(s.Problem=="PPAR"&s.Metric=="HV"&s.IntegrationPoints==pts&s.Contrast=="Interaction",:);
 errorbar(q.MeanDifference*1e4,3-j,(q.MeanDifference-q.CILow)*1e4,(q.CIHigh-q.MeanDifference)*1e4,'horizontal','o','Color',colors(1+2*(j-1),:),'LineWidth',1.2);
 text(.98,3-j+.2,sprintf('Holm p = %.4f',q.HolmP),'Units','data','HorizontalAlignment','left','FontSize',8);
end
xline(0,'k--');xlim([-.4,4.2]);yticks([1,2]);yticklabels({'1,048,576','262,144'});ylim([.5,2.5]);xlabel('Mean HV interaction (10^{-4})');ylabel('Integration points');title('(d) Noise–pulse interaction');grid on;
set(findall(f,'-property','FontName'),'FontName','Arial');set(findall(f,'Type','axes'),'FontSize',9);
exportgraphics(f,fullfile(base,'figures','FigS2.pdf'),'ContentType','vector');exportgraphics(f,fullfile(base,'figures','FigS2.png'),'Resolution',600,'BackgroundColor','white');close(f);
end
function make_validation(base)
R=fullfile(base,'MO_PACPO_P1修正版_20261024');v=load(fullfile(R,'validation','archive_analysis.mat'));
f=figure('Visible','off','Color','w','Position',[100,100,1450,620]);tiledlayout(1,2,'Padding','compact','TileSpacing','compact');nexttile;
gain=squeeze(mean(v.hv(:,:,1)-v.hv(:,:,2),1));plot(1:10,100*gain(1:10)./squeeze(mean(v.hv(:,1:10,2),1)),'o-','LineWidth',1.6);yline(0,'k:');xticks(1:10);xticklabels({'2^18','2^20','S1','S2','S3','S4','S5','S6','S7','S8'});xtickangle(30);ylabel('Mean HV gain over NSGA-II (%)');grid on;
nexttile;a=readtable(fullfile(R,'results','area_statistics.csv'),'TextType','string');tasks=["ZDT1","ZDT2","ZDT3","ZDT4","ZDT6"];vals=zeros(5,2);m=["oldArea","noEC"];
for k=1:5,for j=1:2,q=a(a.Problem==tasks(k)&a.Comparator==m(j)&a.Metric=="HV",:);vals(k,j)=q.MeanDifference;end;end
bar(vals);yline(0,'k:');xticks(1:5);xticklabels(tasks);ylabel('Paired mean HV difference');legend({'Current area – one-pass area','Current area – crowding'},'Location','best');grid on;
set(findall(f,'-property','FontName'),'FontName','Arial');set(findall(f,'Type','axes'),'FontSize',18);
exportgraphics(f,fullfile(base,'figures','FigS1.pdf'),'ContentType','vector');exportgraphics(f,fullfile(base,'figures','FigS1.png'),'Resolution',600,'BackgroundColor','white');close(f);
end
