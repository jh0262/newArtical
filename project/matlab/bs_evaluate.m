function [F,CV,G,detail]=bs_evaluate(X,p)
% X=[catalog_row,T,r,u]. One row = one design evaluation (all scenarios).
assert(size(X,2)==4 && all(isfinite(X),'all'));
idx=X(:,1); assert(all(idx==fix(idx)&idx>=1&idx<=height(p.catalog)));
assert(all(X(:,2:4)>=p.lower'-1e-14 & X(:,2:4)<=p.upper'+1e-14,'all'));
c=p.catalog(idx,:); T=X(:,2); r=X(:,3); u=X(:,4);
[mm,kk]=ndgrid(p.mass_scenarios_kg,p.stiffness_factors);
m=c.nut_mass_kg+mm(:)';
area=pi*(c.dc_mm*1e-3).^2/4;
ks=p.youngs_modulus_Pa*area/p.shaft_length_m;
kn=c.K_N_um*1e6;
k=(1./(1./ks+1./kn+1/p.bearing_stiffness_N_m)).*kk(:)';
w=sqrt(k./m); z=p.damping_ratio;
[R,B,D,q0,v0,qT,vT]=bs_response(T,r,u,w,z,m,k,p);
h=r.*T; tj=u.*h;
vmax=p.stroke_m./(T-h); amax=p.stroke_m./((h-tj).*(T-h));
rpm=60*vmax./(c.lead_mm*1e-3);
Fg=m*p.gravity_m_s2; Fu=Fg+B;
I=pi*(c.dc_mm*1e-3).^4/64;
Pcr=pi^2*p.youngs_modulus_Pa*I/(p.effective_length_factor*p.shaft_length_m)^2;
ncr=p.critical_betaL^2*sqrt(p.youngs_modulus_Pa*I./(c.shaft_mass_kg_m*p.shaft_length_m^4))*60/(2*pi)*p.critical_utilization;
Js=c.shaft_inertia_kg_m2_per_mm*(p.shaft_length_m*1000);
torque=Fu.*(c.lead_mm*1e-3)/(2*pi*p.efficiency)+Js.*(2*pi./(c.lead_mm*1e-3)).*amax;
meanrpm=60*p.stroke_m./(c.lead_mm*1e-3)./(T+p.dwell_s);
life=1e6./(60*meanrpm).*(c.Ca_kN*1000./(p.load_factor*Fu)).^3;
G=[2*(T+p.dwell_s)/p.cycle_limit_s-1, rpm./c.max_rpm-1, ...
    c.dp_mm.*rpm/p.dn_limit-1,rpm./ncr-1, ...
    max(p.static_safety*Fu./(c.C0a_kN*1000)-1,[],2), ...
    max(p.buckling_safety*Fu./Pcr-1,[],2), ...
    max((Fg./k+D)/p.deflection_limit_m-1,[],2), ...
    max(torque/p.peak_torque_limit_Nm-1,[],2), ...
    max(B./Fg-1,[],2), max(p.life_target_h./life-1,[],2)];
CV=sum(max(0,G-p.constraint_tolerance),2);
F=[T,max(R,[],2)*1e6];
assert(all(isfinite(F),'all')&&all(isfinite(G),'all'));
if nargout>3
    detail=struct('R_um',R*1e6,'frequency_Hz',w/(2*pi),'force_dynamic_bound_N',B, ...
        'force_upper_N',Fu,'deflection_bound_um',(Fg./k+D)*1e6,'torque_bound_Nm',torque, ...
        'life_lower_h',life,'q0',q0,'v0',v0,'qT',qT,'vT',vT,'k',k,'m',m,'w',w, ...
        'vmax',vmax,'amax',amax,'rpm',rpm);
end
end
