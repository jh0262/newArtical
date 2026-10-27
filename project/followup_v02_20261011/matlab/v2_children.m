function Y=v2_children(X,AX,p)
% Same mixed-category DE operations and RNG call order as frozen bs_mode.
n=size(X,1); Z=(X(:,2:4)-p.lower')./(p.upper-p.lower)';
if isempty(AX), AX=X; end
guide=AX(randi(size(AX,1),n,1),:); Q=(guide(:,2:4)-p.lower')./(p.upper-p.lower)';
V=Z;
for i=1:n
    other=[1:i-1,i+1:n]; rr=other(randperm(n-1,3));
    if rand<.5, v=Z(rr(1),:)+.5*(Z(rr(2),:)-Z(rr(3),:));
    else, v=Z(i,:)+.5*(Q(i,:)-Z(i,:))+.5*(Z(rr(1),:)-Z(rr(2),:)); end
    mask=rand(1,3)<.9; mask(randi(3))=true; V(i,mask)=v(mask);
end
lo=V<0; hi=V>1; V(lo)=Z(lo)/2; V(hi)=(1+Z(hi))/2;
cat=X(:,1); cr=rand(n,1); mask=cr<.1; cat(mask)=randi(height(p.catalog),sum(mask),1);
mask=cr>=.1 & cr<.5; cat(mask)=guide(mask,1);
Y=[cat,p.lower'+V.*(p.upper-p.lower)'];
end
