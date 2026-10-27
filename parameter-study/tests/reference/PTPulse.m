classdef PTPulse
 methods(Static)
  function [step,rows,applied,ld,gates]=draw(V,P,lambda,c,sigma,stagnation,n,d)
   low=lambda<=c.lowVarianceRatio*max(mean(lambda),1e-12);ld=sum(low);
   h=stagnation>=c.window; l=ld>0;
   eligible=c.useLock && h && (strcmp(c.pulseTrigger,'single') || l);
   step=zeros(0,d);rows=[];applied=false;effective=ld;
   if eligible
    if ~l
     % Single-condition arm uses the minimum eigenvector when no threshold
     % direction exists. This rule is frozen before performance experiments.
     [~,k]=min(lambda);P=V(:,k)*V(:,k)';effective=1;
    end
    scale=max(sqrt(mean(lambda)),1e-6);
    rows=randperm(n,max(1,round(n*c.pulseFraction)));
    step=min(c.pulseCap,sigma)*((randn(numel(rows),d)*P).*scale);
    before=sqrt(sum(step.^2,2));
    if strcmp(c.pulseDirection,'random')
     % Fixed orthogonal rotations are not isotropic controls. Draw uniform
     % spherical directions from a separate stream, preserving exact lengths
     % and the main stream used by all regular search operations.
     % Deterministic key from the current main RNG state makes calls stateless
     % across repeated runs while leaving the global RNG untouched.
     rs=rng;rawState=rs.State;if iscell(rawState),rawState=rawState{1};end
     key=mod(sum(double(rawState(1:16)).*(1:16)')+c.seed+20261025,2^32-1);
     aux=RandStream('mt19937ar','Seed',key);q=randn(aux,numel(rows),d);q=q./max(vecnorm(q,2,2),realmin);
     step=q.*before;
    end
    after=sqrt(sum(step.^2,2));applied=true;
   else,before=0;after=0;end
   gates=[h,l,ld,effective,applied,sqrt(mean(before.^2)),sqrt(mean(after.^2))];
   if ~h || ~c.useLock,ld=0;end % Preserve original history-column semantics.
  end
 end
end
