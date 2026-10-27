classdef TestPhysicalSolver < matlab.unittest.TestCase
    properties (TestParameter)
        algorithm={'PACPO','NSGAII','MOEAD','MOPSO'};
    end
    methods (Test)
        function realModelBudgets(t,algorithm)
            p=PACPOPhysical.problem('PPAR'); p.model=PPaPaRModel.config(512);
            c=PACPOPhysical.config(struct('N',20,'G',3,'archiveSize',20,'seed',917));
            r=PACPOPhysical.solve(p,algorithm,c);
            t.verifyEqual(r.FE,80); t.verifyEqual(size(r.evaluations,1),80);
            t.verifyTrue(all(isfinite(r.F),'all')); t.verifyTrue(all(r.history(:,6)==0));
            t.verifyEqual(r.F,PPaPaRModel.evaluate(r.X,p.model),'AbsTol',1e-12);
            t.verifyTrue(all(r.X>=p.lb & r.X<=p.ub,'all'));
        end
        function geometryNotAlteredByHistoricalRepair(t)
            p=PACPOPhysical.problem('PPAR'); y=[.2,.8,.9,.1];
            [actual,changed]=PACPOPhysical.repair(p,y);
            t.verifyEqual(actual,y); t.verifyFalse(changed);
        end
    end
end
