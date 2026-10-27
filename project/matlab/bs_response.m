function [R,forceBound,defBound,q0,v0,q,v]=bs_response(T,r,u,w,z,m,k,p)
% Exact seven-segment response with anti-periodic steady-state initial data.
h=r.*T; tj=u.*h; ta=h-2*tj; tv=T-2*h;
J=p.stroke_m./(tj.*(h-tj).*(T-h));
dt=[tj,ta,tj,tv,tj,ta,tj]; jj=J.*[1,0,-1,0,-1,0,1];
q=zeros(size(w)); v=q; a=zeros(size(T));
for n=1:7
    [q,v]=advance(q,v,a,jj(:,n),dt(:,n),w,z); a=a+jj(:,n).*dt(:,n);
end
[bq,bv]=bs_hom(q,v,p.dwell_s,w,z);
[P11,P21]=bs_hom(ones(size(w)),zeros(size(w)),T+p.dwell_s,w,z);
[P12,P22]=bs_hom(zeros(size(w)),ones(size(w)),T+p.dwell_s,w,z);
detM=(1+P11).*(1+P22)-P12.*P21;
q0=(-bq.*(1+P22)+P12.*bv)./detM;
v0=(-(1+P11).*bv+P21.*bq)./detM;
q=q0; v=v0; a=zeros(size(T)); forceBound=zeros(size(w)); defBound=forceBound;
for n=1:7
    j=jj(:,n); t=dt(:,n); ae=a+j.*t;
    qp=-a./w.^2+2*z.*j./w.^3; vp=-j./w.^2;
    y=q-qp; yd=v-vp; wd=w.*sqrt(1-z.^2); lam=z.*w; damp=2*z.*w.*m;
    aq=hypot(y,(yd+lam.*y)./wd);
    C=k.*y+damp.*yd;
    S=(k.*(yd+lam.*y)-damp.*(lam.*yd+w.^2.*y))./wd;
    fb=m.*max(abs(a),abs(ae))+hypot(C,S);
    db=max(abs(qp),abs(-ae./w.^2+2*z.*j./w.^3))+aq;
    % A zero-duration segment has no interval to bound.
    fb(t==0,:)=0; db(t==0,:)=0;
    forceBound=max(forceBound,fb); defBound=max(defBound,db);
    [q,v]=advance(q,v,a,j,t,w,z); a=ae;
end
wd=w.*sqrt(1-z.^2); lam=z.*w; damp=2*z.*w.*m;
R=hypot(q,(v+lam.*q)./wd);
forceBound=max(forceBound,hypot(k.*q+damp.*v,(k.*(v+lam.*q)-damp.*(lam.*v+w.^2.*q))./wd));
defBound=max(defBound,R);
end

function [q,v]=advance(q,v,a,j,t,w,z)
qp=-a./w.^2+2*z.*j./w.^3; vp=-j./w.^2;
[q,v]=bs_hom(q-qp,v-vp,t,w,z);
q=q-(a+j.*t)./w.^2+2*z.*j./w.^3; v=v+vp;
end
