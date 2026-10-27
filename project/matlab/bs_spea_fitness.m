function [fit,D]=bs_spea_fitness(F)
n=size(F,1);
dom=all(reshape(F,n,1,2)<=reshape(F,1,n,2),3)&any(reshape(F,n,1,2)<reshape(F,1,n,2),3);
strength=sum(dom,2); raw=double(dom')*strength;
D=sqrt(sum((reshape(F,n,1,2)-reshape(F,1,n,2)).^2,3)); D(1:n+1:end)=inf;
sorted=sort(D,2); fit=raw+1./(sorted(:,max(1,floor(sqrt(n))))+2);
end
