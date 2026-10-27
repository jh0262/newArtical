classdef P1GDE3
    % Matrix adaptation of the public PlatEMO GDE3 architecture.
    % Kukkonen & Lampinen (CEC 2005); PlatEMO, Tian et al., IEEE CIM 2017.
    % PlatEMO copyright (c) BIMK Group: research use; cite PlatEMO.
    % Sources and explicit adaptations are recorded in sources/GDE3_SOURCE.md.
    methods (Static)
        function r=solve(p,c)
            saved=rng;restore=onCleanup(@()rng(saved));rng(c.seed,'twister');timer=tic;
            n=c.N;d=p.D;m=p.M; c.useEC=false;
            y=rand(n,d);[f,cv]=PACPOP1.evaluate(p,p.lb+y.*(p.ub-p.lb));
            pop=[y,f,cv,(1:n)'];raw=zeros(n*(c.G+1),d+m+2);raw(1:n,:)=pop;used=n;
            archive=PACPOP1.archive(p,zeros(0,d+m+2),pop,c);history=zeros(c.G+1,9);
            good=archive(:,end-1)==0;[~,hv]=PACPOP1.metrics(p,archive(good,d+1:d+m));history(1,:)=[0,n,hv,0,0,0,sum(good),0,0];
            for gen=1:c.G
                r2=randi(n,n,1);r3=randi(n,n,1);
                site=rand(n,d)<1;child=pop(:,1:d);delta=.5*(pop(r2,1:d)-pop(r3,1:d));child(site)=child(site)+delta(site);
                % Same bounded polynomial mutation distribution as OperatorDE.
                child=PACPOP1.mutate(max(0,min(1,child)),20);
                [f,cv]=PACPOP1.evaluate(p,p.lb+child.*(p.ub-p.lb));batch=[child,f,cv,(used+1:used+n)'];
                pop=P1GDE3.select(pop,batch,n,d,m);
                raw(used+1:used+n,:)=batch;used=used+n;
                archive=PACPOP1.archive(p,archive,batch,c);good=archive(:,end-1)==0;
                [~,hv]=PACPOP1.metrics(p,archive(good,d+1:d+m));history(gen+1,:)=[gen,used,hv,0,0,0,sum(good),0,0];
            end
            [igd,hv,sp]=PACPOP1.metrics(p,archive(good,d+1:d+m));
            r=struct('problem',p.name,'algorithm','GDE3','config',c,'seed',c.seed,'archive',archive,'population',pop, ...
                'history',history,'FE',used,'IGD',igd,'HV',hv,'Spacing',sp,'elapsed',toc(timer), ...
                'X',p.lb+archive(:,1:d).*(p.ub-p.lb),'F',archive(:,d+1:d+m),'CV',archive(:,end-1), ...
                'archiveIDs',archive(:,end),'evaluations',raw,'pulseEvents',zeros(0,6));
            assert(used==n*(c.G+1));
        end
        function pop=select(pop,child,n,d,m)
            a=pop(:,d+1:d+m);b=child(:,d+1:d+m);ca=pop(:,end-1);cb=child(:,end-1);
            replace=cb<ca | (cb==ca & all(b<=a,2));
            add=ca==0 & cb==0 & any(a<b,2)&any(a>b,2);
            pop(replace,:)=child(replace,:);pool=[pop;child(add,:)];
            rank=PACPOP1.ranks(pool(:,d+1:d+m),pool(:,end-1));last=1;
            while nnz(rank<=last)<n,last=last+1;end
            inside=find(rank<last);edge=find(rank==last);
            while numel(inside)+numel(edge)>n
                cd=PACPOP1.crowding(pool(edge,d+1:d+m));[~,k]=min(cd);edge(k)=[];
            end
            pop=pool([inside;edge],:);
        end
    end
end
