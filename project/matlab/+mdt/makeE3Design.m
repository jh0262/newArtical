function design = makeE3Design()
%MAKEE3DESIGN Return the post-P1 B2-versus-B3 diagnostic design.

first = struct('instanceId', "D-3-4-S", 'family', "D", ...
    'q', 3, 'L', 4, 'rho', 0.075, 'lambda', 1, ...
    'N', 108, 'budget', 54000, 'archiveCapacity', 108);
second = struct('instanceId', "D-5-3-S", 'family', "D", ...
    'q', 5, 'L', 3, 'rho', 0.125, 'lambda', 1, ...
    'N', 100, 'budget', 50000, 'archiveCapacity', 100);
instances = [first, second];

design = struct();
design.schema = "mdt.e3-diagnostic-design.v0.1";
design.matrixRow = "E3-DIAG";
design.instances = instances;
design.seeds = 2026090201:2026090210;
design.algorithms = ["B2", "B3"];
design.operator = struct('F', 0.30, 'CR', 0.50, ...
    'FCategory', 0.75, 'minimumComponentQuota', 2);
design.configIds = struct('B2', "B2-NICHING-v0.1", ...
    'B3', "B3-ORACLE-Q2-v0.1");
design.expectedPairs = numel(instances)*numel(design.seeds);
design.expectedAlgorithmRuns = 2*design.expectedPairs;
design.scope = "POST_P1_DIAGNOSTIC_NO_DEPLOYABLE_CLAIM";
end
