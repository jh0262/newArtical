function make_physical_figures()
root=fileparts(mfilename('fullpath')); out=fullfile(root,'results'); folder=fullfile(root,'figures');
z=load(fullfile(out,'physical_summary_data.mat')); old=load(fullfile(root,'benchmark_reference','summary_data.mat'),'runs','histories');
algorithms={'PACPO','NSGAII','MOEAD','MOPSO'}; labels={'MO-PACPO','NSGA-II','MOEA/D-SBX','MOPSO-CD'};
tasks={'ZDT1','ZDT2','ZDT3','DTLZ1','DTLZ2'}; colors=lines(4);
fig=figure('Visible','off','Color','w','Position',[100,100,1500,850]); tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
for i=1:6
    nexttile; hold on;
    for j=1:4
        if i<=5
            k=strcmp(old.runs.Study,'main') & strcmp(old.runs.Problem,tasks{i}) & strcmp(old.runs.Algorithm,algorithms{j});
            h=mean(old.histories(k,:),1);
        else, k=strcmp(z.runs.Algorithm,algorithms{j}); h=mean(z.histories(k,:),1); end
        plot(0:250,h,'Color',colors(j,:),'LineWidth',1.5,'DisplayName',labels{j});
    end
    xlabel('Generation'); ylabel('Mean normalized HV'); grid on;
    if i<=5, title(tasks{i}); else, title('2PPaPaR: closed-loop model'); legend('Location','southeast','FontSize',10); end
end
saveFig(fig,folder,'Figure4_Convergence');
fig=figure('Visible','off','Color','w','Position',[100,100,1500,620]); tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
nexttile; hold on;
for j=1:4
    k=find(strcmp(z.runs.Algorithm,algorithms{j})); [~,order]=sort(z.runs.FineHV(k)); row=k(order(15));
    r=z.refined{row}; f=r.F(r.keep,:);
    scatter3(-f(:,1)/1e6,f(:,2),-f(:,3),22,colors(j,:),'filled','DisplayName',labels{j});
end
xlabel('V_{work} / 10^6 cm^3'); ylabel('E_{pos} / mm'); zlabel('GCI'); view(130,25); grid on; legend('Location','best'); title('Median-HV runs: refined objectives');
nexttile; r=z.reps;scatter3(r.Volume/1e6,r.Error,r.GCI,80,r.TOPSISEqual,'filled');hold on;
text(r.Volume/1e6,r.Error,r.GCI,string(r.Scheme),'VerticalAlignment','bottom');
xlabel('V_{work} / 10^6 cm^3');ylabel('E_{pos} / mm');zlabel('GCI');view(130,25);grid on;colorbar;title('Five candidates: TOPSIS closeness');
saveFig(fig,folder,'Figure5_Engineering');
% Physical y-z sections at theta=0, not the orientation-averaged volume.
designs=[400,700,1000,150;table2array(z.reps(1,{'a','b','c','d'}))];
m=PPaPaRModel.config(65536);m.theta(:)=0;m.ct(:)=1;m.st(:)=0;
data=cell(2,1);maxError=0;maxGCI=0;
for i=1:2
    [w,varPos,k,p]=PPaPaRModel.integrand(designs(i,:),m);good=w>0;
    data{i}=struct('p',p(good,:),'err',sqrt(varPos(good)),'k',k(good));
    maxError=max(maxError,max(data{i}.err));maxGCI=max(maxGCI,max(data{i}.k));
end
allPos=[data{1}.p;data{2}.p]; yRange=[min(allPos(:,2)),max(allPos(:,2))]; zRange=[min(allPos(:,3)),max(allPos(:,3))];
fig=figure('Visible','off','Color','w','Position',[100,100,1350,1000]);tiledlayout(2,2,'Padding','compact','TileSpacing','compact');
for i=1:2
    for j=1:2
        nexttile; a=data{i};
        if j==1, values=a.err; limits=[0,maxError];label='Position RMS / mm'; else,values=a.k;limits=[0,maxGCI];label='Local k_F';end
        scatter(a.p(:,2),a.p(:,3),4,values,'filled');clim(limits);colorbar;
        xlabel('y / mm');ylabel('z / mm');axis equal; xlim(yRange); ylim(zRange); grid on;
        if i==1, title(['Baseline: ',label]);else,title(['TOPSIS choice: ',label]);end
    end
end
saveFig(fig,folder,'Figure6_WorkspaceSections');
save(fullfile(out,'workspace_sections.mat'),'data','designs');
end
function saveFig(fig,folder,name)
set(findall(fig,'-property','FontName'),'FontName','Arial');set(findall(fig,'-property','FontSize'),'FontSize',15);
set(findall(fig,'Type','Legend'),'FontSize',11);
savefig(fig,fullfile(folder,[name,'.fig']));exportgraphics(fig,fullfile(folder,[name,'.png']),'Resolution',250);close(fig);
end
