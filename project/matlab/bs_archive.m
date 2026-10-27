function [X,F]=bs_archive(X,F,K,stratified)
% Same total capacity for global and category-stratified guide archives.
if isempty(X), return; end
[X,ia]=unique(X,'rows','stable'); F=F(ia,:);
if ~stratified
    id=ec_nd_indices(F); X=X(id,:); F=F(id,:);
    if size(X,1)>K, id=ec_cd_subset(F,K); X=X(id,:); F=F(id,:); end
    return;
end
cats=unique(X(:,1))'; groups=cell(size(cats));
for j=1:numel(cats)
    id=find(X(:,1)==cats(j)); groups{j}=id(ec_nd_indices(F(id,:)));
end
% Allocate round-robin slots up to available candidates, then truncate each group.
quota=zeros(size(cats)); total=0;
while total<K
    progressed=false;
    for j=1:numel(cats)
        if total<K && quota(j)<numel(groups{j})
            quota(j)=quota(j)+1; total=total+1; progressed=true;
        end
    end
    if ~progressed, break; end
end
keep=[];
for j=1:numel(cats)
    id=groups{j}; if quota(j)<numel(id), id=id(ec_cd_subset(F(id,:),quota(j))); end
    keep=[keep;id(:)]; %#ok<AGROW>
end
X=X(keep,:); F=F(keep,:);
end
