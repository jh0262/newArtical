function [id,info]=bs_select(F,CV,N,method)
% Feasible-first selection; aggregate CV ranks infeasible designs.
feas=find(CV==0); info=struct('ear',false,'fallback',false,'coverage',0,'bound',0);
if numel(feas)<=N
    bad=find(CV>0); [~,o]=sortrows([CV(bad),bad],[1 2]);
    id=[feas;bad(o(1:N-numel(feas)))]; return;
end
if strcmp(method,'spea')
    id=feas(spea(F(feas,:),N)); return;
end
[r,last]=NDSort(F(feas,:),N); front=feas(r==last); id=feas(r<last); K=N-numel(id);
if K>0
    if strcmp(method,'ear') && K<numel(front)
        [ii,z]=ec_earclip(F(front,:),K); info=z; info.ear=true;
    else
        ii=ec_cd_subset(F(front,:),K);
    end
    id=[id(:);front(ii(:))];
end
assert(numel(id)==N&&numel(unique(id))==N);
end

function keep=spea(F,N)
n=size(F,1); [fit,D]=bs_spea_fitness(F);
keep=find(fit<1);
if numel(keep)<N
    [~,o]=sortrows([fit,(1:n)'],[1 2]); keep=o(1:N);
else
    while numel(keep)>N
        v=sort(D(keep,keep),2); [~,o]=sortrows(v); keep(o(1))=[];
    end
end
end
