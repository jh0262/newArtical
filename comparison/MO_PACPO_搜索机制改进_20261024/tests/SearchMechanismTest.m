classdef SearchMechanismTest < matlab.unittest.TestCase
    properties (TestParameter)
        baseline={'NSGAII','MOEAD','MOPSO'};
        candidateVariant={'candidate','candidateDiagonal','candidateNoNoise','candidateNoLock','candidateNoEC','candidateFixed'};
    end
    methods (TestClassSetup)
        function setup(t)
            root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'reference'));
            saved=rng;t.addTeardown(@()rng(saved));
        end
    end
    methods (Test)
        function legacyIdentity(t)
            p=PACPOSearch.problem('ZDT1');o=struct('N',20,'archiveSize',20,'G',6,'seed',301);
            a=PACPOPhysical.solve(p,'PACPO',PACPOPhysical.config(o));
            b=PACPOSearch.solve(p,'PACPO',PACPOSearch.config(o));
            t.verifyEqual(b.evaluations,a.evaluations,'AbsTol',0);
            t.verifyEqual(b.history,a.history,'AbsTol',0);
        end
        function randomStateRestored(t)
            p=PACPOSearch.problem('ZDT1');c=PACPOSearch.config(struct('N',20,'archiveSize',20,'G',6,'mechanism','local'));
            rng(731);before=rng;PACPOSearch.solve(p,'PACPO',c);after=rng;
            t.verifyEqual(after,before);
        end
        function budgetAndBounds(t)
            p=PACPOSearch.problem('DTLZ1');c=PACPOSearch.config(struct('N',20,'archiveSize',20,'G',10,'mechanism','directional'));
            r=PACPOSearch.solve(p,'PACPO',c);
            t.verifyEqual(r.FE,220);t.verifySize(r.evaluations,[220,12]);
            t.verifyGreaterThanOrEqual(min(r.X,[],'all'),0);t.verifyLessThanOrEqual(max(r.X,[],'all'),1);
            t.verifyTrue(all(isfinite(r.evaluations),'all'));
        end
        function deterministic(t)
            p=PACPOSearch.problem('ZDT3');c=PACPOSearch.config(struct('N',20,'archiveSize',20,'G',6,'mechanism','scale'));
            a=PACPOSearch.solve(p,'PACPO',c);b=PACPOSearch.solve(p,'PACPO',c);
            t.verifyEqual(a.evaluations,b.evaluations,'AbsTol',0);
        end
        function noLockDisablesPulse(t)
            p=PACPOSearch.problem('DTLZ1');c=PACPOSearch.config(struct('N',20,'archiveSize',20,'G',6,'mechanism','local','useLock',false));
            r=PACPOSearch.solve(p,'PACPO',c);t.verifyEqual(sum(r.history(:,4)),0);
        end
        function baselineIdentity(t,baseline)
            p=PACPOSearch.problem('DTLZ1');c=SearchVariants.config(baseline,302);
            c.N=20;c.archiveSize=20;c.G=8;
            old=PACPOPhysical.config(struct('N',20,'archiveSize',20,'G',8,'seed',302, ...
                'usePado',false,'useLock',false,'useEC',false));
            a=PACPOPhysical.solve(p,baseline,old);b=PACPOSearch.solve(p,baseline,c);
            t.verifyEqual(b.evaluations,a.evaluations,'AbsTol',0);
            t.verifyEqual(b.history,a.history,'AbsTol',0);
        end
        function candidateContracts(t,candidateVariant)
            p=PACPOSearch.problem('DTLZ1');c=SearchVariants.config(candidateVariant,303);
            c.N=20;c.archiveSize=20;c.G=15;
            a=PACPOSearch.solve(p,'PACPO',c);b=PACPOSearch.solve(p,'PACPO',c);
            t.verifyEqual(a.evaluations,b.evaluations,'AbsTol',0);
            t.verifyEqual(a.FE,320);t.verifySize(a.evaluations,[320,12]);
            t.verifyEqual(a.archive,a.evaluations(a.archiveIDs,:),'AbsTol',0);
            t.verifyGreaterThanOrEqual(min(a.evaluations(:,1:p.D),[],'all'),0);
            t.verifyLessThanOrEqual(max(a.evaluations(:,1:p.D),[],'all'),1);
            t.verifyGreaterThanOrEqual(min(a.diagnostic(:,7)),.02);
            t.verifyLessThanOrEqual(max(a.diagnostic(:,7)),2);
            t.verifyFalse(any(PACPOSearch.dominance(a.F,a.CV),'all'));
        end
        function progressReleasesStagnationLock(t)
            p=PACPOSearch.problem('DTLZ1');c=SearchVariants.config('candidate',304);
            c.N=20;c.archiveSize=20;c.G=20;
            a=PACPOSearch.solve(p,'PACPO',c);progress=a.diagnostic(:,1)>.02;
            counts=a.history(2:end,9);
            t.verifyTrue(any(progress));t.verifyEqual(counts(progress),zeros(nnz(progress),1));
        end
        function degenerateArchiveFinite(t)
            p=PACPOSearch.problem('DTLZ1');c=SearchVariants.config('candidate',305);
            y=.5*ones(4,p.D);f=PACPOSearch.evaluate(p,y);pop=[y,f,zeros(4,1),(1:4)'];
            [child,state,pulse,ld]=SearchMechanism.propose(p,pop,pop(1,:),c,struct('sigma',1),1,5);
            t.verifyTrue(all(isfinite(child),'all'));t.verifyTrue(pulse);t.verifyEqual(ld,p.D);
            t.verifyGreaterThanOrEqual(min(child,[],'all'),0);t.verifyLessThanOrEqual(max(child,[],'all'),1);
            t.verifyEqual(state.parentRows,(1:4)');
        end
    end
end
