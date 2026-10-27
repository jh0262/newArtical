function tests = test_mdt_tuning
tests = functiontests(localfunctions);
end

function testTuneGridHasEqualUniqueBudgets(testCase)
grid = mdt.makeTuneGrid();
verifyEqual(testCase, numel(grid.B0), 24);
verifyEqual(testCase, numel(grid.B1), 24);
verifyEqual(testCase, numel(unique(string({grid.B0.configId}))), 24);
verifyEqual(testCase, numel(unique(string({grid.B1.configId}))), 24);
verifyTrue(testCase, all([grid.B0.F] >= 0.3 & [grid.B0.F] <= 1.05));
verifyTrue(testCase, all([grid.B0.CR] >= 0.2 & [grid.B0.CR] <= 0.95));
verifyTrue(testCase, all([grid.B1.FCategory] >= 0.25 & ...
    [grid.B1.FCategory] <= 0.75));
end

function testOptimizerHonorsBudgetAndWritesCompleteTrace(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
op = struct('F', 0.5, 'CR', 0.8, 'FCategory', 0.5);
result = mdt.runOptimizer("B1", cfg, op, 1234, 12, 48, 12);

verifyEqual(testCase, result.metrics.nfeTimeline, [0, 12, 24, 36, 48]);
verifyEqual(testCase, result.metrics.evaluations, 48);
verifyGreaterThanOrEqual(testCase, diff(result.metrics.pcrTimeline), ...
    zeros(1, 4));
verifyEqual(testCase, result.metrics.pcrAuc, ...
    mdt.computePcrAuc(result.metrics.nfeTimeline, ...
    result.metrics.pcrTimeline, 48), 'AbsTol', 1e-12);
verifySize(testCase, result.trace, [4, 12]);
verifyEqual(testCase, result.audit.scheduleSeeds, 1235:1237);
end

function testOptimizerSameSeedIsExactlyDeterministic(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
op = struct('F', 0.7, 'CR', 0.5, 'FCategory', 0.75);
a = mdt.runOptimizer("B1", cfg, op, 4321, 12, 48, 12);
b = mdt.runOptimizer("B1", cfg, op, 4321, 12, 48, 12);

verifyEqual(testCase, a.trace, b.trace);
verifyEqual(testCase, a.finalArchive.X, b.finalArchive.X);
verifyEqual(testCase, a.finalArchive.obj, b.finalArchive.obj);
verifyEqual(testCase, a.audit.initialPopulation, b.audit.initialPopulation);
end

function testPairedAlgorithmsShareInitializationAndSchedule(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
op = struct('F', 0.5, 'CR', 0.8, 'FCategory', 0.5);
b0 = mdt.runOptimizer("B0", cfg, op, 9876, 12, 48, 12);
b1 = mdt.runOptimizer("B1", cfg, op, 9876, 12, 48, 12);

verifyEqual(testCase, b0.audit.initialPopulation, b1.audit.initialPopulation);
verifyEqual(testCase, b0.audit.scheduleSeeds, b1.audit.scheduleSeeds);
verifyEqual(testCase, b0.metrics.evaluations, b1.metrics.evaluations);
verifyFalse(testCase, b0.audit.truthUsedBySelection);
verifyFalse(testCase, b1.audit.truthUsedBySelection);
end

function testOptimizerRejectsInvalidBudget(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
op = struct('F', 0.5, 'CR', 0.8, 'FCategory', 0.5);
verifyError(testCase, ...
    @() mdt.runOptimizer("B0", cfg, op, 1, 12, 47, 12), ...
    'mdt:InvalidEvaluationBudget');
end

function testTuneSelectionUsesMedianThenWorstSeed(testCase)
rows = table( ...
    ["B0-001"; "B0-001"; "B0-001"; "B0-002"; "B0-002"; "B0-002"], ...
    [1; 2; 3; 1; 2; 3], ...
    [0.4; 0.5; 0.6; 0.5; 0.5; 0.5], ...
    [0.6; 0.6; 0.6; 0.6; 0.6; 0.6], ...
    [0.5; 0.5; 0.5; 0.5; 0.5; 0.5], ...
    [0.1; 0.1; 0.1; 0.1; 0.1; 0.1], ...
    'VariableNames', {'configId','seed','pcrAuc','finalPcr','finalHv','duplicateRate'});
winner = mdt.selectTuneWinner(rows);
verifyEqual(testCase, winner.configId, "B0-002");
verifyEqual(testCase, winner.medianPcrAuc, 0.5, 'AbsTol', 1e-12);
verifyEqual(testCase, winner.worstPcrAuc, 0.5, 'AbsTol', 1e-12);
end

function testTuneSelectionRejectsIncompleteSeedCoverage(testCase)
rows = table(["B0-001"; "B0-001"; "B0-002"], [1; 2; 1], ...
    [0.4; 0.5; 0.6], [0.6; 0.6; 0.6], [0.5; 0.5; 0.5], ...
    [0.1; 0.1; 0.1], 'VariableNames', ...
    {'configId','seed','pcrAuc','finalPcr','finalHv','duplicateRate'});
verifyError(testCase, @() mdt.selectTuneWinner(rows), ...
    'mdt:IncompleteTuneCoverage');
end

function testOptimizerBundleIsImmutableAndAuditable(testCase)
outputDir = string(tempname);
cleanup = onCleanup(@() removeIfPresent(outputDir));
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
op = struct('F', 0.5, 'CR', 0.8, 'FCategory', 0.5);
result = mdt.runOptimizer("B0", cfg, op, 2468, 12, 48, 12);
provenance = struct( ...
    'matrixRow', "TUNE-01", ...
    'configId', "B0-TEST", ...
    'tuneSpecSha256', repmat('A', 1, 64), ...
    'planSha256', repmat('B', 1, 64), ...
    'sourceFiles', struct('path', "matlab/+mdt/runOptimizer.m", ...
    'sha256', repmat('C', 1, 64)), ...
    'testEvidencePath', "evidence/e2_full_junit.xml", ...
    'testEvidenceSha256', repmat('D', 1, 64), ...
    'comparisonRole', "tuning");
mdt.writeOptimizerRunBundle(outputDir, result, cfg, provenance);

required = ["manifest.json", "config.json", "environment.json", ...
    "stdout.log", "stderr.log", "raw_metrics.csv", ...
    "predictions.csv", "final_archive.csv", "metrics.json", ...
    "test_evidence.json", "guardrails.json"];
for name = required
    verifyTrue(testCase, isfile(fullfile(outputDir, name)), name);
end
manifest = jsondecode(fileread(fullfile(outputDir, 'manifest.json')));
verifyEqual(testCase, string(manifest.schema), "light.run_manifest.v3");
verifyEqual(testCase, string(manifest.status), "completed");
verifyEqual(testCase, string(manifest.matrix_row), "TUNE-01");
verifyEqual(testCase, string(manifest.completion.status), "PASS");
verifyError(testCase, ...
    @() mdt.writeOptimizerRunBundle(outputDir, result, cfg, provenance), ...
    'mdt:OutputAlreadyExists');
end

function removeIfPresent(path)
if isfolder(path)
    rmdir(path, 's');
end
end

function testSourceManifestIsSortedAndBindsTuneInputs(testCase)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
files = mdt.collectTuneSourceHashes(projectRoot);
paths = string({files.path});
verifyEqual(testCase, paths, sort(paths));
verifyTrue(testCase, any(paths == "docs/TUNE_01_SPEC.md"));
verifyTrue(testCase, any(paths == "matlab/+mdt/runOptimizer.m"));
verifyTrue(testCase, any(paths == "tests/test_mdt_tuning.m"));
verifyTrue(testCase, all(strlength(string({files.sha256})) == 64));
end
