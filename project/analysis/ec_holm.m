function q=ec_holm(p)
original=size(p); p=p(:); assert(all(isfinite(p)) && all(p>=0 & p<=1));
[v,o]=sort(p); m=numel(p);
adjusted=min(1,cummax(v.*(m:-1:1)'));
q=zeros(m,1); q(o)=adjusted; q=reshape(q,original);
end
