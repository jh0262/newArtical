function w=ec_guide_weights(F)
n=size(F,1); w=ones(n,1)/n;
if n<3, return; end
Z=(F-min(F,[],1))./max(max(F,[],1)-min(F,[],1),eps);
[Z,ord]=sortrows(Z,[1 2]); U=diff(Z); gap=hypot(U(:,1),U(:,2));
positive=gap(gap>eps);
if isempty(positive), return; end
med=median(positive); cap=med+2*median(abs(positive-med));
gap=min(gap,max(cap,eps)); density=([gap(1);gap]+[gap;gap(end)])/2;
bend=zeros(n,1);
den=hypot(U(1:end-1,1),U(1:end-1,2)).*hypot(U(2:end,1),U(2:end,2));
bend(2:end-1)=abs(U(1:end-1,1).*U(2:end,2)-U(1:end-1,2).*U(2:end,1))./max(den,eps);
score=max(density,eps).*(1+bend);
w(ord)=score/sum(score);
end
