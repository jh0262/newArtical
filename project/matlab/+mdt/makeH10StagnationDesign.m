function design = makeH10StagnationDesign()
%MAKEH10STAGNATIONDESIGN Frozen B5S stagnation diagnostic design.

instances = [
    makeItem("D-5-6-H10", "D", 5, 6, 0.02)
    makeItem("DM2-7-5-H10", "DM2", 7, 5, 0.02)];
operator = struct('F', 0.30, 'CR', 0.50, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 8);
design = struct();
design.schema = "mdt.h10-stagnation-design.v1.0";
design.matrixRow = "H10-STALL-DIAG";
design.scope = "DEVELOPMENT_STAGNATION_DIAGNOSTIC_ONLY";
design.algorithm = "B5S";
design.instances = instances;
design.seeds = 94101:94106;
design.operator = operator;
design.stagnationHorizon = 8;
design.pcrTolerance = 0;
design.hvTolerance = 1e-12;
design.actionableBudgetFraction = 0.80;
design.confirmedRunThreshold = 4;
design.requiredTriggeredInstances = 2;
design.expectedRuns = numel(instances)*numel(design.seeds);
design.fixedEvaluationBudget = sum([instances.budget])*numel(design.seeds);
end

function item = makeItem(id, family, q, L, rho)
item = struct('instanceId', id, 'family', family, 'q', q, 'L', L, ...
    'rho', rho, 'lambda', 1, 'N', 50, 'budget', 1000, ...
    'archiveCapacity', 50);
end

