function idx=ec_cd_subset(F,K)
n=size(F,1); assert(K>=1 && K<=n && K==floor(K));
cd=zeros(n,1);
for j=1:size(F,2)
    [v,o]=sort(F(:,j),'ascend');
    cd(o([1 end]))=inf;
    if n>2 && v(end)>v(1)
        cd(o(2:end-1))=cd(o(2:end-1))+(v(3:end)-v(1:end-2))/(v(end)-v(1));
    end
end
[~,order]=sortrows([-cd,(1:n)'],[1 2]);
idx=order(1:K)';
end
