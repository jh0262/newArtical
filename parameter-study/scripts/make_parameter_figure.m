function make_parameter_figure()
root=fileparts(fileparts(mfilename('fullpath')));
t=readtable(fullfile(root,'data','screen_runs.csv'),'TextType','string');
t=t(t.Problem=="PPAR",:);
f=figure('Visible','off','Color','w','Units','centimeters','Position',[2,2,17.0,7.3]);
tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
colors=[0,.447,.698;.835,.369,0;0,.620,.451];
nexttile;hold on;etas=[.025,.05,.1];floors=[.005,.02,.05];
for i=1:3
  means=zeros(1,3);
  for j=1:3
    q=t(t.Eta==etas(i)&t.SigmaMin==floors(j)&t.Window==5&t.Cap==.2,:);
    assert(height(q)==16);means(j)=mean(q.LateNoise);
  end
  plot(1:3,means,'-o','Color',colors(i,:),'MarkerFaceColor','w','LineWidth',1.1,'MarkerSize',4,'DisplayName',sprintf('%.3f',etas(i)));
end
set(gca,'YScale','log','XTick',1:3,'XTickLabel',{'0.005','0.020','0.050'});xlim([.8,3.2]);ylim([3e-5,2.5e-3]);
xlabel('Step-size lower bound');ylabel('Late regular-noise RMS');title('(a) Sustained perturbation');grid on;
lg=legend('Location','northwest','Box','off');title(lg,'Noise gain');
nexttile;hold on;ids=["W2","B","W10"];windows=[2,5,10];mu=zeros(1,3);
for i=1:3
  q=t(t.Variant==ids(i),:);assert(height(q)==16);v=q.Pulses;
  scatter(windows(i)+linspace(-.15,.15,16)',v,14,colors(i,:),'filled','MarkerFaceAlpha',.5);
  mu(i)=mean(v);
end
plot(windows,mu,'-k','LineWidth',1.1);plot(windows,mu,'dk','MarkerFaceColor','w','MarkerSize',5);
for i=1:3,text(windows(i)+.25,mu(i)+1,sprintf('%.2f',mu(i)),'FontSize',8);end
xlim([1,11.3]);ylim([-.8,max(t.Pulses(t.Variant=="W2"))+5]);xticks(windows);
xlabel('Stagnation window (generations)');ylabel('Pulse-triggered generations');title('(b) Pulse frequency');grid on;
set(findall(f,'Type','axes'),'FontName','Arial','FontSize',9);
exportgraphics(f,fullfile(root,'figures','Figure10_Parameter_Activation.png'),'Resolution',300);
exportgraphics(f,fullfile(root,'figures','Figure10_Parameter_Activation.pdf'),'ContentType','vector');close(f);
end
