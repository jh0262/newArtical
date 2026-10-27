function tests = test_mdt_h13_formal_public_comparison
%TEST_MDT_H13_FORMAL_PUBLIC_COMPARISON Formal public-batch contracts.

tests = functiontests(localfunctions);
end

function testFormalDesignFreezesPairedMatrixAndGenerationBudgets(testCase)
design = mdt.makeH13PublicComparisonDesign();

verifyEqual(testCase, design.algorithms, ...
    ["B1", "B5S", "N2", "NSGAII", "CCMO"]);
verifyEqual(testCase, numel(design.seeds), 30);
verifyEqual(testCase, numel(unique(design.seeds)), 30);
verifyEqual(testCase, design.expectedRuns, 450);
verifyEqual(testCase, design.populationSize, 100);
verifyEqual(testCase, string({design.problems.id}), ...
    ["RCM06", "RCM19", "RCM25"]);
verifyEqual(testCase, [design.problems.nominalBudget], ...
    [20000, 26250, 20000]);
verifyEqual(testCase, [design.problems.executionBudget], ...
    [20000, 26300, 20000]);
verifyEqual(testCase, mod([design.problems.executionBudget], 100), ...
    [0, 0, 0]);
verifyGreaterThanOrEqual(testCase, ...
    [design.problems.executionBudget], [design.problems.nominalBudget]);
verifyLessThan(testCase, ...
    [design.problems.executionBudget]-[design.problems.nominalBudget], ...
    100*ones(1, 3));
verifyEqual(testCase, design.status, "AUTHORIZED_PRE_RESULT");
matrix = mdt.makeH13RunMatrix(design);
verifyEqual(testCase, height(matrix), 450);
verifyEqual(testCase, numel(unique(matrix.runId)), 450);
pairs = unique(matrix.pairId);
counts = arrayfun(@(pairId) sum(matrix.pairId == pairId), pairs);
verifyEqual(testCase, counts, 5*ones(90, 1));
end

function testNormalizedFeasibleHypervolumeHasExactTwoDimensionalGold(testCase)
obj = [2, 8; 5, 5; 8, 2; 9, 9];
con = [-1; -1; -1; -1];

[value, audit] = mdt.computeNormalizedFeasibleHV( ...
    obj, con, [0, 0], [10, 10], [11, 11]);

verifyEqual(testCase, value, 0.54, 'AbsTol', 1e-12);
verifyEqual(testCase, audit.feasibleCount, 4);
verifyEqual(testCase, audit.nondominatedCount, 3);
verifyEqual(testCase, audit.normalizedReferencePoint, [1.1, 1.1], ...
    'AbsTol', 1e-12);
end

function testNormalizedFeasibleHypervolumeHasExactThreeDimensionalGold(testCase)
obj = [2, 3, 4; 8, 8, 8];
con = [-1; -1];

[value, audit] = mdt.computeNormalizedFeasibleHV( ...
    obj, con, [0, 0, 0], [10, 10, 10], [11, 11, 11]);

verifyEqual(testCase, value, 0.504, 'AbsTol', 1e-12);
verifyEqual(testCase, audit.nondominatedCount, 1);
end

function testNormalizedFeasibleHypervolumeIgnoresInfeasibleAndIsScaleInvariant(testCase)
obj = [2, 8; 5, 5; 8, 2];
con = [-1; 0.1; -1];
[base, audit] = mdt.computeNormalizedFeasibleHV( ...
    obj, con, [0, 0], [10, 10], [11, 11]);
[scaled, ~] = mdt.computeNormalizedFeasibleHV( ...
    3*obj+7, con, [7, 7], [37, 37], [40, 40]);

verifyEqual(testCase, scaled, base, 'AbsTol', 1e-12);
verifyEqual(testCase, audit.feasibleCount, 2);
verifyEqual(testCase, audit.infeasibleCount, 1);
verifyEqual(testCase, mdt.computeNormalizedFeasibleHV( ...
    obj, ones(3, 1), [0, 0], [10, 10], [11, 11]), 0);
