function score=ec_igdplus(F,R)
% IGD+: distance from every reference point to attained weak dominators.
assert(size(F,2)==2 && all(isfinite(F),'all') && all(isfinite(R),'all'),'EC:InvalidObjectives','Invalid objectives.');
if isempty(F), score=inf; return; end
d1=max(0,R(:,1)*0+F(:,1)'-R(:,1));
d2=max(0,R(:,2)*0+F(:,2)'-R(:,2));
score=mean(min(hypot(d1,d2),[],2));
end
