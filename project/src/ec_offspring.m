function [Y,meta]=ec_offspring(X,Fobj,GX,GF,lower,upper,state,cfg)
% All vector arithmetic is in decision space. Fobj is only a contract check.
[n,d]=size(X); assert(n>=4 && size(Fobj,1)==n);
if cfg.adaptive
    slot=randi(numel(state.MF),n,1);
    scale=state.MF(slot)+.1*tan(pi*(rand(n,1)-.5));
    bad=scale<=0;
    while any(bad)
        scale(bad)=state.MF(slot(bad))+.1*tan(pi*(rand(sum(bad),1)-.5)); bad=scale<=0;
    end
    scale=min(scale,1); cross=max(0,min(1,state.MCR(slot)+.1*randn(n,1)));
else
    scale=.5*ones(n,1); cross=.9*ones(n,1);
end
if cfg.B, weights=ec_guide_weights(GF); else, weights=ones(size(GX,1),1)/size(GX,1); end
if cfg.shuffle, weights=weights(randperm(numel(weights))); end
prob=.5; if cfg.C, prob=state.pLocal; end
arm=1+(rand(n,1)<prob); cumulative=cumsum(weights); cumulative(end)=1;
Y=X;
for i=1:n
    candidates=[1:i-1,i+1:n]; r=candidates(randperm(n-1,3));
    if arm(i)==1
        v=X(r(1),:)+scale(i)*(X(r(2),:)-X(r(3),:));
    else
        g=find(rand<=cumulative,1);
        v=X(i,:)+scale(i)*(GX(g,:)-X(i,:))+scale(i)*(X(r(1),:)-X(r(2),:));
    end
    mask=rand(1,d)<cross(i); mask(randi(d))=true;
    Y(i,mask)=v(mask);
end
L=repmat(lower,n,1); U=repmat(upper,n,1);
bad=Y<L; Y(bad)=(X(bad)+L(bad))/2;
bad=Y>U; Y(bad)=(X(bad)+U(bad))/2;
assert(all(isfinite(Y),'all'));
meta=struct('F',scale,'CR',cross,'arm',arm,'pLocal',prob);
end
