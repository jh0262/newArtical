classdef P4Core
    % Shared, self-contained corrected multiobjective experiment implementation.
    % All decision operators work on [0,1]^D. See PROTOCOL.md for definitions.
    methods (Static)
        function c = config(overrides)
            c = struct('N',100,'G',250,'archiveSize',100,'seed',1, ...
                'usePado',true,'useLock',true,'useEC',true,'rho',1e-6, ...
                'window',5,'hvTolerance',1e-4,'pulse',0.05,'lowVarianceRatio',0.1, ...
                'sigmaStart',0.15,'sigmaEnd',0.01,'attraction',0.5, ...
                'sbxIndex',20,'mutationIndex',20,'crossoverProbability',0.9, ...
                'neighborhood',20,'inertia',0.4,'acceleration',1.5, ...
                'velocityLimit',0.2,'saveEvaluations',true, ...
                'mechanism','legacy','adaptiveStep',true,'localGuide',true, ...
                'differentialGain',0.5,'principalGain',0.3,'sparseRate',0.9, ...
                'rankParents',false,'randomGain',false,'progressLock',true,'pulseFraction',.1,'areaMode','onepass','pulseDirection','low','pulseTrigger','double');
            if nargin > 0
                names = fieldnames(overrides);
                for i=1:numel(names)
                    assert(isfield(c,names{i}),'PACPO:UnknownOption','Unknown option %s',names{i});
                    c.(names{i})=overrides.(names{i});
                end
            end
            validateattributes(c.N,{'numeric'},{'scalar','integer','>=',4});
            validateattributes(c.G,{'numeric'},{'scalar','integer','positive'});
            validateattributes(c.rho,{'numeric'},{'scalar','>=',0,'<=',1});
            validateattributes(c.window,{'numeric'},{'scalar','integer','positive'});
            assert(c.archiveSize>=3 && c.archiveSize<=c.N,'PACPO:ArchiveSize','Invalid archive size');
        end

        function p = problem(name)
            if strcmpi(name,'PPAR')
                p=struct('name','PPAR','D',4,'M',3,'lb',[200,600,800,100], ...
                    'ub',[600,1000,1200,400],'lower',[-8e6,0,-1], ...
                    'scale',[8e6,2,1],'ref',1.1*ones(1,3),'pf',zeros(0,3));
                p.model=PPaPaRModel.config(32768); return;
            end
            p.name=char(name);
            switch upper(p.name)
                case {'ZDT1','ZDT2','ZDT3'}
                    p.D=30; p.M=2; p.lb=zeros(1,30); p.ub=ones(1,30);
                case {'ZDT4','ZDT6'}
                    p.D=10; p.M=2; p.lb=zeros(1,10); p.ub=ones(1,10);
                    if strcmpi(name,'ZDT4'), p.lb(2:end)=-5; p.ub(2:end)=5; end
                case 'DTLZ1'
                    p.D=7; p.M=3; p.lb=zeros(1,7); p.ub=ones(1,7);
                case {'DTLZ2','DTLZ3'}
                    p.D=12; p.M=3; p.lb=zeros(1,12); p.ub=ones(1,12);
                case 'ENGINEERING'
                    p.D=4; p.M=3; p.lb=100*ones(1,4); p.ub=800*ones(1,4);
                otherwise
                    error('PACPO:Problem','Unknown problem %s',name);
            end
            p.lower=zeros(1,p.M); p.scale=ones(1,p.M);
            p.ref=1.1*ones(1,p.M);
            switch upper(p.name)
                case 'ZDT3'
                    p.lower=[0,-0.773369012326640];
                    p.scale=[1,1.773369012326640];
                    intervals=[0,.0830015349;.1822287280,.2577623634; ...
                        .4093136748,.4538821041;.6183967944,.6525117038; ...
                        .8233317983,.8518328654];
                    t=reshape(intervals(:,1)+(intervals(:,2)-intervals(:,1))*linspace(0,1,400),[],1);
                    p.pf=[t,1-sqrt(t)-t.*sin(10*pi*t)];
                    % Rounded interval endpoints can contain mutually dominated boundary duplicates.
                    p.pf=p.pf(~any(P4Core.dominance(p.pf,zeros(size(p.pf,1),1)),1)',:);
                case {'ZDT1','ZDT4'}
                    t=linspace(0,1,2001)'; p.pf=[t,1-sqrt(t)];
                case 'ZDT2'
                    t=linspace(0,1,2001)'; p.pf=[t,1-t.^2];
                case 'ZDT6'
                    t=linspace(0.2807753191,1,2001)'; p.pf=[t,1-t.^2];
                case {'DTLZ1','DTLZ2','DTLZ3'}
                    w=P4Core.simplex(60);
                    if strcmpi(name,'DTLZ1')
                        p.pf=.5*w; p.scale=.5*ones(1,3);
                    else
                        p.pf=w./sqrt(sum(w.^2,2));
                    end
                case 'ENGINEERING'
                    p.lower=[-512000,.09,-.88];
                    p.scale=[512000,1.01,.46]; p.pf=zeros(0,3);
            end
        end

        function w = simplex(h)
            w=zeros((h+1)*(h+2)/2,3); k=0;
            for i=0:h
                for j=0:h-i
                    k=k+1; w(k,:)=[i,j,h-i-j]/h;
                end
            end
        end

        function [f,cv,g] = evaluate(p,x)
            if P4Tape.active(),[f,cv,g]=P4Tape.take(p,x);return;end
            if strcmpi(p.name,'PPAR')
                [f,cv,g]=PPaPaRModel.evaluate(x,p.model); return;
            end
            n=size(x,1); g=zeros(n,0); cv=zeros(n,1);
            switch upper(p.name)
                case {'ZDT1','ZDT2','ZDT3','ZDT4','ZDT6'}
                    f1=x(:,1);
                    switch upper(p.name)
                        case 'ZDT4'
                            q=1+10*(p.D-1)+sum(x(:,2:end).^2-10*cos(4*pi*x(:,2:end)),2);
                        case 'ZDT6'
                            f1=1-exp(-4*f1).*sin(6*pi*f1).^6;
                            q=1+9*mean(x(:,2:end),2).^0.25;
                        otherwise
                            q=1+9*mean(x(:,2:end),2);
                    end
                    if ismember(upper(p.name),{'ZDT2','ZDT6'})
                        f2=q.*(1-(f1./q).^2);
                    else
                        f2=q.*(1-sqrt(f1./q));
                        if strcmpi(p.name,'ZDT3'), f2=f2-f1.*sin(10*pi*f1); end
                    end
                    f=[f1,f2];
                case {'DTLZ1','DTLZ2','DTLZ3'}
                    t=x(:,3:end)-.5;
                    if strcmpi(p.name,'DTLZ2')
                        q=sum(t.^2,2);
                    else
                        q=100*(p.D-2+sum(t.^2-cos(20*pi*t),2));
                    end
                    if strcmpi(p.name,'DTLZ1')
                        f=.5*(1+q).*[x(:,1).*x(:,2),x(:,1).*(1-x(:,2)),1-x(:,1)];
                    else
                        a=x(:,1)*pi/2; b=x(:,2)*pi/2;
                        f=(1+q).*[cos(a).*cos(b),cos(a).*sin(b),sin(a)];
                    end
                case 'ENGINEERING'
                    a=x(:,1); b=x(:,2); c=x(:,3); d=x(:,4); L=mean(x,2);
                    volume=.001*L.^3.*(1-.25*abs(a-b)./L);
                    err=.04*(a/100).^1.25+.035*(b/100).^1.15+.015*(c+d)/200;
                    dex=.42+.46*sin(pi*b./(a+b+1e-5)).*exp(-.08*abs(c-d)/100);
                    f=[-volume,err,-dex];
                    g=[sqrt((c-d).^2+100^2)-(a+b),a+2*b-(2*c+d+250),b-(a+c+d+100)];
                    cv=sum(max(g,0),2)/700;
            end
            assert(all(isfinite(f),'all') && all(isfinite(cv)),'PACPO:Nonfinite','Nonfinite objective');
        end

        function [y,repaired] = repair(p,y)
            y=max(0,min(1,y)); repaired=false(size(y,1),1);
            if strcmpi(p.name,'ENGINEERING')
                x=p.lb+y.*(p.ub-p.lb); t=mean(x(:,3:4),2);
                repaired=100<=x(:,1)+x(:,2) & x(:,1)+2*x(:,2)<=3*t+250 & x(:,2)<=x(:,1)+2*t+100;
                y(repaired,3:4)=repmat((t(repaired)-100)/700,1,2);
            end
        end

        function f = normalize(p,f)
            f=(f-p.lower)./p.scale;
        end

        function dom = dominance(f,cv)
            n=size(f,1); le=true(n); lt=false(n);
            for m=1:size(f,2)
                le=le & f(:,m)<=f(:,m)'; lt=lt | f(:,m)<f(:,m)';
            end
            dom=(cv<cv') | ((cv==cv') & le & lt);
        end

        function rank = ranks(f,cv)
            dom=P4Core.dominance(f,cv); counts=sum(dom,1)';
            rank=inf(size(cv)); level=0;
            while any(isinf(rank))
                level=level+1; front=find(counts==0 & isinf(rank));
                assert(~isempty(front),'PACPO:Sort','Dominance cycle');
                rank(front)=level; counts=counts-sum(dom(front,:),1)';
            end
        end

        function cd = crowding(f)
            n=size(f,1); cd=zeros(n,1);
            if n<=2, cd(:)=inf; return; end
            for j=1:size(f,2)
                [v,k]=sort(f(:,j)); span=v(end)-v(1);
                if span>0
                    cd(k([1,end]))=inf;
                    cd(k(2:end-1))=cd(k(2:end-1))+(v(3:end)-v(1:end-2))/span;
                end
            end
        end

        function [keep,rank,cd] = select(f,cv,n)
            rank=P4Core.ranks(f,cv); cd=zeros(size(cv));
            for j=1:max(rank), k=find(rank==j); cd(k)=P4Core.crowding(f(k,:)); end
            [~,order]=sortrows([rank,-cd,(1:numel(cv))'],[1,2,3]);
            keep=order(1:min(n,numel(order)));
        end

        function keep = areaPrune(f,n,mode)
            if nargin>=3 && strcmp(mode,'progressive')
                [~,order]=sortrows(f,[1,2]); q=f(order,:); ids=(1:size(q,1))';
                while numel(ids)>n
                    a=q(ids(1:end-2),:);b=q(ids(2:end-1),:);c=q(ids(3:end),:);
                    area=abs((b(:,1)-a(:,1)).*(c(:,2)-a(:,2))-(b(:,2)-a(:,2)).*(c(:,1)-a(:,1)))/2;
                    tolerance=64*eps(max(1,max(area)));
                    tied=find(area<=min(area)+tolerance);
                    span=max(max(q)-min(q),1e-12);
                    gap=sum(abs((c(tied,:)-a(tied,:))./span),2);
                    [~,j]=min(gap); ids(tied(j)+1)=[];
                end
                keep=order(ids);return;
            end
            [~,order]=sort(f(:,1)); q=f(order,:); count=size(q,1);
            s=inf(count,1);
            if count>2
                s(2:end-1)=abs((q(2:end-1,1)-q(1:end-2,1)).*(q(3:end,2)-q(1:end-2,2)) ...
                    -(q(2:end-1,2)-q(1:end-2,2)).*(q(3:end,1)-q(1:end-2,1)))/2;
            end
            [~,k]=sortrows([-s,(1:count)'],[1,2]); keep=order(k(1:n));
        end

        function a = archive(p,a,new,c)
            z=[a;new];
            f=z(:,p.D+1:p.D+p.M); cv=z(:,end-1);
            z=z(~any(P4Core.dominance(f,cv),1)',:);
            % Equal objective vectors can have different constraint violations.
            % Apply feasibility dominance before selecting a unique representative.
            [~,uniqueRows]=unique(z(:,p.D+1:p.D+p.M),'rows','stable'); z=z(uniqueRows,:);
            if size(z,1)>c.archiveSize
                f=P4Core.normalize(p,z(:,p.D+1:p.D+p.M));
                if c.useEC && p.M==2
                    keep=P4Core.areaPrune(f,c.archiveSize,c.areaMode);
                else
                    cd=P4Core.crowding(f); [~,keep]=sort(cd,'descend'); keep=keep(1:c.archiveSize);
                end
                z=z(keep,:);
            end
            a=z;
        end

        function value = hv(f,ref)
            f=f(all(isfinite(f),2) & all(f<ref,2),:);
            if isempty(f), value=0; return; end
            if size(f,2)==2
                [~,idx]=sort(f(:,1)); f=f(idx,:);
                level=cummin([ref(2);f(:,2)]);
                value=sum((ref(1)-f(:,1)).*(level(1:end-1)-level(2:end)));
            elseif size(f,2)==3
                [~,idx]=sort(f(:,1)); f=f(idx,:); value=0;
                for i=1:size(f,1)
                    if i<size(f,1), right=f(i+1,1); else, right=ref(1); end
                    if right>f(i,1), value=value+(right-f(i,1))*P4Core.hv(f(1:i,2:3),ref(2:3)); end
                end
            else
                error('PACPO:HVDimension','Exact HV supports two or three objectives');
            end
        end

        function [igd,hv,spacing] = metrics(p,f)
            if isempty(f), igd=inf; hv=0; spacing=NaN; return; end
            f=P4Core.normalize(p,f); hv=P4Core.hv(f,p.ref)/prod(p.ref);
            if isempty(p.pf), igd=NaN; else
                q=P4Core.normalize(p,p.pf); igd=mean(min(pdist2(q,f),[],2));
            end
            if size(f,1)<2, spacing=NaN; else
                distance=pdist2(f,f,'cityblock'); distance(1:size(f,1)+1:end)=inf;
                spacing=std(min(distance,[],2));
            end
        end

        function [V,s,P,lambda] = principal(y,c)
            d=size(y,2);
            if size(y,1)<2, C=zeros(d); else, C=cov(y); end
            C=(C+C')/2; [V,L]=eig(C,'vector');
            [lambda,k]=sort(max(L,0),'descend'); V=V(:,k);
            mu=mean(lambda); reg=(1-c.rho)*lambda+c.rho*max(mu,1e-12);
            s=sqrt(max(reg,1e-16)/max(mean(reg),1e-16));
            s=min(2,max(.25,s)); s=s/sqrt(mean(s.^2));
            low=lambda<=c.lowVarianceRatio*max(mu,1e-12);
            P=V(:,low)*V(:,low)';
        end

        function child = variation(a,b,c)
            % Bounded simulated binary crossover, then polynomial mutation.
            [n,d]=size(a); lo=min(a,b); hi=max(a,b); diff=hi-lo;
            u=rand(n,d); eta=c.sbxIndex;
            beta=1+2*lo./max(diff,eps); alpha=2-beta.^(-eta-1);
            q=(u.*alpha).^(1/(eta+1)); k=u>1./alpha;
            q(k)=(1./(2-u(k).*alpha(k))).^(1/(eta+1));
            left=.5*(lo+hi-q.*diff);
            beta=1+2*(1-hi)./max(diff,eps); alpha=2-beta.^(-eta-1);
            q=(u.*alpha).^(1/(eta+1)); k=u>1./alpha;
            q(k)=(1./(2-u(k).*alpha(k))).^(1/(eta+1));
            right=.5*(lo+hi+q.*diff);
            child=left; k=rand(n,d)<.5; child(k)=right(k);
            active=rand(n,1)<c.crossoverProbability & rand(n,d)<.5 & diff>1e-14;
            child(~active)=a(~active);
            child=P4Core.mutate(max(0,min(1,child)),c.mutationIndex);
        end

        function y = mutate(y,eta)
            u=rand(size(y)); active=rand(size(y))<1/size(y,2);
            left=active & u<=.5; right=active & ~left;
            v=2*u(left)+(1-2*u(left)).*(1-y(left)).^(eta+1);
            y(left)=y(left)+v.^(1/(eta+1))-1;
            v=2*(1-u(right))+2*(u(right)-.5).*y(right).^(eta+1);
            y(right)=y(right)+1-v.^(1/(eta+1)); y=max(0,min(1,y));
        end

        function ids = tournament(rank,cd,n)
            a=randi(numel(rank),n,1); b=randi(numel(rank),n,1); ids=a;
            use=rank(b)<rank(a) | (rank(b)==rank(a) & cd(b)>cd(a)); ids(use)=b(use);
        end

        function w = weights(n,m)
            if m==2, t=linspace(0,1,n)'; w=[t,1-t]; return; end
            h=ceil((sqrt(8*n+1)-3)/2); q=P4Core.simplex(h);
            picked=zeros(n,1); [~,picked(1)]=max(q(:,1)); distance=inf(size(q,1),1);
            for i=2:n
                distance=min(distance,sum((q-q(picked(i-1),:)).^2,2)); distance(picked(1:i-1))=-inf;
                [~,picked(i)]=max(distance);
            end
            w=q(picked,:);
        end

        function ids = gridLeaders(f,n)
            lo=min(f,[],1); span=max(max(f,[],1)-lo,1e-12);
            cellIndex=min(9,floor(10*(f-lo)./span));
            [~,~,group]=unique(cellIndex,'rows'); occupancy=accumarray(group,1);
            % Cell probability proportional to inverse occupancy; uniform within cell.
            mass=1./occupancy(group).^2; cumulative=cumsum(mass/sum(mass));
            u=rand(n,1); ids=sum(u>cumulative',2)+1;
        end

        function result = solve(p,algorithm,c)
            c=P4Core.config(c); previous=rng; restore=onCleanup(@()rng(previous));
            if ~strcmp(algorithm,'PACPO')
                c.usePado=false; c.useLock=false; c.useEC=false;
            end
            rng(c.seed,'twister'); timer=tic; n=c.N; d=p.D; m=p.M;
            raw=zeros(n*(c.G+1),d+m+2); % normalized x, raw f, CV, evaluation ID
            [y,changed]=P4Core.repair(p,rand(n,d));
            [f,cv]=P4Core.evaluate(p,p.lb+y.*(p.ub-p.lb));
            pop=[y,f,cv,(1:n)']; raw(1:n,:)=pop; used=n;
            archive=P4Core.archive(p,zeros(0,d+m+2),pop,c);
            velocity=zeros(n,d); personal=pop;
            if strcmp(algorithm,'MOEAD')
                weights=max(P4Core.weights(n,m),1e-6); distance=pdist2(weights,weights);
                [~,neighbors]=sort(distance,2); neighbors=neighbors(:,1:min(c.neighborhood,n));
                ideal=min(P4Core.normalize(p,f),[],1);
            end
            history=zeros(c.G+1,9); stagnation=0;
            gateTrace=zeros(c.G,7); operatorTrace=zeros(c.G,13); diagnostic=zeros(c.G,8); state=struct('sigma',1,'success',.2);pulseEvents=zeros(0,6);
            good=archive(:,end-1)==0;
            oldHV=P4Core.hv(P4Core.normalize(p,archive(good,d+1:d+m)),p.ref)/prod(p.ref);
            history(1,:)=[0,n,oldHV,0,0,sum(changed),sum(good),0,0];
            for gen=1:c.G
                pulseApplied=false; lowDimension=0; ecUsed=false;
                parent=pop; preBoundary=0;
                if strcmp(algorithm,'MOEAD')
                    batch=zeros(n,d+m+2);
                    repairCount=0;
                    order=randperm(n);
                    for j=1:n
                        i=order(j); pool=neighbors(i,:); pair=pool(randperm(numel(pool),2));
                        child=P4Core.variation(pop(pair(1),1:d),pop(pair(2),1:d),c);
                        preBoundary=mean(child<0 | child>1,'all');
                    [child,changed]=P4Core.repair(p,child);
                        repairCount=repairCount+sum(changed);
                        [fc,cc]=P4Core.evaluate(p,p.lb+child.*(p.ub-p.lb));
                        row=[child,fc,cc,used+j]; batch(j,:)=row;
                        nf=P4Core.normalize(p,fc); ideal=min(ideal,nf);
                        current=P4Core.normalize(p,pop(pool,d+1:d+m));
                        oldScore=max(weights(pool,:).*abs(current-ideal),[],2);
                        newScore=max(weights(pool,:).*abs(nf-ideal),[],2);
                        replace=cc<pop(pool,end-1) | (cc==pop(pool,end-1) & newScore<=oldScore);
                        pop(pool(replace),:)=repmat(row,sum(replace),1);
                    end
                else
                    switch algorithm
                        case 'PACPO'
                            if strcmp(c.mechanism,'legacy')
                            [V,s,P,lambda]=P4Core.principal(archive(:,1:d),c);
                            leader=archive(randi(size(archive,1),n,1),1:d);
                            noise=randn(n,d);
                            if c.usePado, noise=(noise.*s')*V'; end
                            sigma=c.sigmaStart+(c.sigmaEnd-c.sigmaStart)*(gen-1)/max(c.G-1,1);
                            child=pop(:,1:d)+c.attraction*(leader-pop(:,1:d))+sigma*noise;
                            if c.useLock && stagnation>=c.window
                                lowDimension=sum(lambda<=c.lowVarianceRatio*max(mean(lambda),1e-12));
                                if lowDimension>0
                                    child=child+c.pulse*(randn(n,d)*P); pulseApplied=true;
                                end
                                stagnation=0;
                            end
                            else
                                [child,state,pulseApplied,lowDimension]=P4Mechanism.propose(p,pop,archive,c,state,gen,stagnation);
                                parent=pop(state.parentRows,:);
                                operatorTrace(gen,:)=state.components; gateTrace(gen,:)=state.gates;
                                if pulseApplied, stagnation=0; end
                            end
                        case 'NSGAII'
                            [~,rank,cd]=P4Core.select(pop(:,d+1:d+m),pop(:,end-1),n);
                            a=P4Core.tournament(rank,cd,n); b=P4Core.tournament(rank,cd,n);
                            child=P4Core.variation(pop(a,1:d),pop(b,1:d),c);
                        case 'MOPSO'
                            lead=P4Core.gridLeaders(archive(:,d+1:d+m),n);
                            velocity=c.inertia*velocity+c.acceleration*rand(n,d).*(personal(:,1:d)-pop(:,1:d)) ...
                                +c.acceleration*rand(n,d).*(archive(lead,1:d)-pop(:,1:d));
                            velocity=max(-c.velocityLimit,min(c.velocityLimit,velocity));
                            child=pop(:,1:d)+velocity;
                            hit=child<0 | child>1; velocity(hit)=-velocity(hit);
                            child=P4Core.mutate(max(0,min(1,child)),c.mutationIndex);
                        otherwise
                            error('PACPO:Algorithm','Unknown algorithm %s',algorithm);
                    end
                    preBoundary=mean(child<0 | child>1,'all');
                    [child,changed]=P4Core.repair(p,child);
                    repairCount=sum(changed);
                    [fc,cc]=P4Core.evaluate(p,p.lb+child.*(p.ub-p.lb));
                    batch=[child,fc,cc,(used+1:used+n)'];
                    if strcmp(algorithm,'MOPSO')
                        better=cc<personal(:,end-1) | (cc==personal(:,end-1) & all(fc<=personal(:,d+1:d+m),2) & any(fc<personal(:,d+1:d+m),2));
                        worse=personal(:,end-1)<cc | (cc==personal(:,end-1) & all(personal(:,d+1:d+m)<=fc,2) & any(personal(:,d+1:d+m)<fc,2));
                        replace=better | (~worse & rand(n,1)<.5); personal(replace,:)=batch(replace,:); pop=batch;
                    else
                        joined=[pop;batch]; k=P4Core.select(joined(:,d+1:d+m),joined(:,end-1),n); pop=joined(k,:);
                    end
                end
                survived=mean(ismember(batch(:,end),pop(:,end)));
                strict=batch(:,end-1)<parent(:,end-1) | (batch(:,end-1)==parent(:,end-1) & all(batch(:,d+1:d+m)<=parent(:,d+1:d+m),2) & any(batch(:,d+1:d+m)<parent(:,d+1:d+m),2));
                stepRMS=sqrt(mean(sum((batch(:,1:d)-parent(:,1:d)).^2,2)));
                if strcmp(algorithm,'PACPO') && ~strcmp(c.mechanism,'legacy')
                    state.success=.9*state.success+.1*mean(strict);
                    if c.adaptiveStep, state.sigma=min(2,max(.02,state.sigma*exp(.2*(state.success-.2)))); end
                end
                raw(used+1:used+n,:)=batch; used=used+n;
                if c.useEC && m==2
                    joined=[archive;batch]; fcheck=joined(:,d+1:d+m);
                    [~,uniq]=unique(fcheck,'rows','stable'); joined=joined(uniq,:);
                    ecUsed=sum(~any(P4Core.dominance(joined(:,d+1:d+m),joined(:,end-1)),1))>c.archiveSize;
                end
                archive=P4Core.archive(p,archive,batch,c); good=archive(:,end-1)==0;
                hv=P4Core.hv(P4Core.normalize(p,archive(good,d+1:d+m)),p.ref)/prod(p.ref);
                if abs(hv-oldHV)<c.hvTolerance, stagnation=stagnation+1; else, stagnation=0; end
                entered=mean(ismember(batch(:,end),archive(:,end)));
                if strcmp(algorithm,'PACPO') && ~strcmp(c.mechanism,'legacy')
                    preBoundary=state.preBoundary;
                    if c.progressLock && mean(strict)>.02, stagnation=0; end
                end
                if pulseApplied && isfield(state,'pulseRows')
                    ids=state.pulseRows;
                    pulseEvents(end+1,:)=[gen,numel(ids),sum(strict(ids)),sum(ismember(batch(ids,end),archive(:,end))),hv-oldHV,lowDimension]; %#ok<AGROW>
                end
                if size(archive,1)<2, varianceTrace=0; else, varianceTrace=trace(cov(archive(:,1:d))); end
                diagnostic(gen,:)=[mean(strict),survived,entered,preBoundary,stepRMS,varianceTrace,state.sigma,hv-oldHV];
                oldHV=hv;
                history(gen+1,:)=[gen,used,hv,pulseApplied,lowDimension,repairCount,sum(good),ecUsed,stagnation];
            end
            [igd,hv,spacing]=P4Core.metrics(p,archive(good,d+1:d+m));
            result=struct('problem',p.name,'algorithm',algorithm,'config',c,'seed',c.seed, ...
                'archive',archive,'population',pop,'history',history,'FE',used, ...
                'IGD',igd,'HV',hv,'Spacing',spacing,'elapsed',toc(timer));
            result.gateTrace=gateTrace;result.gateColumns={'hvEligible','lowEligible','lowDimension','effectiveDimension','pulseApplied','pulseNormBefore','pulseNormAfter'}; result.operatorTrace=operatorTrace;
            result.operatorColumns={'guidePre','differencePre','noisePre','guideMasked','differenceMasked','noiseMasked','combinedMasked','pulse','clipping','mutation','finalStep','maskFraction','sigmaBefore'};
            result.diagnostic=diagnostic;
            result.pulseEvents=pulseEvents;
            result.pulseEventColumns={'generation','perturbedCount','strictImproved','archiveEntered','deltaHV','lowDimension'};
            result.diagnosticColumns={'parentDominanceRate','survivalRate','archiveEntryRate','boundaryFraction','stepRMS','archiveVariance','sigmaFactor','deltaHV'};
            result.historyColumns={'generation','FE','normalizedHV','pulseApplied','lowVarianceDimension', ...
                'repairedCount','feasibleArchiveCount','areaPruningUsed','stagnationCount'};
            result.X=p.lb+archive(:,1:d).*(p.ub-p.lb); result.F=archive(:,d+1:d+m);
            result.CV=archive(:,end-1); result.archiveIDs=archive(:,end);
            if c.saveEvaluations, result.evaluations=raw; end
            assert(used==n*(c.G+1),'PACPO:Budget','Evaluation budget mismatch');
        end

        function [score,order] = topsis(f,weights)
            % All supplied objectives are minimized. Vector-normalized TOPSIS.
            weights=weights/sum(weights); denom=sqrt(sum(f.^2,1)); denom(denom==0)=1;
            z=(f./denom).*weights; positive=min(z,[],1); negative=max(z,[],1);
            dp=sqrt(sum((z-positive).^2,2)); dn=sqrt(sum((z-negative).^2,2));
            score=dn./max(dp+dn,eps); [~,order]=sort(score,'descend');
        end

        function adjusted = holm(p)
            p=p(:); [ordered,k]=sort(p); n=numel(p);
            corrected=min(1,cummax((n-(1:n)'+1).*ordered)); adjusted=zeros(n,1); adjusted(k)=corrected;
        end
    end
end
