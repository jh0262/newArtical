function tests = test_mdt_component_selection
tests = functiontests(localfunctions);
end

function testOrdinaryNichingUsesDecisionSpaceMaximin(testCase)
cfg = mdt.makeInstance("C", 3, 3, 0.15, 1);
u = [0; 0.1; 0.2; 0.3; 0.9; 1.0];
X = [u, 0.5*ones(6, 1), zeros(6, 3)];
obj = zeros(6, 2);
con = zeros(6, 2);

[nextX, ~, ~, info] = mdt.selectPopulationNiching(X, obj, con, 3, cfg);
selectedU = sort(nextX(:, 1));
verifyEqual(testCase, selectedU(1), 0, 'AbsTol', 1e-12);
verifyEqual(testCase, selectedU(end), 1, 'AbsTol', 1e-12);
verifyGreaterThanOrEqual(testCase, selectedU(2), 0.3);
verifyEqual(testCase, info.strategy, "ordinary_decision_niching");
verifyFalse(testCase, info.truthUsedBySelection);
end

function testOracleSelectionProtectsRepresentedRelevantComponents(testCase)
cfg = mdt.makeInstance("D", 2, 3, 0.15, 1);
truth = mdt.enumerateTruth(cfg);
states = truth.validDiscreteStates;
X = zeros(20, 5);
for component = 1:4
    rows = (component-1)*5+(1:5);
    X(rows, 1) = linspace(0, 1, 5);
    X(rows, 2) = 0.5;
    X(rows, 3:5) = repmat(states(component, :), 5, 1);
end
[obj, con] = mdt.evaluate(X, cfg);

[nextX, ~, ~, info] = mdt.selectPopulationOracle( ...
    X, obj, con, 16, cfg, 2);
