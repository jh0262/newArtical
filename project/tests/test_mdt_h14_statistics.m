function tests = test_mdt_h14_statistics
%TEST_MDT_H14_STATISTICS Frozen H1-H4 analysis contracts.

tests = functiontests(localfunctions);
end

function testKnownPrimaryEffectsReachSuccessBranches(testCase)
rows = syntheticFormalResults();
stats = mdt.computeH14Statistics(rows, 1000, 2026083102);
verifyEqual(testCase, stats.schema, "mdt.h14-statistics.v0.1");
verifyEqual(testCase, stats.independentUnit, "landscape instance");
verifyEqual(testCase, stats.nLandscapes, 16);
verifyEqual(testCase, stats.seedsPerLandscape, 10);
verifyEqual(testCase, stats.primaryFamilySize, 3);
verifyEqual(testCase, string({stats.primary.hypothesisId}), ...
    ["H1", "H2", "H3"]);
verifyEqual(testCase, [stats.primary.estimate], ...
    [0.03, 0.035, 0.025], 'AbsTol', 1e-12);
verifyEqual(testCase, string({stats.primary.branch}), ...
    ["success", "success", "success"]);
verifyTrue(testCase, all([stats.primary.holmSignificant]));
verifyTrue(testCase, stats.primary(1).hvGuardrailPassed);
verifyTrue(testCase, stats.primary(2).hvGuardrailPassed);
verifyEqual(testCase, stats.boundary.hypothesisId, "H4");
verifyEqual(testCase, stats.boundary.branch, "success");
verifyFalse(testCase, stats.boundary.equivalenceClaimAllowed);
end

function testH4IntervalCrossingGuardrailIsInconclusive(testCase)
rows = syntheticFormalResults();
isBoundaryB5S = rows.Q == 2 & rows.algorithm == "B5S";
landscapes = unique(rows.landscapeSeed);
for i = 1:numel(landscapes)
    shift = -0.02;
    if i > numel(landscapes)/2
        shift = 0.02;
    end
    mask = isBoundaryB5S & rows.landscapeSeed == landscapes(i);
    rows.normalizedFeasibleHv(mask) = 0.5+shift;
end
stats = mdt.computeH14Statistics(rows, 2000, 2026083102);
verifyEqual(testCase, stats.boundary.branch, "inconclusive");
verifyFalse(testCase, stats.boundary.successConditionMet);
verifyFalse(testCase, stats.boundary.failureConditionMet);
verifyFalse(testCase, stats.boundary.equivalenceClaimAllowed);
end

function testPrimaryAndBoundaryFailureBranchesAreReachable(testCase)
rows = syntheticFormalResults();
highDispersedB5S = rows.Q == 4096 & ...
    rows.stateLayout == "dispersed" & rows.algorithm == "B5S";
rows.fscaAuc(highDispersedB5S) = 0.195;
boundaryB5S = rows.Q == 2 & rows.algorithm == "B5S";
rows.normalizedFeasibleHv(boundaryB5S) = 0.49;
stats = mdt.computeH14Statistics(rows, 500, 2026083102);
verifyEqual(testCase, stats.primary(1).branch, "failure");
verifyTrue(testCase, stats.primary(1).failureConditionMet);
verifyEqual(testCase, stats.boundary.branch, "failure");
verifyTrue(testCase, stats.boundary.failureConditionMet);
end

function testSubthresholdPositivePrimaryEffectIsInconclusive(testCase)
rows = syntheticFormalResults();
highDispersedB5S = rows.Q == 4096 & ...
    rows.stateLayout == "dispersed" & rows.algorithm == "B5S";
rows.fscaAuc(highDispersedB5S) = 0.210;
stats = mdt.computeH14Statistics(rows, 500, 2026083102);
verifyEqual(testCase, stats.primary(1).estimate, 0.005, ...
    'AbsTol', 1e-12);
verifyEqual(testCase, stats.primary(1).branch, "inconclusive");
verifyFalse(testCase, stats.primary(1).successConditionMet);
verifyFalse(testCase, stats.primary(1).failureConditionMet);
end

function testStatisticsAreDeterministicForFixedBootstrapSeed(testCase)
rows = syntheticFormalResults();
first = mdt.computeH14Statistics(rows, 500, 991);
second = mdt.computeH14Statistics(rows, 500, 991);
verifyEqual(testCase, [first.primary.bootstrapCi95], ...
    [second.primary.bootstrapCi95]);
