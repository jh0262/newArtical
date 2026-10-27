function report=bs_preflight()
p=bs_config(); addpath(fullfile(p.root,'matlab','vendor')); rng(92103,'twister');
assert(height(p.catalog)==19 && numel(unique(p.catalog.model))==19);
X=[10,.95,.3,.25;14,1,.25,.4;19,1.5,.49,.5]; [F,CV]=bs_evaluate(X,p);
for i=1:3
    [f,cv]=bs_evaluate(X(i,:),p); assert(max(abs(F(i,:)-f))<1e-12 && abs(CV(i)-cv)<1e-12);
end
coverage_excess=0;
for t=1:60
    n=randi([12,100]); k=randi([2,n-1]); f=[sort(rand(n,1)),sort(rand(n,1),'descend')];
    [id,z]=ec_earclip(f,k); base=ec_cd_subset(f,k); assert(numel(unique(id))==k);
    Q=(f-min(f))./(max(f)-min(f)); D=hypot(Q(:,1)-Q(:,1)',Q(:,2)-Q(:,2)');
    actual=max(min(D(:,id),[],2)); b=max(min(D(:,base),[],2));
    assert(actual<=b+1e-10 && z.coverage<=z.bound+1e-10);
    coverage_excess=max(coverage_excess,actual-b);
end
for how={'cd','ear','spea'}
    FF=rand(30,2); cv=[zeros(20,1);ones(10,1)]; id=bs_select(FF,cv,16,how{1}); assert(all(cv(id)==0));
    cv=(1:30)'; id=bs_select(FF,cv,16,how{1}); assert(isequal(sort(id),(1:16)'));
end
[sx,~]=bs_archive([1,0,0,0;2,0,0,0],[0,0;1,1],2,true);
[gx,~]=bs_archive([1,0,0,0;2,0,0,0],[0,0;1,1],2,false);
assert(size(sx,1)==2 && size(gx,1)==1);
f=[0,0;1,1;2,0]; fit=bs_spea_fitness(f); assert(fit(1)<1 && all(fit(2:3)>1));
fitness=bs_ga_fitness([0,0;1,1;2,0],[1;0;0],false); assert(all(fitness(2:3,3)==1));
[hv,exc]=bs_hv([.7,1;1.5,0],p); assert(abs(hv-.21)<1e-12&&exc==0);
p.cycle_limit_s=3;
a=bs_mode('MODE-EAR-S',92104,32,10,p); b=bs_mode('MODE-EAR-S',92104,32,10,p);
assert(isequal(a.X,b.X)&&isequal(a.F,b.F)&&isequal(a.trace,b.trace));
a=bs_qmc(92104,32,10,p); b=bs_qmc(92104,32,10,p);
assert(isequal(a.X,b.X)&&isequal(a.F,b.F)&&a.FE==352);
report=struct('status','PASS','catalogue_rows',19,'coverage_random_fronts',60, ...
    'maximum_coverage_excess',coverage_excess,'batch_scalar_cases',3,'feasible_first_selectors',3, ...
    'archive_fixture','PASS','SPEA_strength_fixture','PASS','HV_rectangle_fixture','PASS', ...
    'MODE_repeatability','PASS','QMC_repeatability','PASS','matlab',version);
out=fullfile(p.root,'verification_v02','algorithm_preflight.json'); fid=fopen(out,'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(report,PrettyPrint=true),'char'); disp(report);
end
