function design = makeP1Design()
%MAKEP1DESIGN Return the frozen paired-pilot seeds and tuned operators.

design = struct();
design.schema = "mdt.p1-design.v0.1";
design.matrixRow = "EXP-P1";
design.instances = mdt.makeP1Matrix();
design.seeds = 2026090101:2026090110;
design.B0 = struct('configId', "B0-010", 'F', 0.60, 'CR', 0.45, ...
    'FCategory', 0.50);
design.B1 = struct('configId', "B1-004", 'F', 0.30, 'CR', 0.50, ...
    'FCategory', 0.75);
design.algorithms = ["B0", "B1"];
design.expectedPairs = numel(design.instances)*numel(design.seeds);
design.expectedAlgorithmRuns = 2*design.expectedPairs;
design.scope = "PILOT_ONLY_NO_H2_DECISION";
end
