classdef ERFigures
 methods(Static)
 function run()
  root=ERStudy.root();d=fullfile(root,'data');sc=readtable(fullfile(d,'screen_runs.csv'),'TextType','string');co=readtable(fullfile(d,'confirm_runs.csv'),'TextType','string');curves=readtable(fullfile(d,'confirm_curves.csv'),'TextType','string');profiles=readtable(fullfile(d,'screen_profiles.csv'),'TextType','string');st=readtable(fullfile(d,'confirm_stability.csv'),'TextType','string');sel=jsondecode(fileread(fullfile(d,'selection.json')));cand=string(sel.candidates(:)');ids=["B",cand];colors=[0,.447,.698;.835,.369,0;0,.620,.451;.8,.475,.655;.9,.62,0;.337,.706,.914];
  gridIDs=["N11","N12","N13";"N21","B","N23";"N31","N32","N33"];s=sc(sc.Problem=="PPAR",:);b=s(s.Variant=="B",:);
  f=ERFigures.new(28,9);tiledlayout(1,3,'TileSpacing','compact','Padding','compact');metrics=["MillionHV","AUC","MillionHV"];titles=["Mean final HV","Mean HV AUC","10th percentile final HV"];
  for k=1:3
   ax=nexttile;value=zeros(3);ref=mean(b.(metrics(k)));if k==3,ref=prctile(b.(metrics(k)),10);end
   for i=1:3,for j=1:3,v=s.(metrics(k))(s.Variant==gridIDs(i,j));q=mean(v);if k==3,q=prctile(v,10);end;value(i,j)=100*(q/ref-1);end;end
   imagesc(value);axis square;lim=max(max(abs(value),[],'all'),1e-8);clim([-lim,lim]);colormap(ax,ERFigures.diverging());colorbar;set(ax,'XTick',1:3,'XTickLabel',{'0.005','0.020','0.050'},'YTick',1:3,'YTickLabel',{'0.025','0.050','0.100'});xlabel('Step-size floor');ylabel('Noise gain');title(titles(k));
   for i=1:3,for j=1:3,color='k';if abs(value(i,j))>.65*lim,color='w';end;text(j,i,sprintf('%+.3f%%',value(i,j)),'HorizontalAlignment','center','Color',color,'FontSize',9);end;end
  end
  sgtitle('2PPaPaR screening: 16 seeds per setting; change from B (%)');ERFigures.save(f,'01_engineering_noise_grid');
  gates=["B","W2","W10","C005","W2C005"];f=ERFigures.new(28,9);tiledlayout(1,3,'TileSpacing','compact','Padding','compact');metrics=["MillionHV","AUC","Pulses"];labels=["Final HV (million-point evaluation)","Search HV AUC","Pulse events per run"];
  for k=1:3,ax=nexttile;mu=zeros(1,5);se=mu;for i=1:5,v=s.(metrics(k))(s.Variant==gates(i));mu(i)=mean(v);se(i)=std(v)/sqrt(numel(v));end;errorbar(1:5,mu,1.96*se,'o','Color',colors(1,:),'LineWidth',1);xticks(1:5);xticklabels(gates);xtickangle(25);ylabel(labels(k));grid on;ax.XLim=[.5,5.5];end
  sgtitle('2PPaPaR pulse settings: mean and approximate 95% mean interval');ERFigures.save(f,'02_engineering_gate_effects');
  f=ERFigures.new(26,10);tiledlayout(1,2,'TileSpacing','compact','Padding','compact');target=jsondecode(fileread(fullfile(d,'targets.json')));target=target.engineering_HV_target;
  for panel=1:2
   nexttile;hold on;handles=gobjects(1,numel(ids));
   for i=1:numel(ids)
    a=sortrows(curves(curves.Problem=="PPAR"&curves.Variant==ids(i),:),{'Seed','FE'});y=reshape(a.HV,251,[])';xx=(100:100:25100)';
    if panel==1,mu=mean(y)';se=std(y)'/sqrt(size(y,1));fill([xx;flipud(xx)],[mu-1.96*se;flipud(mu+1.96*se)],colors(i,:),'FaceAlpha',.15,'EdgeColor','none','HandleVisibility','off');handles(i)=plot(xx,mu,'Color',colors(i,:),'LineWidth',1.3);
    else,rate=mean(cummax(y,2)>=target)';handles(i)=stairs(xx,rate,'Color',colors(i,:),'LineWidth',1.3);end
   end
   if panel==1,yline(target,':','Color',[.5,.5,.5],'HandleVisibility','off');ylabel('Search HV');else,ylabel('Fraction reaching fixed target');ylim([-.02,1.02]);end
   xlabel('Objective evaluations');grid on;legend(handles,ids,'Location','southeast','Box','off');
  end
  sgtitle('2PPaPaR independent confirmation: 30 new seeds');ERFigures.save(f,'03_confirmation_convergence');
  f=ERFigures.new(28,10);tiledlayout(1,3,'TileSpacing','compact','Padding','compact');a=co(co.Problem=="PPAR",:);base=sortrows(a(a.Variant=="B",:),'Seed');metrics=["MillionHV","AUC"];
  for panel=1:2
   nexttile;hold on;
   for i=1:numel(cand),q=sortrows(a(a.Variant==cand(i),:),'Seed');v=100*(q.(metrics(panel))-base.(metrics(panel)))./base.(metrics(panel));boxchart(i*ones(numel(v),1),v,'BoxFaceColor',colors(i+1,:),'MarkerStyle','none');scatter(i+linspace(-.08,.08,numel(v))',v,15,colors(i+1,:),'filled','MarkerFaceAlpha',.6);end
   yline(0,'--','Color',[.5,.5,.5]);xticks(1:numel(cand));xticklabels(cand);xlim([.5,numel(cand)+.5]);ylabel('Paired change from B (%)');titles=["Final HV","HV AUC"];title(titles(panel));grid on;
  end
  nexttile;hold on;q=st(st.Metric=="MillionHV",:);for i=1:height(q),plot([i,i],[q.SDRatioLow(i),q.SDRatioHigh(i)],'-','Color',colors(i+1,:),'LineWidth',1.2);plot(i,q.SDRatio(i),'o','Color',colors(i+1,:),'MarkerFaceColor',colors(i+1,:));end;yline(1,'--','Color',[.5,.5,.5]);xticks(1:height(q));xticklabels(q.Variant);xlim([.5,height(q)+.5]);ylabel('Final-HV SD ratio to B');title('Paired bootstrap 95% CI');grid on;ERFigures.save(f,'04_confirmation_quality_stability');
  f=ERFigures.new(28,10);tiledlayout(1,3,'TileSpacing','compact','Padding','compact');pr=profiles(profiles.Problem=="PPAR",:);show=["N11","N13","B","N31","N33","W2C005"];stages=["early","middle","late"];metrics=["NoiseRMS","FloorFraction","Pulses"];labels=["Applied regular-noise RMS","Fraction at step-size floor","Pulse events / 100 generations"];
  mechanismColors=colors([6,4,1,2,5,3],:);
  for panel=1:3,nexttile;hold on;for i=1:numel(show),q=pr(pr.Variant==show(i),:);v=zeros(1,3);for j=1:3,v(j)=mean(q.(metrics(panel))(q.Stage==stages(j)));end;if panel==3,v=100*v./[50,150,50];end;plot(1:3,v,'-o','Color',mechanismColors(i,:),'LineWidth',1,'DisplayName',show(i));end;xticks(1:3);xticklabels({'1-50','51-200','201-250'});xlabel('Generation range');ylabel(labels(panel));grid on;if panel==1,set(gca,'YScale','log');legend('Location','southwest','NumColumns',2,'FontSize',7,'Box','off');end;end
  sgtitle('2PPaPaR mechanism activation along complete trajectories');ERFigures.save(f,'05_mechanism_activation');
  f=ERFigures.new(25,10);tiledlayout(1,2,'TileSpacing','compact','Padding','compact');s=sc(sc.Problem=="DTLZ3",:);value=zeros(3);for i=1:3,for j=1:3,value(i,j)=mean(s.IGD(s.Variant==gridIDs(i,j)));end;end
  ax=nexttile;imagesc(value);axis square;colormap(ax,flipud(parula));colorbar;for i=1:3,for j=1:3,color='k';if value(i,j)>mean(value,'all'),color='w';end;text(j,i,sprintf('%.3f',value(i,j)),'HorizontalAlignment','center','Color',color);end;end;set(ax,'XTick',1:3,'XTickLabel',{'0.005','0.020','0.050'},'YTick',1:3,'YTickLabel',{'0.025','0.050','0.100'});xlabel('Step-size floor');ylabel('Noise gain');title('Screening mean IGD');
  nexttile;hold on;for i=1:numel(ids),v=co.IGD(co.Problem=="DTLZ3"&co.Variant==ids(i));boxchart(i*ones(numel(v),1),v,'BoxFaceColor',colors(i,:));end;xticks(1:numel(ids));xticklabels(ids);xlim([.5,numel(ids)+.5]);ylabel('Final IGD (lower is better)');title('Engineering-selected settings');grid on;sgtitle('DTLZ3: auxiliary multimodal convergence test');ERFigures.save(f,'06_dtlz3_auxiliary');
  f=ERFigures.new(26,10);tiledlayout(1,2,'TileSpacing','compact','Padding','compact');a=co(co.Problem=="PPAR",:);base=sortrows(a(a.Variant=="B",:),'Seed');
  for panel=1:2,nexttile;hold on;for i=1:numel(ids),q=sortrows(a(a.Variant==ids(i),:),'Seed');if panel==1,plot(1:height(q),100*(q.MillionHV-q.FineHV)./q.MillionHV,'o','Color',colors(i,:),'MarkerSize',3,'DisplayName',ids(i));elseif i>1,scatter(q.FineHV-base.FineHV,q.MillionHV-base.MillionHV,18,colors(i,:),'filled','DisplayName',ids(i));end;end;if panel==1,xlabel('Seed index');ylabel('(Million HV - fine HV) / million HV (%)');else,xlabel('Paired HV difference: 262,144 points');ylabel('Paired HV difference: 1,048,576 points');xline(0,':','HandleVisibility','off');yline(0,':','HandleVisibility','off');end;legend('Box','off','Location','best');grid on;end
  sgtitle('Numerical integration sensitivity of final engineering archives');ERFigures.save(f,'07_integration_sensitivity');
 end
 function f=new(w,h)
  f=figure('Visible','off','Color','w','Units','centimeters','Position',[2,2,w,h]);
 end
 function cmap=diverging()
  a=[.70,.15,.15];b=[.98,.98,.98];c=[.1,.35,.65];t=linspace(0,1,128)';cmap=[a+(b-a).*t;b+(c-b).*t];
 end
 function save(f,name)
  root=ERStudy.root();set(findall(f,'Type','axes'),'FontName','Arial','FontSize',9);exportgraphics(f,fullfile(root,'figures',[name,'.png']),'Resolution',180);exportgraphics(f,fullfile(root,'figures',[name,'.pdf']),'ContentType','vector');close(f);
 end
 end
end
