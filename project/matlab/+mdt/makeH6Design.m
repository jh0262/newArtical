function design = makeH6Design()
%MAKEH6DESIGN Frozen H6 topology-shift and ablation experiment design.

instances = [
    makeItem("WM-5-4-OOD", "WM", 5, 4, 0.025, 160, 16000)
    makeItem("WM-7-3-SPARSE", "WM", 7, 3, 0.015, 196, 19600)
    makeItem("DM2-5-4-SPARSE", "DM2", 5, 4, 0.025, 160, 16000)
    makeItem("WM-3-6-HDIM", "WM", 3, 6, 0.025, 180, 18000)];

de = struct('F', 0.30, 'CR', 0.50, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10);
design = struct();
design.schema = "mdt.h6-design.v0.1";
design.matrixRow = "H6-GEN";
design.instances = instances;
design.seeds = 83001:83015;
design.algorithms = ["B1", "B4F", "B4R", "B4", "N2"];
design.operators = struct('B1', de, 'B4F', de, 'B4R', de, 'B4', de);
design.configIds = struct('B1', "B1-004", 'B4F', "B4F-001", ...
    'B4R', "B4R-001", 'B4', "B4-008", 'N2', "N2-MV-001");
design.primaryMetric = "AUC_PCR";
design.comparisons = ["B4-minus-N2", "B4-minus-B1", ...
    "B4-minus-B4F", "B4-minus-B4R"];
design.practicalThreshold = 0.01;
design.bootstrapReplicates = 20000;
design.permutationReplicates = 50000;
design.bootstrapSeed = 83090;
design.permutationSeed = 83091;
design.multiplicityCorrection = "Holm";
design.expectedSets = numel(instances)*numel(design.seeds);
design.expectedAlgorithmRuns = design.expectedSets*numel(design.algorithms);
design.scope = "H6_FROZEN_GENERALIZATION_AND_ABLATION";
end

function item = makeItem(id, family, q, L, rho, N, budget)
item = struct('instanceId', id, 'family', family, 'q', q, 'L', L, ...
    'rho', rho, 'lambda', 1, 'N', N, 'budget', budget, ...
    'archiveCapacity', N);
end
