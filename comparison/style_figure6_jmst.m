function style_figure6_jmst(f)
% Presentation only: preserve all archived coordinates and series order.
labels=["MO-PACPO","NSGA-II","MOEA/D-SBX","MOPSO-CD","GDE3-adapted","noLock"];
markers={'o','s','^','d','v','x'};
colors=[0 .447 .698;.55 .337 .294;.494 .184 .556;0 .62 .45;0 .50 .55;.835 .369 0];
objects=findall(f,'Type','scatter');
for h=objects'
    idx=find(labels==string(h.DisplayName),1);
    if isempty(idx),continue;end
    h.CData=colors(idx,:);h.Marker=markers{idx};h.SizeData=42;
    h.MarkerEdgeColor=colors(idx,:);h.MarkerFaceColor='none';h.LineWidth=1.05;
    if idx==1,h.MarkerFaceColor=colors(idx,:);h.SizeData=32;end
end
set(findall(f,'-property','FontName'),'FontName','Arial');
lg=findall(f,'Type','legend');
set(lg,'Location','southoutside','NumColumns',2,'FontSize',18,'Box','off');
end
