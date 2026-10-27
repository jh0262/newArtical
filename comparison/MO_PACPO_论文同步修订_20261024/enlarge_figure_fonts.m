function enlarge_figure_fonts()
root=fileparts(mfilename('fullpath'));folder=fullfile(root,'figures');
names={'Figure3_IGD','Figure4_Convergence','Figure5_Engineering','Figure6_WorkspaceSections'};
for i=1:4
 f=openfig(fullfile(folder,[names{i},'.fig']),'invisible');
 set(findall(f,'-property','FontSize'),'FontSize',18);
 lg=findall(f,'Type','Legend');set(lg,'FontSize',16);
 if i==2 || i==3,lg.Layout.Tile='south';lg.NumColumns=3;end
 savefig(f,fullfile(folder,[names{i},'.fig']));
 exportgraphics(f,fullfile(folder,[names{i},'.png']),'Resolution',250);
 exportgraphics(f,fullfile(folder,[names{i},'.pdf']),'ContentType','vector');close(f);
end
end
