classdef TestSearchCore < matlab.unittest.TestCase
    properties (TestParameter)
        solver={'PACPO','NSGAII','MOEAD','MOPSO'};
        task={'ZDT1','ZDT2','ZDT3','DTLZ1','DTLZ2','ENGINEERING'};
    end
    methods (Test)
        function exactHV2D(t)
            t.verifyEqual(PACPOSearch.hv([.2,.8;.8,.2],[1,1]),.28,'AbsTol',1e-14);
        end
        function exactHV3D(t)
            t.verifyEqual(PACPOSearch.hv([.2,.8,.2;.8,.2,.2],[1,1,1]),.224,'AbsTol',1e-14);
        end
        function hvDuplicatesAndDominated(t)
            t.verifyEqual(PACPOSearch.hv([.2,.8,.2;.8,.2,.2;.2,.8,.2;.9,.9,.9],[1,1,1]),.224,'AbsTol',1e-14);
        end
        function hvMonotonic(t)
            t.verifyGreaterThan(PACPOSearch.hv([.2,.8,.2;.8,.2,.2],[1,1,1]),PACPOSearch.hv([.2,.8,.2],[1,1,1]));
        end
        function hvOutside(t)
            t.verifyEqual(PACPOSearch.hv([2,0,0],[1,1,1]),0);
        end
        function hvIndependentUnionOracle(t)
            f=[.1,.7,.3;.4,.2,.6;.6,.3,.2;.2,.5,.4;.7,.1,.5;.9,.8,.9];
            masks=logical(dec2bin(1:63,6)-'0');
            volumes=arrayfun(@(i)prod(1-max(f(masks(i,:),:),[],1)),(1:63)');
            exact=sum((-1).^(sum(masks,2)+1).*volumes);
            t.verifyEqual(PACPOSearch.hv(f,[1,1,1]),exact,'AbsTol',1e-13);
        end
        function correctFrontRanks(t)
            f=[0,4;1,3;2,2;3,1;4,0;3.1,3.1;.1,4.1;.2,4.2];
            t.verifyEqual(PACPOSearch.ranks(f,zeros(8,1)),[1;1;1;1;1;2;2;3]);
        end
        function feasibleDominatesInfeasible(t)
            t.verifyEqual(PACPOSearch.ranks([100,100;0,0],[0;1]),[1;2]);
        end
        function dtlz1Reference(t)
            p=PACPOSearch.problem('DTLZ1');
            t.verifyEqual(sum(p.pf,2),.5*ones(size(p.pf,1),1),'AbsTol',1e-14);
        end
        function dtlz2Reference(t)
            p=PACPOSearch.problem('DTLZ2');
            t.verifyEqual(sum(p.pf.^2,2),ones(size(p.pf,1),1),'AbsTol',1e-14);
        end
        function zdt3Reference(t)
            p=PACPOSearch.problem('ZDT3');
            t.verifyFalse(any(PACPOSearch.dominance(p.pf,zeros(size(p.pf,1),1)),'all'));
        end
        function referenceDeterministic(t)
            p=PACPOSearch.problem('DTLZ1'); q=PACPOSearch.problem('DTLZ1');
            t.verifyEqual(p.pf,q.pf);
        end
        function knownZDT1(t)
            p=PACPOSearch.problem('ZDT1'); x=zeros(1,p.D); x(1)=.25;
            t.verifyEqual(PACPOSearch.evaluate(p,x),[.25,.5],'AbsTol',1e-14);
        end
        function knownDTLZ1(t)
            p=PACPOSearch.problem('DTLZ1');
            t.verifyEqual(PACPOSearch.evaluate(p,.5*ones(1,7)),[.125,.125,.25],'AbsTol',1e-14);
        end
        function knownDTLZ2(t)
            p=PACPOSearch.problem('DTLZ2');
            t.verifyEqual(PACPOSearch.evaluate(p,.5*ones(1,12)),[.5,.5,sqrt(.5)],'AbsTol',1e-14);
        end
        function engineeringValues(t)
            p=PACPOSearch.problem('ENGINEERING');
            [f,cv]=PACPOSearch.evaluate(p,[217.28,232.12,698.49,694.07]);
            t.verifyEqual(f,[-96860.674096878,.302142142578525,-.877759808782089],'AbsTol',1e-8);
            t.verifyEqual(cv,0);
        end
        function engineeringDominanceRepair(t)
            p=PACPOSearch.problem('ENGINEERING'); x=[217.28,232.12,698.49,694.07];
            y=PACPOSearch.repair(p,(x-p.lb)./(p.ub-p.lb));
            [f,cv]=PACPOSearch.evaluate(p,p.lb+y.*(p.ub-p.lb)); before=PACPOSearch.evaluate(p,x);
            t.verifyEqual(f(1:2),before(1:2),'AbsTol',1e-8);
            t.verifyLessThan(f(3),before(3)); t.verifyEqual(cv,0);
        end
        function engineeringRepairPreservesUnbalancedFeasibility(t)
            p=PACPOSearch.problem('ENGINEERING'); x=[700,600,800,100]; y=(x-p.lb)./(p.ub-p.lb);
            [after,changed]=PACPOSearch.repair(p,y);
            t.verifyEqual(after,y); t.verifyFalse(changed);
        end
        function isotropicSpectralScale(t)
            c=PACPOSearch.config(); [~,s,~,lambda]=PACPOSearch.principal([1,0;-1,0;0,1;0,-1],c);
            t.verifyEqual(s,[1;1],'AbsTol',1e-14);
            t.verifyEqual(lambda(1),lambda(2),'AbsTol',1e-14);
        end
        function effectiveAnisotropy(t)
            c=PACPOSearch.config(); [V,s]=PACPOSearch.principal([1,0;-1,0;0,.1;0,-.1],c);
            covariance=V*diag(s.^2)*V';
            t.verifyGreaterThan(covariance(1,1)/covariance(2,2),10);
        end
        function collapsedArchiveIsFinite(t)
            [~,s,P]=PACPOSearch.principal(zeros(5,4),PACPOSearch.config());
            t.verifyEqual(s,ones(4,1),'AbsTol',1e-14); t.verifyEqual(P,eye(4),'AbsTol',1e-14);
        end
        function optionsComplete(t)
            c=PACPOSearch.config(struct('usePado',false));
            t.verifyEqual(c.hvTolerance,1e-4); t.verifyEqual(c.pulse,.05);
        end
        function optionsRejectTypo(t)
            t.verifyError(@()PACPOSearch.config(struct('eps_HV',1e-4)),'PACPO:UnknownOption');
        end
        function budgetAndFiniteResults(t,solver,task)
            c=PACPOSearch.config(struct('N',12,'archiveSize',12,'G',3,'seed',19));
            p=PACPOSearch.problem(task); r=PACPOSearch.solve(p,solver,c);
            t.verifyEqual(r.FE,48); t.verifySize(r.evaluations,[48,p.D+p.M+2]);
            t.verifyTrue(all(isfinite(r.F),'all')); t.verifyGreaterThanOrEqual(r.X,repmat(p.lb,size(r.X,1),1));
            t.verifyLessThanOrEqual(r.X,repmat(p.ub,size(r.X,1),1));
            t.verifyFalse(any(PACPOSearch.dominance(r.F,r.CV),'all'));
        end
        function reproducible(t)
            c=PACPOSearch.config(struct('N',12,'archiveSize',12,'G',3,'seed',19)); p=PACPOSearch.problem('ZDT1');
            a=PACPOSearch.solve(p,'PACPO',c); b=PACPOSearch.solve(p,'PACPO',c);
            t.verifyEqual(a.evaluations,b.evaluations);
        end
        function threeDimensionalECIsInactive(t)
            c=PACPOSearch.config(struct('N',12,'archiveSize',12,'G',3,'seed',19)); p=PACPOSearch.problem('DTLZ2');
            a=PACPOSearch.solve(p,'PACPO',c); c.useEC=false; b=PACPOSearch.solve(p,'PACPO',c);
            t.verifyEqual(a.evaluations,b.evaluations); t.verifyEqual(a.F,b.F);
        end
        function lockIndependentOfPado(t)
            c=PACPOSearch.config(struct('N',12,'archiveSize',12,'G',4,'seed',19, ...
                'window',1,'hvTolerance',2,'lowVarianceRatio',100,'usePado',false));
            r=PACPOSearch.solve(PACPOSearch.problem('ZDT1'),'PACPO',c);
            t.verifyGreaterThan(sum(r.history(:,4)),0); t.verifyEqual(r.FE,60);
        end
        function disabledLockDoesNotPulse(t)
            c=PACPOSearch.config(struct('N',12,'archiveSize',12,'G',4,'seed',19, ...
                'window',1,'hvTolerance',2,'lowVarianceRatio',100,'useLock',false));
            r=PACPOSearch.solve(PACPOSearch.problem('ZDT1'),'PACPO',c);
            t.verifyEqual(sum(r.history(:,4)),0);
        end
        function topsisKnownBest(t)
            [score,order]=PACPOSearch.topsis([1,1;2,2;3,3],[.5,.5]);
            t.verifyEqual(order,[1;2;3]); t.verifyEqual(score([1,3]),[1;0],'AbsTol',1e-14);
        end
        function holmKnown(t)
            t.verifyEqual(PACPOSearch.holm([.01,.04,.03]),[.03;.06;.06],'AbsTol',1e-14);
        end
        function areaKeepsEndpoints(t)
            f=[0,1;.2,.7;.5,.4;.8,.2;1,0]; k=PACPOSearch.areaPrune(f,3);
            t.verifyTrue(all(ismember([1,5],k)));
        end
        function completeProtocol(t)
            jobs=PACPOExperiment.jobs('complete');
            t.verifyNumElements(jobs,930);
            configurations=[jobs.config];
            t.verifyEqual([configurations.N],100*ones(1,930));
            t.verifyEqual([configurations.G],250*ones(1,930));
        end
        function archiveDuplicatesPreserveFeasibility(t)
            p=PACPOSearch.problem('ENGINEERING'); x=[600,600,200,700;600,600,700,200];
            [f,cv]=PACPOSearch.evaluate(p,x); y=(x-p.lb)./(p.ub-p.lb);
            t.verifyEqual(f(1,:),f(2,:)); t.verifyGreaterThan(cv(1),0); t.verifyEqual(cv(2),0);
            rows=[y,f,cv,[1;2]]; c=PACPOSearch.config();
            a=PACPOSearch.archive(p,zeros(0,9),rows,c);
            t.verifySize(a,[1,9]); t.verifyEqual(a(:,end-1:end),[0,2]);
            b=PACPOSearch.archive(p,zeros(0,9),flipud(rows),c);
            t.verifyEqual(a,b);
        end
    end
end
