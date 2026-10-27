function keep=v2_pcd(F,K)
% Deterministic reference pruning CD; input rows are in ascending stable ID.
% Update only affected neighbours; recompute if removing a boundary.
n=size(F,1); assert(K>=1 && K<=n && K==floor(K));
if K==1, keep=ec_cd_subset(F,1); return; end
alive=true(n,1); left=zeros(n,2); right=zeros(n,2); span=zeros(1,2);
con=zeros(n,2); rebuild();
for count=n:-1:K+1
    a=find(alive); score=sum(con(a,:),2); low=min(score);
    tie=a(score==low); gone=tie(end); % Keep earlier stable IDs on exact ties.
    boundary=any(left(gone,:)==0 | right(gone,:)==0);
    alive(gone)=false;
    if boundary, rebuild(); continue; end
    for axisIndex=1:2
        previous=left(gone,axisIndex); following=right(gone,axisIndex);
        right(previous,axisIndex)=following; left(following,axisIndex)=previous;
        refresh(previous,axisIndex); refresh(following,axisIndex);
    end
end
keep=find(alive);
    function rebuild()
        activeRows=find(alive); con(:)=0; left(:)=0; right(:)=0;
        for rebAxis=1:2
            [~,rebOrder]=sortrows([F(activeRows,rebAxis),activeRows],[1 2]); sortedRows=activeRows(rebOrder); numberRows=numel(sortedRows);
            span(rebAxis)=F(sortedRows(end),rebAxis)-F(sortedRows(1),rebAxis);
            left(sortedRows(2:numberRows),rebAxis)=sortedRows(1:numberRows-1);
            right(sortedRows(1:numberRows-1),rebAxis)=sortedRows(2:numberRows);
            for rebRow=1:numberRows, refresh(sortedRows(rebRow),rebAxis); end
        end
    end
    function refresh(rowNo,axisNo)
        neighbourLeft=left(rowNo,axisNo); neighbourRight=right(rowNo,axisNo);
        if neighbourLeft==0 || neighbourRight==0
            con(rowNo,axisNo)=inf;
        elseif span(axisNo)>0
            con(rowNo,axisNo)=(F(neighbourRight,axisNo)-F(neighbourLeft,axisNo))/span(axisNo);
        else
            con(rowNo,axisNo)=0;
        end
    end
end