end

function testPlatEMOFormalRoleIsExplicitAndDefaultRemainsSmoke(testCase)
benchmark = mdt.makeRWMOP25Benchmark();
formal = mdt.runPlatEMOBaseline("NSGAII", benchmark, ...
    13001, 12, 36, true);
smoke = mdt.runPlatEMOBaseline("NSGAII", benchmark, ...
    13001, 12, 36);

verifyTrue(testCase, formal.audit.formalPerformanceRun);
verifyFalse(testCase, smoke.audit.formalPerformanceRun);
verifyEqual(testCase, formal.finalPopulation, smoke.finalPopulation);
verifyEqual(testCase, formal.trace(end, 1), 36);
verifyGreaterThanOrEqual(testCase, formal.trace(:, 2), zeros(3, 1));
verifyLessThanOrEqual(testCase, formal.trace(:, 2), ones(3, 1));
end

function testFormalRoleResolutionCoversInternalAndRejectsMismatch(testCase)
internalAudit = struct('evaluatorCalls', 36, 'truthUsed', false);
formalRole = mdt.resolveH13FormalRole(internalAudit, true);
smokeRole = mdt.resolveH13FormalRole(internalAudit, false);

verifyTrue(testCase, formalRole);
verifyFalse(testCase, smokeRole);
verifyError(testCase, @() mdt.resolveH13FormalRole( ...
    struct('formalPerformanceRun', false), true), ...
    'mdt:H13FormalRoleMismatch');
end

function testPreflightBatchWritesAndResumesFifteenBundles(testCase)
outputDir = string(tempname);
cleanup = onCleanup(@() removeTemp(outputDir));

first = mdt.runH13PublicComparisonBatch(outputDir, "preflight");
second = mdt.runH13PublicComparisonBatch(outputDir, "preflight");

verifyEqual(testCase, first.expectedRuns, 15);
verifyEqual(testCase, first.completedRuns, 15);
verifyEqual(testCase, first.failedRuns, 0);
verifyEqual(testCase, first.resumedRuns, 0);
verifyEqual(testCase, second.completedRuns, 15);
verifyEqual(testCase, second.resumedRuns, 15);
verifyEqual(testCase, numel(dir(fullfile(outputDir, ...
    'runs', '**', 'manifest.json'))), 15);
verifyTrue(testCase, isfile(fullfile(outputDir, 'h13_results.csv')));
verifyTrue(testCase, isfile(fullfile(outputDir, 'batch_manifest.json')));
source = jsondecode(fileread(fullfile(outputDir, 'source_manifest.json')));
sourcePaths = string({source.files.path});
verifyTrue(testCase, any(sourcePaths == ".light/h13/failure-tree.json"));
verifyTrue(testCase, any(sourcePaths == ".light/h13/failure_tree_report.json"));
verifyTrue(testCase, any(sourcePaths == ".light/h13/formal_run_matrix.json"));
completed = dir(fullfile(outputDir, 'runs', '**', 'manifest.json'));
manifest = jsondecode(fileread(fullfile(completed(1).folder, ...
    completed(1).name)));
runSummary = jsondecode(fileread(fullfile(completed(1).folder, ...
    'result_summary.json')));
guardrails = jsondecode(fileread(fullfile(completed(1).folder, ...
    'guardrails.json')));
verifyEqual(testCase, string(manifest.started_at), ...
    string(runSummary.executionStartedAt));
verifyEqual(testCase, string(manifest.ended_at), ...
    string(runSummary.executionEndedAt));
verifyFalse(testCase, runSummary.formalPerformanceRun);
verifyTrue(testCase, guardrails.formalRoleRecorded);
clear cleanup
end

function removeTemp(path)
if isfolder(path)
    rmdir(path, 's');
end
end
