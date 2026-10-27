classdef ERTheory
 methods(Static)
 function [g,square,oscillatory,projection]=landscape(p,x)
  switch p.name
   case 'DTLZ3'
    t=x(:,3:end)-.5;square=100*sum(t.^2,2);oscillatory=100*sum(1-cos(20*pi*t),2);g=square+oscillatory;
    a=x(:,1)*pi/2;b=x(:,2)*pi/2;projection=[cos(a).*cos(b),cos(a).*sin(b),sin(a)];
   case 'ZDT4'
    t=x(:,2:end);square=sum(t.^2,2);oscillatory=10*sum(1-cos(4*pi*t),2);g=1+square+oscillatory;projection=[x(:,1),1-sqrt(max(x(:,1),0))];
   case 'ZDT1'
    square=9*mean(x(:,2:end),2);oscillatory=zeros(size(square));g=1+square;projection=[x(:,1),1-sqrt(max(x(:,1),0))];
   otherwise,g=[];square=[];oscillatory=[];projection=[];
  end
 end
 function expected=expectedG(problem,base,variance)
  if strcmp(problem,'DTLZ3'),t=base(:,3:end)-.5;v=variance(:,3:end);expected=100*sum(v+cos(20*pi*t).*(-expm1(-.5*(20*pi)^2*v)),2);
  elseif strcmp(problem,'ZDT4'),t=base(:,2:end);v=variance(:,2:end);expected=sum(v+10*cos(4*pi*t).*(-expm1(-.5*(4*pi)^2*v)),2);
  else,expected=zeros(size(base,1),1);end
 end
 end
end
