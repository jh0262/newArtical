function [idx,info]=ec_earclip(F,K)
% Coverage-bounded greedy ear deletion on ONE nondominated front.
n=size(F,1); baseline=ec_cd_subset(F,K);
Z=(F-min(F,[],1))./max(max(F,[],1)-min(F,[],1),eps);
D=hypot(Z(:,1)-Z(:,1)',Z(:,2)-Z(:,2)');
budget=max(min(D(:,baseline),[],2));
info=struct('fallback',false,'coverage',budget,'bound',budget,'deletions',0);
if K>=n || K<2, idx=baseline; return; end
[Z,order]=sortrows(Z,[1 2]); D=D(order,order);
left=(0:n-1)'; right=(2:n+1)'; alive=true(n,1);
areas=inf(n,1); costs=inf(n,1);
for i=2:n-1, update(i); end
count=n;
while count>K
    valid=find(alive & costs<=budget+1e-12 & isfinite(areas));
    if isempty(valid)
        idx=baseline; info.fallback=true; return;
    end
    a=min(areas(valid)); valid=valid(areas(valid)<=a+1e-12);
    c=min(costs(valid)); valid=valid(costs(valid)<=c+1e-12);
    i=valid(1); l=left(i); r=right(i);
    alive(i)=false; right(l)=r; left(r)=l; count=count-1;
    info.deletions=info.deletions+1;
    update(l); update(r);
end
idx=order(alive)';
info.coverage=max(min(D(:,alive),[],2));
assert(info.coverage<=budget+1e-10,'EC:Coverage','Coverage bound violated.');
    function update(i)
        l=left(i); r=right(i);
        if l<1 || r>n, areas(i)=inf; costs(i)=inf; return; end
        u=Z(i,:)-Z(l,:); v=Z(r,:)-Z(l,:);
        areas(i)=abs(u(1)*v(2)-u(2)*v(1))/2;
        % For a monotone nondominated chain, every original point between
        % retained endpoints has a nearest retained point at an endpoint.
        costs(i)=max(min(D(l:r,[l r]),[],2));
    end
end
