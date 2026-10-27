function strip_legacy_presentation(f,name)
% Remove only retired P0 objects. Preserve retained objective data exactly.
if ~ismember(string(name),["Fig2","Fig3","Fig6"]),return;end
axesList=findall(f,'Type','axes');removed=0;checked=0;
original=findall(f,'-property','XData');saved=cell(numel(original),3);
for k=1:numel(original),for j=1:3,prop={'XData','YData','ZData'};if isprop(original(k),prop{j}),saved{k,j}=original(k).(prop{j});end;end;end
for ax=axesList'
    if strcmp(name,'Fig2')
        boxes=findall(ax,'Type','boxchart');
        for h=boxes'
            idx=round(h.XData(1));
            if idx==2,delete(h);removed=removed+1;
            else
                y=h.YData;
                if idx>2,h.XData=h.XData-1;end
                assert(isequaln(y,h.YData));checked=checked+1;
            end
        end
        if ~isempty(boxes)
            ax.XTick=1:5;ax.XTickLabel={'P','N','D','S','G'};ax.XLim=[.5,5.5];
        end
    end
    named=findall(ax,'-property','DisplayName');
    for h=named'
        if ~isvalid(h),continue;end
        if contains(string(h.DisplayName),'previous')||string(h.DisplayName)=="P0"
            if strcmp(name,'Fig3')
                color=h.Color;patches=findall(ax,'Type','patch');n=0;
                for q=patches'
                    if isnumeric(q.FaceColor)&&isequal(q.FaceColor,color),delete(q);n=n+1;end
                end
                assert(n==1,'Expected one retired IQR band for each curve');
            end
            delete(h);removed=removed+1;
        end
    end
end
% Assert all surviving data other than box-chart display categories are retained.
% Coordinate equality during subsequent styling is also checked in make_figures.
survivors=0;
for k=1:numel(original)
    h=original(k);if ~isvalid(h),continue;end;survivors=survivors+1;
    for j=1:3
        prop={'XData','YData','ZData'};if ~isprop(h,prop{j}),continue;end
        expected=saved{k,j};
        if j==1&&strcmp(name,'Fig2')&&isa(h,'matlab.graphics.chart.primitive.BoxChart')&&expected(1)>2,expected=expected-1;end
        assert(isequaln(expected,h.(prop{j})),'Retained series values changed');
    end
end
names=findall(f,'-property','DisplayName');
assert(~any(arrayfun(@(h)contains(string(h.DisplayName),'previous')||string(h.DisplayName)=="P0",names)));
if strcmp(name,'Fig2'),assert(removed==6&&checked==25);end
if strcmp(name,'Fig3'),assert(removed==6);end
if strcmp(name,'Fig6'),assert(removed==1);end
fprintf('%s: removed %d retired chart objects; retained values unchanged.\n',name,removed);
base=fileparts(mfilename('fullpath'));
writelines(jsonencode(struct('figure',name,'removedSeriesOrLegend',removed,'retainedObjectsChecked',survivors,'retainedNumericalValuesUnchanged',true,'boxCategoryReindexOnly',strcmp(name,'Fig2'))),fullfile(base,'figures',[name,'_removal_audit.json']));
end