verifyEqual(testCase, ...
    [first.boundary.comparisons.bootstrapCi95], ...
    [second.boundary.comparisons.bootstrapCi95]);
end

function testIncompleteOrDuplicateCoverageIsRejected(testCase)
rows = syntheticFormalResults();
verifyError(testCase, @() mdt.computeH14Statistics( ...
    rows(1:end-1, :), 100, 1), 'mdt:InvalidH14ResultCoverage');
duplicate = rows;
duplicate.runId(end) = duplicate.runId(1);
verifyError(testCase, @() mdt.computeH14Statistics( ...
    duplicate, 100, 1), 'mdt:InvalidH14ResultCoverage');
end

function testPreflightTruthLeakAndNonfiniteMetricsAreRejected(testCase)
rows = syntheticFormalResults();
preflight = rows;
preflight.formalPerformanceRun(:) = false;
verifyError(testCase, @() mdt.computeH14Statistics( ...
    preflight, 100, 1), 'mdt:H14ProtocolViolation');
truthLeak = rows;
truthLeak.truthUsedByAlgorithm(1) = true;
verifyError(testCase, @() mdt.computeH14Statistics( ...
    truthLeak, 100, 1), 'mdt:H14ProtocolViolation');
nonfinite = rows;
nonfinite.fscaAuc(1) = NaN;
verifyError(testCase, @() mdt.computeH14Statistics( ...
    nonfinite, 100, 1), 'mdt:InvalidH14Results');
end

function testOneCommandAnalysisWritesHashBoundArtifacts(testCase)
root = string(tempname);
mkdir(root);
cleanup = onCleanup(@() removeTemp(root));
resultsFile = fullfile(root, 'h14_results.csv');
outputDir = fullfile(root, 'analysis');
writetable(syntheticFormalResults(), resultsFile);
summary = mdt.runH14ResultAnalysis(resultsFile, outputDir, 100, 77);
verifyEqual(testCase, summary.status, "COMPLETE_SYNTHETIC_OR_FORMAL_INPUT");
expected = ["h14_statistics.json", "h14_primary_contrasts.csv", ...
    "h14_boundary_contrasts.csv", "analysis_manifest.json"];
for file = expected
    verifyTrue(testCase, isfile(fullfile(outputDir, file)));
end
manifest = jsondecode(fileread(fullfile(outputDir, ...
    'analysis_manifest.json')));
verifyEqual(testCase, string(manifest.schema), ...
    "mdt.h14-analysis-manifest.v0.1");
verifyEqual(testCase, string(manifest.status), "completed");
verifyEqual(testCase, numel(manifest.artifacts), 3);
verifyError(testCase, @() mdt.runH14ResultAnalysis( ...
    resultsFile, outputDir, 100, 77), ...
    'mdt:H14AnalysisOutputCollision');
clear cleanup
end

function rows = syntheticFormalResults()
matrix = mdt.makeH14RunMatrix(mdt.makeH14Design());
rows = matrix(:, {'runId','executionRow','Q','stateLayout', ...
    'componentsPerState','landscapeSeed','algorithmSeed', ...
    'algorithm'});
rows.actualNfe = 10000*ones(height(rows), 1);
rows.fscaAuc = 0.2*ones(height(rows), 1);
rows.finalFeasibleStateCoverage = 0.25*ones(height(rows), 1);
rows.normalizedFeasibleHv = 0.5*ones(height(rows), 1);
rows.status = repmat("completed", height(rows), 1);
rows.truthUsedByAlgorithm = false(height(rows), 1);
rows.formalPerformanceRun = true(height(rows), 1);

isB5R = rows.algorithm == "B5R";
isB5S = rows.algorithm == "B5S";
rows.fscaAuc(isB5R) = 0.205;
rows.fscaAuc(isB5S) = 0.205;
highDispersed = rows.Q == 4096 & rows.stateLayout == "dispersed";
lowDispersed = rows.Q == 16 & rows.stateLayout == "dispersed";
rows.fscaAuc(isB5S & highDispersed) = 0.235;
rows.fscaAuc(isB5S & lowDispersed) = 0.210;
end

function removeTemp(path)
if isfolder(path)
    rmdir(path, 's');
end
end
