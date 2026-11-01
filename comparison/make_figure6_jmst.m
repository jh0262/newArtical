function make_figure6_jmst
% Re-export the frozen Figure 6 data with distinct algorithm markers.
base=fileparts(mfilename('fullpath'));out=fullfile(base,'figures');
if ~isfolder(out),mkdir(out);end
f=openfig(fullfile(base,'figure_sources','Fig6.fig'),'invisible');
cleanup=onCleanup(@()close(f));
strip_legacy_presentation(f,'Fig6');
before=snapshot(f);lg=findall(f,'Type','legend');labels=lg.String;
style_figure6_jmst(f);
assert(isequaln(before,snapshot(f)),'Figure 6 numerical coordinates changed.');
assert(isequal(labels,lg.String),'Figure 6 legend order changed.');
exportgraphics(f,fullfile(out,'Fig6.pdf'),'ContentType','vector','BackgroundColor','white');
exportgraphics(f,fullfile(out,'Fig6.png'),'Resolution',600,'BackgroundColor','white');
audit=struct('coordinatesUnchanged',true,'legendOrderUnchanged',true,...
    'retiredSeriesExcluded',true,'optimizerSearches',0,...
    'series',{{'MO-PACPO','NSGA-II','MOEA/D-SBX','MOPSO-CD','GDE3-adapted','noLock'}},...
    'markers',{{'o','s','^','d','v','x'}},'source','figure_sources/Fig6.fig');
writelines(jsonencode(audit),fullfile(out,'Fig6_JMST_audit.json'));
% A grayscale proof for print-readability inspection, with numerical values intact.
for h=findall(f,'Type','scatter')'
    if strlength(string(h.DisplayName))>0
        h.CData=[.18 .18 .18];h.MarkerEdgeColor=[.18 .18 .18];
        if isnumeric(h.MarkerFaceColor),h.MarkerFaceColor=[.18 .18 .18];end
    end
end
colormap(f,gray(256));
exportgraphics(f,fullfile(out,'Fig6_grayscale_check.png'),'Resolution',150,'BackgroundColor','white');
fprintf('Figure 6 exported: unchanged coordinates; six distinct markers.\n');
end

function values=snapshot(f)
values={};
for prop={'XData','YData','ZData'}
    for h=findall(f,'-property',prop{1})'
        values{end+1}=get(h,prop{1}); %#ok<AGROW>
    end
end
% Numeric TOPSIS color values also remain unchanged.
for h=findall(f,'Type','scatter')'
    if strlength(string(h.DisplayName))==0,values{end+1}=h.CData;end %#ok<AGROW>
end
end