powers = cfg.q.^((cfg.L-1):-1:0);
componentIds = truth.componentIdByState(round(nextX(:, 3:end))*powers'+1);
counts = accumarray(componentIds, 1, [truth.nComponents, 1]);
verifyGreaterThanOrEqual(testCase, counts, 2*ones(4, 1));
verifyEqual(testCase, info.strategy, "oracle_component_protection");
verifyTrue(testCase, info.truthUsedBySelection);
verifyEqual(testCase, info.minimumQuota, 2);
end

function testOracleQuotaRejectsInsufficientPopulation(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
truth = mdt.enumerateTruth(cfg);
states = truth.validDiscreteStates;
X = [linspace(0, 1, 9)', 0.5*ones(9, 1), states];
[obj, con] = mdt.evaluate(X, cfg);
verifyError(testCase, ...
    @() mdt.selectPopulationOracle(X, obj, con, 8, cfg, 2), ...
    'mdt:OracleQuotaExceedsCapacity');
end

function testOptimizerExposesB2B3TruthBoundary(testCase)
cfg = mdt.makeInstance("D", 2, 3, 0.15, 1);
op = struct('F', 0.5, 'CR', 0.5, 'FCategory', 0.5, ...
    'minimumComponentQuota', 2);
b2 = mdt.runOptimizer("B2", cfg, op, 123, 16, 64, 16);
b3 = mdt.runOptimizer("B3", cfg, op, 123, 16, 64, 16);

verifyFalse(testCase, b2.audit.truthUsedBySelection);
verifyTrue(testCase, b3.audit.truthUsedBySelection);
verifyEqual(testCase, b2.audit.initialPopulation, b3.audit.initialPopulation);
verifyEqual(testCase, b2.audit.scheduleSeeds, b3.audit.scheduleSeeds);
verifyEqual(testCase, b2.metrics.evaluations, b3.metrics.evaluations);
end

function testE3DesignUsesIndependentDiagnosticSeeds(testCase)
design = mdt.makeE3Design();
verifyEqual(testCase, string({design.instances.instanceId}), ...
    ["D-3-4-S", "D-5-3-S"]);
verifyEqual(testCase, design.seeds, 2026090201:2026090210);
verifyEqual(testCase, design.algorithms, ["B2", "B3"]);
verifyEqual(testCase, design.expectedPairs, 20);
verifyEqual(testCase, design.expectedAlgorithmRuns, 40);
verifyEqual(testCase, design.scope, "POST_P1_DIAGNOSTIC_NO_DEPLOYABLE_CLAIM");
end

function testE3PairAllowsOracleOnlyForB3(testCase)
cfg = mdt.makeInstance("D", 2, 3, 0.15, 1);
op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'minimumComponentQuota', 2);
b2 = mdt.runOptimizer("B2", cfg, op, 2026090201, 16, 64, 16);
b3 = mdt.runOptimizer("B3", cfg, op, 2026090201, 16, 64, 16);
audit = mdt.validateE3Pair(b2, b3, "D-2-3-S");
verifyEqual(testCase, audit.status, "PASS");
verifyTrue(testCase, audit.oracleBoundaryCorrect);
verifyEqual(testCase, audit.pairId, "D-2-3-S__seed-2026090201");

b2.audit.truthUsedBySelection = true;
verifyError(testCase, @() mdt.validateE3Pair(b2, b3, "D-2-3-S"), ...
    'mdt:E3PairMismatch');
end

function testE3BatchRefusesOverwrite(testCase)
outputDir = string(tempname);
mkdir(outputDir);
cleanup = onCleanup(@() removeIfPresent(outputDir));
verifyError(testCase, @() mdt.runE3DiagnosticBatch(outputDir), ...
    'mdt:OutputAlreadyExists');
end

function testE3BundleMarksDiagnosticScope(testCase)
outputDir = string(tempname);
cleanup = onCleanup(@() removeIfPresent(outputDir));
cfg = mdt.makeInstance("D", 2, 3, 0.15, 1);
op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'minimumComponentQuota', 2);
result = mdt.runOptimizer("B2", cfg, op, 2026090201, 16, 64, 16);
provenance = struct('matrixRow', "E3-DIAG", 'configId', "B2-FROZEN", ...
    'tuneSpecSha256', repmat('A', 1, 64), ...
    'planSha256', repmat('B', 1, 64), ...
    'sourceFiles', struct('path', "matlab/+mdt/runOptimizer.m", ...
    'sha256', repmat('C', 1, 64)), ...
    'testEvidencePath', "evidence/e3_preflight_junit.xml", ...
    'testEvidenceSha256', repmat('D', 1, 64), ...
    'comparisonRole', "diagnostic_niching", ...
    'pairId', "D-2-3-S__seed-2026090201", ...
    'scope', "POST_P1_DIAGNOSTIC_NO_DEPLOYABLE_CLAIM");
mdt.writeOptimizerRunBundle(outputDir, result, cfg, provenance);
manifest = jsondecode(fileread(fullfile(outputDir, 'manifest.json')));
verifyTrue(testCase, all(contains(string(manifest.notes), "Diagnostic")));
verifyEqual(testCase, string(manifest.seed.role), "randomness_estimation");
stdout = string(fileread(fullfile(outputDir, 'stdout.log')));
verifyTrue(testCase, contains(stdout, "E3-DIAG"));
verifyFalse(testCase, contains(stdout, "TUNE-01"));
verifyFalse(testCase, contains(stdout, "EXP-P1"));
end

function testB3BundleDisclosesOracleSelection(testCase)
outputDir = string(tempname);
cleanup = onCleanup(@() removeIfPresent(outputDir));
cfg = mdt.makeInstance("D", 2, 3, 0.15, 1);
op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'minimumComponentQuota', 2);
result = mdt.runOptimizer("B3", cfg, op, 2026090201, 16, 64, 16);
provenance = struct('matrixRow', "E3-DIAG", 'configId', "B3-FROZEN", ...
    'tuneSpecSha256', repmat('A', 1, 64), ...
    'planSha256', repmat('B', 1, 64), ...
    'sourceFiles', struct('path', "matlab/+mdt/runOptimizer.m", ...
    'sha256', repmat('C', 1, 64)), ...
    'testEvidencePath', "evidence/e3_preflight_junit.xml", ...
    'testEvidenceSha256', repmat('D', 1, 64), ...
    'comparisonRole', "diagnostic_oracle", ...
    'pairId', "D-2-3-S__seed-2026090201", ...
    'scope', "POST_P1_DIAGNOSTIC_NO_DEPLOYABLE_CLAIM");
mdt.writeOptimizerRunBundle(outputDir, result, cfg, provenance);
config = jsondecode(fileread(fullfile(outputDir, 'config.json')));
verifyTrue(testCase, config.truthUsedBySelection);
end

function removeIfPresent(path)
if isfolder(path)
    rmdir(path, 's');
end
end
