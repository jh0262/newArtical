function result=bs_qmc(seed,N,generations,p)
rng(seed,'twister'); cats=mod((0:N-1)',height(p.catalog))+1; cats=cats(randperm(N));
X0=[cats,p.lower'+rand(N,3).*(p.upper-p.lower)'];
rng(seed+100000,'twister'); start=tic; FE=N*(generations+1); remain=FE-N;
cats=mod((0:remain-1)',height(p.catalog))+1; Y=zeros(remain,4); Y(:,1)=cats;
for c=1:height(p.catalog)
    ix=find(cats==c); seq=scramble(sobolset(3),'MatousekAffineOwen'); Z=net(seq,numel(ix));
    Y(ix,2:4)=p.lower'+Z.*(p.upper-p.lower)';
end
X=[X0;Y]; [F,CV]=bs_evaluate(X,p); trace=zeros(generations+1,7); keep=[];
for gen=0:generations
    ix=gen*N+(1:N); ix=ix(CV(ix)==0); keep=[keep;ix(:)]; %#ok<AGROW>
    if ~isempty(keep), keep=keep(ec_nd_indices(F(keep,:))); end
    if numel(keep)>N, short=keep(ec_cd_subset(F(keep,:),N)); else, short=keep; end
    trace(gen+1,:)=[gen,(gen+1)*N,bs_hv(F(short,:),p),mean(CV(1:(gen+1)*N)==0),numel(keep),numel(unique(X(keep,1))),numel(unique(X(keep,1)))];
end
[id,~]=bs_select(F,CV,N,'cd');
result=struct('method','CAT-QMC','seed',seed,'N',N,'generations',generations,'FE',FE,'seconds',toc(start), ...
    'X',X(id,:),'F',F(id,:),'CV',CV(id),'trace',trace,'ear_calls',0,'ear_fallbacks',0, ...
    'max_coverage_excess',0,'sample_feasible_fraction',mean(CV==0),'full_sample_X',X, ...
    'full_sample_F',F,'full_sample_CV',CV,'config',rmfield(p,{'catalog','root'}));
% Final population and trace HV must agree.
result.trace(end,3)=bs_hv(result.F(result.CV==0,:),p);
end
