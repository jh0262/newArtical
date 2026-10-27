function tests = test_mdt_p1
tests = functiontests(localfunctions);
end

function testP1MatrixMatchesFrozenPlan(testCase)
matrix = mdt.makeP1Matrix();

verifyEqual(testCase, string({matrix.instanceId}), ...
    ["D-3-3-L", "D-3-3-S", "D-3-4-L", "D-3-4-S", "D-5-3-S"]);
verifyEqual(testCase, [matrix.q], [3, 3, 3, 3, 5]);
verifyEqual(testCase, [matrix.L], [3, 3, 4, 4, 3]);
verifyEqual(testCase, [matrix.rho], [0.150, 0.075, 0.150, 0.075, 0.125], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, [matrix.N], [100, 100, 108, 108, 100]);
verifyEqual(testCase, [matrix.budget], [50000, 50000, 54000, 54000, 50000]);
verifyEqual(testCase, [matrix.archiveCapacity], [100, 100, 108, 108, 100]);
verifyTrue(testCase, all([matrix.lambda] == 1));
end

function testP1FrozenConfigsAndSeedsAreExact(testCase)
design = mdt.makeP1Design();

verifyEqual(testCase, design.seeds, 2026090101:2026090110);
verifyEqual(testCase, design.expectedAlgorithmRuns, 100);
verifyEqual(testCase, design.B0.configId, "B0-010");
verifyEqual(testCase, [design.B0.F, design.B0.CR], [0.60, 0.45], ...
    'AbsTol', 1e-12);
verifyEqual(testCase, design.B1.configId, "B1-004");
verifyEqual(testCase, [design.B1.F, design.B1.CR, design.B1.FCategory], ...
    [0.30, 0.50, 0.75], 'AbsTol', 1e-12);
verifyEqual(testCase, design.scope, "PILOT_ONLY_NO_H2_DECISION");
end

