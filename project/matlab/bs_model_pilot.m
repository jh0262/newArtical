function bs_model_pilot()
% Bounded structural screening and export for independent Python ODE checks.
p=bs_config(); out=fullfile(p.root,'verification_v02'); if ~isfolder(out), mkdir(out); end
rng(p.pilot_seed,'twister');
n=20000; X=[randi(height(p.catalog),n,1),p.lower'+rand(n,3).*(p.upper-p.lower)'];
t=tic; [F,CV,G]=bs_evaluate(X,p); elapsed=toc(t);
ok=CV==0;
tbl=array2table([X,F,CV],'VariableNames',{'catalog_row','T_s','r','u','time_s','residual_um','CV'});
writetable(tbl,fullfile(out,'screening_samples.csv'));
counts=accumarray(X(ok,1),1,[height(p.catalog),1]);
writetable(table(p.catalog.model,counts,'VariableNames',{'model','feasible_count'}),fullfile(out,'feasible_models.csv'));
% Fixed-profile slices test oscillatory structure. These are not Pareto solutions.
Ts=linspace(.7,1.5,1601)'; XS=[10*ones(size(Ts)),Ts,.30*ones(size(Ts)),.25*ones(size(Ts))];
[FS,CS]=bs_evaluate(XS,p);
writetable(array2table([XS,FS,CS],'VariableNames',tbl.Properties.VariableNames),fullfile(out,'time_slice.csv'));
mask=CS==0; fs=FS(mask,2); ds=diff(fs);
summary=struct('stage','bounded model screening, not optimizer comparison','seed',p.pilot_seed, ...
    'design_evaluations',n+numel(Ts),'scenario_count',9,'batch_seconds',elapsed,'seconds_per_design',elapsed/n, ...
    'feasible_samples',sum(ok),'feasible_models',find(counts>0)', ...
    'slice_feasible_points',sum(mask),'slice_positive_differences',sum(ds>1e-10), ...
    'slice_negative_differences',sum(ds< -1e-10),'slice_local_minima',sum(ds(1:end-1)<0 & ds(2:end)>0), ...
    'constraint_names',{{'cycle','catalog_rpm','DN','critical_rpm','static_capacity','buckling','deflection','torque_proxy','single_flank_load','life_screen'}}, ...
    'max_constraint_violation',max(G,[],1),'matlab',version);
writejson(fullfile(out,'model_screening.json'),summary);
% Export independent verification cases including bound edges and zero-length plateaus.
ids=[1;3;6;8;10;12;14;17;19];
Y=[ids,linspace(.7,1.5,9)',linspace(.15,.49,9)',[.1;.15;.2;.25;.3;.35;.4;.45;.5]];
[FY,CY,GY,d]=bs_evaluate(Y,p); %#ok<ASGLU>
rows=[];
for i=1:size(Y,1)
    for s=[1,5,9]
        rows(end+1,:)=[Y(i,:),s,d.m(i,s),d.k(i,s),d.w(i,s),d.q0(i,s),d.v0(i,s),d.qT(i,s),d.vT(i,s),d.R_um(i,s)*1e-6,d.force_dynamic_bound_N(i,s),d.deflection_bound_um(i,s)*1e-6]; %#ok<AGROW>
    end
end
writetable(array2table(rows,'VariableNames',{'catalog_row','T','r','u','scenario','m','k','w','q0','v0','qT','vT','R_m','dynamic_force_bound','total_deflection_bound'}),fullfile(out,'ode_cases.csv'));
f=figure('Visible','off','Color','w'); tiledlayout(1,2);
nexttile; scatter(F(ok,1),F(ok,2),8,X(ok,1),'filled'); xlabel('Move time (s)'); ylabel('Worst-scenario residual envelope (\mum)'); title('Feasible model predictions'); grid on;
nexttile; plot(FS(:,1),FS(:,2),'Color',[.7,.7,.7]); hold on; plot(FS(mask,1),FS(mask,2),'b.'); xlabel('Move time (s)'); ylabel('Residual envelope (\mum)'); title('Fixed catalogue and shape: structural slice'); grid on;
exportgraphics(f,fullfile(out,'model_screening.png'),'Resolution',180); close(f);
disp(summary);
end

function writejson(path,value)
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(value,PrettyPrint=true),'char');
end
