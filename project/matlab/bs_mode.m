function result=bs_mode(name,seed,N,generations,p)
% Research reference implementations with explicit mixed-category operators.
% Same initial population, budget and candidate domain across all methods.
rng(seed,'twister'); cats=mod((0:N-1)',height(p.catalog))+1; cats=cats(randperm(N));
X=[cats,p.lower'+rand(N,3).*(p.upper-p.lower)'];
[F,CV]=bs_evaluate(X,p); FE=N; rng(seed+100000,'twister'); start=tic;
strat=endsWith(name,'-S'); useEar=contains(name,'EAR');
isGA=startsWith(name,'MV-'); isSpea=strcmp(name,'MV-SPEA2');
if isGA, matingFitness=bs_ga_fitness(F,CV,isSpea); end
method='cd'; if useEar, method='ear'; end; if isSpea, method='spea'; end
[AX,AF]=bs_archive(X(CV==0,:),F(CV==0,:),N,strat);
trace=zeros(generations+1,7); trace(1,:)=trace_row(0,FE,X,F,CV,AX,p);
fallback=0; applied=0; boundExcess=0;
for gen=1:generations
    if isGA
        Y=ga_children(X,matingFitness,p);
    else
        Y=de_children(X,AX,p);
    end
    [FY,CY]=bs_evaluate(Y,p); FE=FE+N;
    [AX,AF]=bs_archive([AX;Y(CY==0,:)],[AF;FY(CY==0,:)],N,strat);
    [id,info]=bs_select([F;FY],[CV;CY],N,method);
    U=[X;Y]; FF=[F;FY]; CC=[CV;CY]; X=U(id,:); F=FF(id,:); CV=CC(id);
    if isGA, allFitness=bs_ga_fitness(FF,CC,isSpea); matingFitness=allFitness(id,:); end
    if info.ear
        applied=applied+1; fallback=fallback+info.fallback;
        boundExcess=max(boundExcess,info.coverage-info.bound);
    end
    trace(gen+1,:)=trace_row(gen,FE,X,F,CV,AX,p);
end
assert(FE==N*(generations+1));
result=struct('method',name,'seed',seed,'N',N,'generations',generations,'FE',FE, ...
    'seconds',toc(start),'X',X,'F',F,'CV',CV,'trace',trace,'ear_calls',applied, ...
    'ear_fallbacks',fallback,'max_coverage_excess',boundExcess,'config',rmfield(p,{'catalog','root'}));
end

function Y=de_children(X,AX,p)
n=size(X,1); Z=(X(:,2:4)-p.lower')./(p.upper-p.lower)';
if isempty(AX), AX=X; end
guide=AX(randi(size(AX,1),n,1),:); Q=(guide(:,2:4)-p.lower')./(p.upper-p.lower)';
V=Z;
for i=1:n
    other=[1:i-1,i+1:n]; rr=other(randperm(n-1,3));
    if rand<.5, v=Z(rr(1),:)+.5*(Z(rr(2),:)-Z(rr(3),:));
    else, v=Z(i,:)+.5*(Q(i,:)-Z(i,:))+.5*(Z(rr(1),:)-Z(rr(2),:)); end
    mask=rand(1,3)<.9; mask(randi(3))=true; V(i,mask)=v(mask);
end
lo=V<0; hi=V>1; V(lo)=Z(lo)/2; V(hi)=(1+Z(hi))/2;
cat=X(:,1); cr=rand(n,1); mask=cr<.1; cat(mask)=randi(height(p.catalog),sum(mask),1);
mask=cr>=.1 & cr<.5; cat(mask)=guide(mask,1);
Y=[cat,p.lower'+V.*(p.upper-p.lower)'];
end

function Y=ga_children(X,fitness,p)
n=size(X,1);
parents=zeros(n,1);
for i=1:n
    pair=randi(n,2,1); [~,o]=sortrows(fitness(pair,:),[1 2 3 4]); parents(i)=pair(o(1));
end
Z=(X(parents,2:4)-p.lower')./(p.upper-p.lower)'; cat=X(parents,1);
for i=1:2:n-1
    for j=1:3
        a=Z(i,j); b=Z(i+1,j);
        if rand>.5 || abs(a-b)<1e-14, continue; end
        y1=min(a,b); y2=max(a,b); rv=rand; eta=20;
        beta=1+2*y1/(y2-y1); alpha=2-beta^(-eta-1);
        if rv<=1/alpha, bq=(rv*alpha)^(1/(eta+1)); else, bq=(1/(2-rv*alpha))^(1/(eta+1)); end
        c1=.5*((y1+y2)-bq*(y2-y1));
        beta=1+2*(1-y2)/(y2-y1); alpha=2-beta^(-eta-1);
        if rv<=1/alpha, bq=(rv*alpha)^(1/(eta+1)); else, bq=(1/(2-rv*alpha))^(1/(eta+1)); end
        c2=.5*((y1+y2)+bq*(y2-y1));
        if rand<.5, Z(i,j)=c1; Z(i+1,j)=c2; else, Z(i,j)=c2; Z(i+1,j)=c1; end
    end
    if rand<.5, cat([i i+1])=cat([i+1 i]); end
end
for i=1:n
    for j=1:3
        if rand>1/3, continue; end
        y=Z(i,j); rv=rand; eta=20;
        if rv<=.5, delta=(2*rv+(1-2*rv)*(1-y)^(eta+1))^(1/(eta+1))-1;
        else, delta=1-(2*(1-rv)+2*(rv-.5)*y^(eta+1))^(1/(eta+1)); end
        Z(i,j)=min(1,max(0,y+delta));
    end
    if rand<.1, cat(i)=randi(height(p.catalog)); end
end
Y=[cat,p.lower'+Z.*(p.upper-p.lower)'];
end

function row=trace_row(g,fe,X,F,CV,AX,p)
ok=CV==0; ff=F(ok,:); hv=0;
if ~isempty(ff)
    zz=[(ff(:,1)-p.lower(1))/(p.upper(1)-p.lower(1)),ff(:,2)];
    zz=zz(all(zz<[1.1,1.1],2),:);
    if ~isempty(zz), zz=zz(ec_nd_indices(zz),:); prev=1.1; for j=1:size(zz,1), hv=hv+(1.1-zz(j,1))*(prev-zz(j,2)); prev=zz(j,2); end; end
end
row=[g,fe,hv,mean(ok),size(unique(X,'rows'),1),numel(unique(X(ok,1))),numel(unique(AX(:,1)))];
end