function testP1PairAuditPassesOnlyForMatchedSchedule(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
b0op = struct('F', 0.60, 'CR', 0.45, 'FCategory', 0.50);
b1op = struct('F', 0.30, 'CR', 0.50, 'FCategory', 0.75);
b0 = mdt.runOptimizer("B0", cfg, b0op, 2026090101, 12, 48, 12);
b1 = mdt.runOptimizer("B1", cfg, b1op, 2026090101, 12, 48, 12);

audit = mdt.validateP1Pair(b0, b1, "D-3-3-L");
verifyEqual(testCase, audit.status, "PASS");
verifyEqual(testCase, audit.pairId, "D-3-3-L__seed-2026090101");
verifyTrue(testCase, audit.sameInitialPopulation);
verifyTrue(testCase, audit.sameScheduleSeeds);
verifyTrue(testCase, audit.sameEvaluationBudget);
verifyTrue(testCase, audit.truthIsolatedFromSelection);

b1.audit.scheduleSeeds(1) = b1.audit.scheduleSeeds(1) + 1;
verifyError(testCase, @() mdt.validateP1Pair(b0, b1, "D-3-3-L"), ...
    'mdt:P1PairMismatch');
end

function testP1BundleUsesPilotScopeAndSharedPairId(testCase)
outputDir = string(tempname);
cleanup = onCleanup(@() removeIfPresent(outputDir));
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
op = struct('F', 0.60, 'CR', 0.45, 'FCategory', 0.50);
result = mdt.runOptimizer("B0", cfg, op, 2026090101, 12, 48, 12);
provenance = struct( ...
    'matrixRow', "EXP-P1", ...
    'configId', "B0-010", ...
    'tuneSpecSha256', repmat('A', 1, 64), ...
    'planSha256', repmat('B', 1, 64), ...
    'sourceFiles', struct('path', "matlab/+mdt/runOptimizer.m", ...
    'sha256', repmat('C', 1, 64)), ...
    'testEvidencePath', "evidence/p1_preflight_junit.xml", ...
    'testEvidenceSha256', repmat('D', 1, 64), ...
    'comparisonRole', "pilot_baseline", ...
    'pairId', "D-3-3-L__seed-2026090101", ...
    'scope', "PILOT_ONLY_NO_H2_DECISION");
mdt.writeOptimizerRunBundle(outputDir, result, cfg, provenance);

manifest = jsondecode(fileread(fullfile(outputDir, 'manifest.json')));
verifyEqual(testCase, string(manifest.matrix_row), "EXP-P1");
verifyEqual(testCase, string(manifest.reproducibility.pair_id), ...
    "D-3-3-L__seed-2026090101");
verifyTrue(testCase, all(contains(string(manifest.notes), "Pilot")));
stdout = string(fileread(fullfile(outputDir, 'stdout.log')));
verifyTrue(testCase, contains(stdout, "EXP-P1"));
verifyFalse(testCase, contains(stdout, "TUNE-01"));
end

function testP1BatchRefusesToOverwriteExistingDirectory(testCase)
outputDir = string(tempname);
mkdir(outputDir);
cleanup = onCleanup(@() removeIfPresent(outputDir));
verifyError(testCase, @() mdt.runP1Batch(outputDir), ...
    'mdt:OutputAlreadyExists');
end


function testP1SourceManifestUsesExistingFailureTreePath(testCase)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
files = mdt.collectP1SourceHashes(projectRoot);
paths = string({files.path});
verifyTrue(testCase, any(paths == ".light/e2/failure-tree.json"));
verifyFalse(testCase, any(paths == ".light/e2/failure_tree.json"));
verifyFalse(testCase, any(paths == "evidence/p1_preflight_junit.xml"));
for i = 1:numel(paths)
    verifyTrue(testCase, isfile(fullfile(projectRoot, paths(i))), paths(i));
end
end


function testPairedHodgesLehmannUsesWalshAverages(testCase)
verifyEqual(testCase, mdt.hodgesLehmannPaired([1; 2; 3]), 2, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, mdt.hodgesLehmannPaired([-2; 0; 2]), 0, ...
    'AbsTol', 1e-12);
verifyError(testCase, @() mdt.hodgesLehmannPaired([]), ...
    'mdt:InvalidPairedDifferences');
end

function testP1StatisticsPreserveInstanceStrata(testCase)
instances = ["D-3-3-L", "D-3-3-S", "D-3-4-L", ...
    "D-3-4-S", "D-5-3-S"];
rows = table();
for instance = instances
    for seed = 1:3
        pairId = instance + "__seed-" + seed;
        b0 = table(instance, "B0", seed, pairId, 0.4, 0.8, 0.6, ...
            0.10, 0, 'VariableNames', {'instanceId','algorithm','seed', ...
            'pairId','pcrAuc','finalPcr','finalHv','duplicateRate', ...
            'noFeasibleCheckpointRate'});
        b1 = table(instance, "B1", seed, pairId, 0.6, 1.0, 0.61, ...
            0.05, 0, 'VariableNames', b0.Properties.VariableNames);
        rows = [rows; b0; b1]; %#ok<AGROW>
    end
end

stats = mdt.computeP1PilotStatistics(rows, 200, 99);
verifyEqual(testCase, stats.pairs, 15);
verifyEqual(testCase, stats.instances, 5);
verifyEqual(testCase, stats.overallEstimand, 0.2, 'AbsTol', 1e-12);
verifyEqual(testCase, stats.bootstrapCi95, [0.2, 0.2], 'AbsTol', 1e-12);
verifyEqual(testCase, [stats.byInstance.hodgesLehmannAuc], ...
    0.2*ones(1, 5), 'AbsTol', 1e-12);
verifyTrue(testCase, stats.guardrails.feasibilityPass);
end

function removeIfPresent(path)
if isfolder(path)
    rmdir(path, 's');
end
end
