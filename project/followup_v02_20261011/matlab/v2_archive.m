function keep=v2_archive(X,F,CV,ids,K,method)
% Global feasible archive, exact X de-duplication, then objective ND filtering.
ids=sort(ids(:)); ids=ids(CV(ids)==0);
if isempty(ids), keep=ids; return; end
[~,ia]=unique(X(ids,:),'rows','stable'); ids=ids(ia);
ids=sort(ids(ec_nd_indices(F(ids,:))));
if numel(ids)>K
    if strcmp(method,'pcd'), sub=v2_pcd(F(ids,:),K);
    else, assert(strcmp(method,'cd')); sub=ec_cd_subset(F(ids,:),K); end
    ids=ids(sub);
end
keep=sort(ids);
end
