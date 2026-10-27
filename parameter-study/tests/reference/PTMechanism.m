classdef PTMechanism
    methods (Static)
        function [child,state,pulsed,ld] = propose(p,pop,archive,c,state,~,stagnation)
            n=size(pop,1);d=p.D;m=p.M;a=archive(:,1:d);
            if c.rankParents
                [~,rank,cd]=PTCore.select(pop(:,d+1:d+m),pop(:,end-1),n);
                pr=PTCore.tournament(rank,cd,n);
            else
                pr=(1:n)';
            end
            state.parentRows=pr;x=pop(pr,1:d);
            [V,~,P,lambda]=PTCore.principal(a,c);
            if c.localGuide && ~strcmp(c.mechanism,'scale')
                f=[pop(:,d+1:d+m);archive(:,d+1:d+m)]; lo=min(f);span=max(max(f)-lo,1e-12);
                dist=pdist2((pop(pr,d+1:d+m)-lo)./span,(archive(:,d+1:d+m)-lo)./span);
                [~,near]=sort(dist,2); k=min(10,size(a,1));
                ix=sub2ind(size(near),(1:n)',randi(k,n,1));leader=a(near(ix),:);
            else
                leader=a(randi(size(a,1),n,1),:);
            end
            reg=(1-c.rho)*lambda+c.rho*max(mean(lambda),1e-12);
            if c.usePado, noise=(randn(n,d).*sqrt(max(reg,1e-14))')*V';
            else, noise=randn(n,d).*max(std(a,0,1),1e-7); end
            if strcmp(c.mechanism,'directional')
                r1=randi(n,n,1);r2=randi(n,n,1);
                bad=r1==pr | r2==pr | r2==r1;
                while any(bad),r1(bad)=randi(n,nnz(bad),1);r2(bad)=randi(n,nnz(bad),1);bad=r1==pr | r2==pr | r2==r1;end
                delta=pop(r1,1:d)-pop(r2,1:d);
                if c.randomGain,gain=max(.1,min(1,c.differentialGain+.2*randn(n,1)));else,gain=c.differentialGain;end
                child=x+gain.*(leader-x)+gain.*delta+c.principalGain*state.sigma*noise;
                mask=rand(n,d)<c.sparseRate;mask(sub2ind([n,d],(1:n)',randi(d,n,1)))=true;
                child(~mask)=x(~mask);
                gg=gain.*(leader-x);dd=gain.*delta;nn=c.principalGain*state.sigma*noise;
                rmsrow=@(v)sqrt(mean(sum(v.^2,2)));
                state.components=[rmsrow(gg),rmsrow(dd),rmsrow(nn),rmsrow(gg.*mask),rmsrow(dd.*mask),rmsrow(nn.*mask),rmsrow(child-x),0,0,0,0,mean(mask,'all'),state.sigma];
            else
                child=x+.5*(leader-x)+state.sigma*noise;
            end
            beforePulse=child;
            pulsed=false;ld=0;state.pulseRows=[];
            [step,rows,pulsed,ld,gates]=PTPulse.draw(V,P,lambda,c,state.sigma,stagnation,n,d);
            if pulsed,child(rows,:)=child(rows,:)+step;state.pulseRows=rows;end
            state.gates=gates;
            state.preBoundary=mean(child<0 | child>1,'all');
            afterPulse=child;clipped=max(0,min(1,child));
            child=PTCore.mutate(max(0,min(1,child)),c.mutationIndex);
            if strcmp(c.mechanism,'directional')
                state.components(8:11)=[rmsrow(afterPulse-beforePulse),rmsrow(clipped-afterPulse),rmsrow(child-clipped),rmsrow(child-x)];
            end
        end
    end
end
