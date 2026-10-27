function [q,v]=bs_hom(q0,v0,t,w,z)
% Exact homogeneous damped-oscillator transition. Inputs may be arrays.
wd=w.*sqrt(1-z.^2); lam=z.*w; e=exp(-lam.*t);
c=cos(wd.*t); s=sin(wd.*t);
q=e.*(q0.*c+(v0+lam.*q0)./wd.*s);
v=e.*(v0.*c-(lam.*v0+w.^2.*q0)./wd.*s);
end
