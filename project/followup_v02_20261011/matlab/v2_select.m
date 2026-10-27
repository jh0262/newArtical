function [id,info]=v2_select(F,CV,N,method)
% Input has canonical ascending evaluation IDs. Return indices in that order.
info=struct('ear',false,'fallback',false,'coverage',NaN,'bound',NaN, ...
    'front_rank',0,'front_size',0,'K',0);
feas=find(CV==0);
if numel(feas)<=N
    bad=find(CV>0); [~,o]=sortrows([CV(bad),bad],[1 2]);
    id=sort([feas;bad(o(1:N-numel(feas)))]); return;
end
[rank,last]=NDSort(F(feas,:),N); front=feas(rank==last); id=feas(rank<last); K=N-numel(id);
info.front_rank=last; info.front_size=numel(front); info.K=K;
if K>0
    if K==numel(front), chosen=(1:K)';
    elseif strcmp(method,'ear')
        [chosen,z]=ec_earclip(F(front,:),K);
        info.ear=true; info.fallback=z.fallback; info.coverage=z.coverage; info.bound=z.bound;
    elseif strcmp(method,'pcd'), chosen=v2_pcd(F(front,:),K);
    else, assert(strcmp(method,'cd')); chosen=ec_cd_subset(F(front,:),K); end
    id=[id(:);front(chosen(:))];
end
id=sort(id); assert(numel(id)==N && numel(unique(id))==N);
end
