classdef TestP1 < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(t)
            root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'reference'),fullfile(fileparts(root),'MO_PACPO_搜索机制改进_20261024'));
            old=rng;t.addTeardown(@()rng(old));
        end
    end
    methods (Test)
        function pairedMissing(t)
            a=[1;NaN;3;4];b=[2;1;NaN;5];s=P1Stats.paired(a,b,-1);
            t.verifyEqual(s.NValid,2);t.verifyEqual(s.NMissing,2);t.verifyEqual(s.CandidateEffect,1);t.verifyEqual(s.MeanDifference,-1);
        end
        function allMissing(t)
            s=P1Stats.paired([NaN;Inf],[1;2],1);t.verifyEqual(s.NValid,0);t.verifyTrue(isnan(s.RawP));
            a=struct2table(s);a.Metric="HV";a=P1Stats.adjust(a);t.verifyEqual(a.Outcome,"not_evaluable");
        end
        function zeroPairs(t)
            s=P1Stats.paired([1;1],[1;1],1);t.verifyEqual(s.RawP,1);t.verifyEqual(s.CandidateEffect,0);
        end
        function collinear(t)
            v=(0:199)';f=[v,199-v];a=PACPOP1.areaPrune(f,100,'onepass');b=PACPOP1.areaPrune(f,100,'progressive');
            t.verifyEqual(max(diff(sort(f(a,1)))),101);t.verifyLessThanOrEqual(max(diff(sort(f(b,1)))),4);
            t.verifyTrue(all(ismember([1,200],b)));t.verifyEqual(numel(unique(b)),100);
        end
        function areaOrderInvariant(t)
            v=(0:199)'/199;f=[v,1-v.^2];rng(10);perm=randperm(200);a=PACPOP1.areaPrune(f,100,'progressive');b=PACPOP1.areaPrune(f(perm,:),100,'progressive');
            t.verifyEqual(sortrows(f(a,:)),sortrows(f(perm(b),:)));
        end
        function oldAreaIdentity(t)
            p=PACPOP1.problem('ZDT1');c=P1Variants.config('oldArea',331);c.N=20;c.archiveSize=20;c.G=6;
            old=SearchVariants.config('candidate',331);old.N=20;old.archiveSize=20;old.G=6;
            a=PACPOSearch.solve(p,'PACPO',old);b=PACPOP1.solve(p,'PACPO',c);t.verifyEqual(a.evaluations,b.evaluations);t.verifyEqual(a.history,b.history);
        end
        function threeObjectiveIdentity(t)
            p=PACPOP1.problem('DTLZ1');c=P1Variants.config('revised',332);c.N=20;c.archiveSize=20;c.G=6;
            old=SearchVariants.config('candidate',332);old.N=20;old.archiveSize=20;old.G=6;
            a=PACPOSearch.solve(p,'PACPO',old);b=PACPOP1.solve(p,'PACPO',c);t.verifyEqual(a.evaluations,b.evaluations);t.verifyEqual(a.history,b.history);
        end
        function solverContract(t)
            p=PACPOP1.problem('ZDT3');c=P1Variants.config('revised',333);c.N=20;c.archiveSize=20;c.G=8;
            for name=["PACPO","GDE3"]
                if name=="PACPO",a=PACPOP1.solve(p,'PACPO',c);else,a=P1GDE3.solve(p,c);end
                t.verifyEqual(a.FE,180);t.verifyEqual(a.archive,a.evaluations(a.archiveIDs,:));t.verifyTrue(all(isfinite(a.F),'all'));
                t.verifyGreaterThanOrEqual(min(a.X,[],'all'),0);t.verifyLessThanOrEqual(max(a.X,[],'all'),1);
                t.verifyFalse(any(PACPOP1.dominance(a.F,a.CV),'all'));
            end
        end
        function correctedSP(t)
            root=fileparts(fileparts(mfilename('fullpath')));old=fullfile(fileparts(root),'MO_PACPO_搜索机制改进_20261024');
            r=readtable(fullfile(old,'results','external','runs.csv'),'TextType','string');
            a=sortrows(r(r.Problem=="ZDT4"&r.Variant=="candidate",:),'Seed');b=sortrows(r(r.Problem=="ZDT4"&r.Variant=="legacy",:),'Seed');
            s=P1Stats.paired(a.SP,b.SP,-1);t.verifyEqual(s.NValid,25);t.verifyEqual(s.CandidateEffect,.9815384615384616,'AbsTol',1e-12);t.verifyLessThan(s.RawP,.001);
        end
    end
end
