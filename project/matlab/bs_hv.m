function [h,excluded]=bs_hv(F,p)
% Fixed physical scaling, reference [1.1,1.1], minimization.
h=0; excluded=0; if isempty(F), return; end
Z=[(F(:,1)-p.lower(1))/(p.upper(1)-p.lower(1)),F(:,2)];
inside=all(Z<[1.1,1.1],2); excluded=sum(~inside); Z=Z(inside,:);
if isempty(Z), return; end
Z=Z(ec_nd_indices(Z),:); previous=1.1;
for i=1:size(Z,1)
    h=h+(1.1-Z(i,1))*(previous-Z(i,2)); previous=Z(i,2);
end
end
