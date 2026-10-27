function bs_two_mode_check()
% A model-form stress test, NOT a validated high-fidelity model.
% Coordinates: relative screw end z1 and nut/load z2 from ideal base motion.
% Shaft effective moving mass = shaft mass / 3 (assumed linear axial shape).
p=bs_config(); addpath(fullfile(p.root,'matlab','vendor')); p.cycle_limit_s=3;
out=fullfile(p.root,'verification_v02'); rows=[];
names={'MODE-CD-G','MODE-EAR-S','MV-NSGA-II','MV-SPEA2','CAT-QMC'};
for i=1:numel(names)
    data=load(fullfile(p.root,'pilot_v02',[names{i},'_seed92102.mat'])); result=data.result;
    good=find(result.CV==0); if isempty(good), continue; end
    [~,a]=min(result.F(good,1)); [~,b]=min(result.F(good,2));
    for ix=unique(good([a b]))'
        x=result.X(ix,:); cat=p.catalog(x(1),:); mm=cat.nut_mass_kg+100;
        ks=p.youngs_modulus_Pa*pi*(cat.dc_mm*1e-3)^2/(4*p.shaft_length_m);
        kb=1/(1/ks+1/p.bearing_stiffness_N_m); kn=cat.K_N_um*1e6;
        ms=cat.shaft_mass_kg_m*p.shaft_length_m/3;
        M=diag([ms,mm]); K=[kb+kn,-kn;-kn,kn];
        [V,D]=eig(K,M); [ww,o]=sort(sqrt(diag(D))); V=V(:,o);
        for j=1:2, V(:,j)=V(:,j)/sqrt(V(:,j)'*M*V(:,j)); end
        participation=V'*M*ones(2,1); coeff=V(2,:)'.*participation;
        [R,~,~,~,~,qT,vT]=bs_response(x(2),x(3),x(4),ww',p.damping_ratio,ones(1,2),(ww.^2)',p);
        twoBound=sum(abs(coeff').*R)*1e6;
        q=p; q.mass_scenarios_kg=100; q.stiffness_factors=1;
        f=bs_evaluate(x,q);
        ts=linspace(0,p.dwell_s,ceil(p.dwell_s*max(ww)/(2*pi)*40)+1)';
        [qt,~]=bs_hom(qT,vT,ts,ww',p.damping_ratio); waveform=qt*coeff;
        peak=max(abs(waveform))*1e6;
        rows=[rows;table(string(names{i}),x(1),x(2),x(3),x(4),f(2),twoBound,peak,ww(1)/(2*pi),ww(2)/(2*pi), ...
            'VariableNames',{'method','catalog_row','T_s','r','u','single_mode_envelope_um','two_mode_envelope_bound_um','two_mode_sampled_dwell_peak_um','f1_Hz','f2_Hz'})]; %#ok<AGROW>
    end
end
writetable(rows,fullfile(out,'two_mode_stress_test.csv')); disp(rows);
end
