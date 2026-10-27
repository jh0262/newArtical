function select_engineering_designs()
% Select best found threshold designs from saved runs, never re-optimize.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'matlab'),fullfile(root,'matlab','vendor'));
p=bs_config(); out=fullfile(root,'analysis_formal'); S=readtable(fullfile(out,'all_final_designs.csv'),'TextType','string'); records=[]; missed=[];
constraintNames=["cycle","catalog_rpm","DN","critical_rpm","static_capacity","buckling","deflection","torque_proxy","single_flank_load","life_screen"];
for cy=[2.5,3,3.5]
    for threshold=[.05,.1,.2]
        Q=S(S.cycle_limit_s==cy & S.CV==0 & S.residual_um<=threshold,:);
        if isempty(Q), missed=[missed;cy,threshold]; continue; end %#ok<AGROW>
        Q=sortrows(Q,{'T_s','residual_um','seed'}); z=Q(1,:); x=[z.catalog_row,z.T_s,z.r,z.u];
        p.cycle_limit_s=cy; [F,CV,G,d]=bs_evaluate(x,p); assert(CV==0&&abs(F(2)-z.residual_um)<1e-12);
        [limiting,ix]=max(G); cat=p.catalog(x(1),:);
        records=[records;table(cy,threshold,z.method,z.seed,cat.model,x(1),x(2),x(3),x(4),2*(x(2)+p.dwell_s),F(2), ...
            d.rpm,max(d.torque_bound_Nm),max(d.deflection_bound_um),min(d.life_lower_h),limiting,constraintNames(ix), ...
            'VariableNames',{'cycle_limit_s','residual_threshold_um','source_method','source_seed','model','catalog_row','T_s','r','u','predicted_cycle_s','residual_um', ...
            'rpm','transmission_torque_bound_Nm','deflection_bound_um','rated_life_screen_h','largest_constraint_value','governing_constraint'})]; %#ok<AGROW>
        if cy==3 && threshold==.1, draw_profile(x,d,p,out); end
    end
end
writetable(records,fullfile(out,'best_found_engineering_designs.csv'));
writematrix(missed,fullfile(out,'unattained_engineering_targets.csv')); disp(records(:,1:11));
end

function draw_profile(x,d,p,out)
[~,scenario]=max(d.R_um); w=d.w(scenario); m=d.m(scenario); k=d.k(scenario); z=p.damping_ratio;
T=x(2); h=x(3)*T; tj=x(4)*h; J=p.stroke_m/(tj*(h-tj)*(T-h));
dt=[tj,h-2*tj,tj,T-2*h,tj,h-2*tj,tj,p.dwell_s]; jj=J*[1,0,-1,0,-1,0,1,0];
q=d.q0(scenario); v=d.v0(scenario); pos=0; vel=0; acc=0; elapsed=0; samples=[];
for n=1:8
    ts=linspace(0,dt(n),max(2,ceil(dt(n)*w/(2*pi)*50)))'; j=jj(n);
    qp=-acc/w^2+2*z*j/w^3; vp=-j/w^2;
    [qt,vt]=bs_hom(q-qp,v-vp,ts,w,z);
    qt=qt-(acc+j*ts)/w^2+2*z*j/w^3; vt=vt+vp;
    position=pos+vel*ts+.5*acc*ts.^2+j*ts.^3/6;
    acceleration=acc+j*ts;
    force=m*p.gravity_m_s2-k*qt-2*z*w*m*vt;
    samples=[samples;elapsed+ts,position,acceleration,qt*1e6,force]; %#ok<AGROW>
    pos=position(end); vel=vel+acc*dt(n)+.5*j*dt(n)^2; acc=acc+j*dt(n);
    q=qt(end); v=vt(end); elapsed=elapsed+dt(n);
end
writematrix(samples,fullfile(out,'selected_trajectory_samples.csv'));
selection=struct('design',x,'scenario_index',scenario,'mass_with_nut_kg',m,'stiffness_N_m',k,'damping_ratio',z, ...
    'case','best found among formal 3.0 s case, residual threshold 0.1 um','columns',{{'time_s','command_position_m','command_acceleration_m_s2','relative_displacement_um','axial_load_N'}});
fid=fopen(fullfile(out,'selected_trajectory_metadata.json'),'w','n','UTF-8'); fwrite(fid,jsonencode(selection,PrettyPrint=true),'char'); fclose(fid);
f=figure('Visible','off','Color','w','Position',[100,100,1000,640]); tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
labels={'Command position (m)','Command acceleration (m/s^2)','Relative displacement (\mum)','Predicted axial load (N)'};
for j=1:4
    nexttile; plot(samples(:,1),samples(:,j+1),'LineWidth',1); xline(T,':','Move ends'); xlabel('Time (s)'); ylabel(labels{j}); grid on; set(gca,'FontSize',10);
end
exportgraphics(f,fullfile(out,'selected_trajectory.png'),'Resolution',180);
exportgraphics(f,fullfile(out,'selected_trajectory.pdf'),'ContentType','vector'); close(f);
end
