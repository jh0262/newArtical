function design = makeH14Design()
%MAKEH14DESIGN Return the H14 precheck-only controlled study design.

op = struct('F', 0.30, 'CR', 0.50, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10);
design = struct();
design.schema = "mdt.h14-controlled-design.v0.1";
design.status = "FORMAL_RELEASE_PREPARATION_APPROVED";
design.formalPerformanceAuthorized = true;
design.formalStartAuthorized = false;
design.algorithms = ["B1", "B5R", "B5S"];
design.mainCardinalities = [16, 256, 4096];
design.mainLayouts = ["connected", "dispersed"];
design.componentsPerState = [1, 4];
design.boundaryCardinality = 2;
design.landscapeSeeds = 814001:814016;
design.algorithmSeeds = 815001:815010;
design.populationSize = 100;
design.archiveCapacity = 100;
design.budget = 10000;
design.checkpointInterval = 100;
design.operators = struct('B1', op, 'B5R', op, 'B5S', op);
design.primaryMetric = "feasible_discrete_state_coverage_auc";
design.analysisUnit = "landscape_instance";
design.seedRole = "paired stochastic repeats nested within landscape";
design.primaryFamily = ["H14-M1", "H14-M2", "H14-M3"];
design.multiplicity = "Holm FWER 0.05 over the three primary contrasts";
design.hvNoninferiorityMargin = -0.005;
design.hvMarginProvenance = ...
    "pre-existing project guardrail from makeH7Design; not externally validated SESOI";
mainCells = numel(design.mainCardinalities)* ...
    numel(design.mainLayouts)*numel(design.componentsPerState);
design.expectedMainRuns = mainCells*numel(design.landscapeSeeds)* ...
    numel(design.algorithmSeeds)*numel(design.algorithms);
design.expectedBoundaryRuns = numel(design.componentsPerState)* ...
    numel(design.landscapeSeeds)*numel(design.algorithmSeeds)* ...
    numel(design.algorithms);
design.expectedFormalRuns = design.expectedMainRuns+ ...
    design.expectedBoundaryRuns;
design.claimBoundary = [ ...
    "Design and analytical precheck only until a separate formal-run ", ...
    "authorization freezes source, seeds, matrix, and analysis code."];
end
