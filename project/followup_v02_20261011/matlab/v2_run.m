function result=v2_run(label,popMethod,archiveMethod,seed,p,N,generations)
% Full evaluation ledger is passive: reproduction sees only P and A IDs.
wall=tic; component=zeros(1,6); total=N*(generations+1);
t=tic; rng(seed,'twister'); cats=mod((0:N-1)',height(p.catalog))+1; cats=cats(randperm(N));
initial=[cats,p.lower'+rand(N,3).*(p.upper-p.lower)'];
HX=zeros(total,4); HF=zeros(total,2); HC=zeros(total,1); HG=zeros(total,10);
HX(1:N,:)=initial; parents=(1:N)'; component(1)=toc(t);
t=tic; [HF(1:N,:),HC(1:N),HG(1:N,:)]=bs_evaluate(initial,p); component(2)=toc(t); FE=N;
rng(seed+100000,'twister');
t=tic; archive=v2_archive(HX,HF,HC,parents,N,archiveMethod); component(5)=toc(t);
P=zeros(generations+1,N,'uint32'); A=zeros(generations+1,N,'uint32');
P(1,:)=uint32(parents); A(1,1:numel(archive))=uint32(archive);
trace=zeros(generations+1,7); trace(1,:)=trace_row(0,FE,parents,archive,HX,HF,HC,p);
details=nan(generations,8); % rank, front size, K, ear, fallback, coverage, bound, exceeded
for g=1:generations
    t=tic; Y=v2_children(HX(parents,:),HX(archive,:),p); component(3)=component(3)+toc(t);
    ids=(FE+1:FE+N)'; t=tic; [FY,CY,GY]=bs_evaluate(Y,p); component(2)=component(2)+toc(t);
    assert(all(isfinite(FY),'all') && all(isfinite(CY)) && all(CY>=0));
    t=tic; HX(ids,:)=Y; HF(ids,:)=FY; HC(ids)=CY; HG(ids,:)=GY; FE=FE+N; component(6)=component(6)+toc(t);
    t=tic; archive=v2_archive(HX,HF,HC,[archive;ids(CY==0)],N,archiveMethod); component(5)=component(5)+toc(t);
    union=sort([parents;ids]); t=tic;
    [selected,info]=v2_select(HF(union,:),HC(union),N,popMethod);
    parents=union(selected); component(4)=component(4)+toc(t);
    t=tic; P(g+1,:)=uint32(parents); A(g+1,1:numel(archive))=uint32(archive);
    trace(g+1,:)=trace_row(g,FE,parents,archive,HX,HF,HC,p);
    details(g,:)=[info.front_rank,info.front_size,info.K,info.ear,info.fallback,info.coverage,info.bound,info.coverage-info.bound];
    if info.ear, assert(info.coverage<=info.bound+1e-10); end
    component(6)=component(6)+toc(t);
end
assert(FE==total && all(P(:)>0) && all(P(:)<=total));
result=struct('label',label,'population_method',popMethod,'archive_method',archiveMethod, ...
    'seed',seed,'cycle_limit_s',p.cycle_limit_s,'N',N,'generations',generations,'FE',FE, ...
    'history_X',HX,'history_F',HF,'history_CV',HC,'history_G',HG,'population_ids',P,'archive_ids',A, ...
    'trace',trace,'selection_details',details,'component_seconds',component, ...
    'component_labels',{{'initialization','objective','variation','selection','archive','logging'}}, ...
    'compute_seconds',toc(wall),'config',rmfield(p,{'catalog','root'}));
end

function row=trace_row(g,fe,ids,a,X,F,CV,p)
ok=ids(CV(ids)==0);
row=[g,fe,bs_hv(F(ok,:),p),numel(ok)/numel(ids),size(unique(X(ids,:),'rows'),1), ...
    numel(unique(X(ok,1))),numel(unique(X(a,1)))];
end
