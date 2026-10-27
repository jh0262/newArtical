function tests = test_mdt_h14_execution
%TEST_MDT_H14_EXECUTION Run-matrix, authorization and bundle contracts.

tests = functiontests(localfunctions);
end

function testFormalMatrixHasStableCompletePairedCoverage(testCase)
design = mdt.makeH14Design();
matrix = mdt.makeH14RunMatrix(design);
verifyEqual(testCase, height(matrix), 6720);
verifyEqual(testCase, numel(unique(matrix.runId)), 6720);
verifyEqual(testCase, numel(unique(matrix.pairId)), 2240);
[~, ~, pairGroup] = unique(matrix.pairId);
pairCounts = accumarray(pairGroup, 1);
verifyEqual(testCase, pairCounts, 3*ones(2240, 1));
verifyEqual(testCase, sum(~matrix.isBoundary), 5760);
verifyEqual(testCase, sum(matrix.isBoundary), 960);
verifyEqual(testCase, unique(matrix.algorithm)', ["B1", "B5R", "B5S"]);
verifyEqual(testCase, numel(unique(matrix.executionRow)), 14);
verifyEqual(testCase, numel(unique(matrix.landscapeUnitId)), 224);
end

function testFormalModeIsHardBlockedWithoutSeparateAuthorization(testCase)
outputDir = string(tempname);
verifyError(testCase, @() mdt.runH14ControlledBatch( ...
    outputDir, "formal"), 'mdt:H14FormalStartNotAuthorized');
verifyFalse(testCase, isfolder(outputDir));
end

function testPreparedAuthorizationBindingsValidate(testCase)
decision = mdt.validateH14FormalAuthorization(projectRoot());
verifyTrue(testCase, decision.integrityValid);
verifyTrue(testCase, decision.budgetApproved);
verifyFalse(testCase, decision.startAuthorized);
verifyEqual(testCase, decision.status, ...
    "BUDGET_APPROVED_FORMAL_PREPARED");
verifyGreaterThanOrEqual(testCase, decision.verifiedBindings, 8);
end

function testAuthorizationRejectsTamperedHash(testCase)
root = projectRoot();
source = fullfile(root, '.light', 'h14', ...
    'h14_formal_authorization.json');
authorization = jsondecode(fileread(source));
authorization.bindings(1).sha256 = repmat('0', 1, 64);
temporary = string(tempname)+".json";
cleanup = onCleanup(@() removeFile(temporary));
fileId = fopen(temporary, 'w', 'n', 'UTF-8');
fileCleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, jsonencode(authorization), 'char');
clear fileCleanup
verifyError(testCase, @() mdt.validateH14FormalAuthorization( ...
    root, temporary), 'mdt:H14AuthorizationHashMismatch');
clear cleanup
end

function testExecutionGuardAllowsApprovedEnvelope(testCase)
limits = guardLimits();
state = guardState();
decision = mdt.evaluateH14ExecutionGuard(state, limits);
verifyFalse(testCase, decision.stop);
verifyEqual(testCase, decision.reasonId, "CONTINUE");
end

function testExecutionGuardStopsAtEachBoundary(testCase)
limits = guardLimits();
cases = {
    struct('elapsedWallSeconds', 12*3600+1), "STOP-H14-TIME"
    struct('outputBytes', 5*1024^3+1), "STOP-H14-STORAGE"
    struct('freeBytes', 5*1024^3-1), "STOP-H14-STORAGE"
    struct('minutesSinceProgress', 31), "STOP-H14-STALL"
    struct('consecutiveFailedRuns', 3), "STOP-H14-FAILURE"
    struct('attemptedRuns', 1000, 'failedRuns', 6), ...
        "STOP-H14-FAILURE"
    struct('protocolViolation', true), "STOP-H14-PROTOCOL"};
for i = 1:size(cases, 1)
    state = guardState();
    patch = cases{i, 1};
    names = fieldnames(patch);
    for j = 1:numel(names)
        state.(names{j}) = patch.(names{j});
    end
    decision = mdt.evaluateH14ExecutionGuard(state, limits);
    verifyTrue(testCase, decision.stop);
    verifyEqual(testCase, decision.reasonId, cases{i, 2});
end
end

function testFormalPerformanceFlagIsDerivedOnlyFromMode(testCase)
verifyFalse(testCase, mdt.h14FormalPerformanceFlag("preflight"));
verifyTrue(testCase, mdt.h14FormalPerformanceFlag("formal"));
verifyError(testCase, @() mdt.h14FormalPerformanceFlag("smoke"), ...
    'MATLAB:validators:mustBeMember');
end

function testPreflightWritesAndResumesImmutableBundles(testCase)
outputDir = string(tempname);
cleanup = onCleanup(@() removeTemp(outputDir));
first = mdt.runH14ControlledBatch(outputDir, "preflight");
second = mdt.runH14ControlledBatch(outputDir, "preflight");
verifyEqual(testCase, first.expectedRuns, 42);
verifyEqual(testCase, first.completedRuns, 42);
verifyEqual(testCase, first.failedRuns, 0);
verifyEqual(testCase, first.resumedRuns, 0);
verifyEqual(testCase, second.completedRuns, 42);
verifyEqual(testCase, second.resumedRuns, 42);
verifyEqual(testCase, numel(dir(fullfile(outputDir, ...
    'runs', '**', 'manifest.json'))), 42);
verifyEqual(testCase, numel(dir(fullfile(outputDir, ...
    'landscapes', '**', 'oracle.json'))), 14);
batch = jsondecode(fileread(fullfile(outputDir, 'batch_manifest.json')));
verifyEqual(testCase, string(batch.status), "COMPLETE_PREFLIGHT");
verifyFalse(testCase, batch.formalPerformanceRun);
verifyTrue(testCase, isfile(fullfile(outputDir, 'h14_results.csv')));
results = readtable(fullfile(outputDir, 'h14_results.csv'), ...
    'TextType', 'string');
verifyTrue(testCase, all(ismember( ...
    ["truthUsedByAlgorithm", "formalPerformanceRun"], ...
    string(results.Properties.VariableNames))));
verifyFalse(testCase, any(results.truthUsedByAlgorithm));
verifyFalse(testCase, any(results.formalPerformanceRun));
manifestFile = dir(fullfile(outputDir, 'runs', '**', 'manifest.json'));
manifest = jsondecode(fileread(fullfile(manifestFile(1).folder, ...
    manifestFile(1).name)));
verifyEqual(testCase, string(manifest.schema), "light.run_manifest.v3");
verifyEqual(testCase, string(manifest.status), "completed");
verifyEqual(testCase, string(manifest.matrix_row), ...
    string(manifest.matrix_row_id));
verifyEqual(testCase, string(manifest.termination.reason), "natural_exit");
verifyEqual(testCase, string(manifest.completion.status), "PASS");
verifyTrue(testCase, isstruct(manifest.artifacts));
verifyEqual(testCase, string(manifest.artifacts.raw_metrics.path), ...
    "raw_metrics.jsonl");
verifyEqual(testCase, string(manifest.artifacts.predictions.path), ...
    "predictions.csv");
verifyTrue(testCase, isstruct(manifest.config));
verifyTrue(testCase, isstruct(manifest.environment));
verifyGreaterThanOrEqual(testCase, numel(manifest.code.files), 1);
codePaths = replace(string({manifest.code.files.path}), "\", "/");
verifyTrue(testCase, any(codePaths == ...
    "code_snapshot/h14FormalPerformanceFlag.m"));
verifyTrue(testCase, any(codePaths == ...
    "code_snapshot/source_manifest.json"));
verifyGreaterThanOrEqual(testCase, numel(manifest.inputs), 1);
verifyEqual(testCase, string(manifest.seed.role), ...
    "fixed_repro");
verifyEqual(testCase, string(manifest.reproducibility.compare_artifacts(:)'), ...
    ["raw_metrics", "predictions"]);
clear cleanup
end

function testResumeRejectsTamperedArtifact(testCase)
outputDir = string(tempname);
cleanup = onCleanup(@() removeTemp(outputDir));
mdt.runH14ControlledBatch(outputDir, "preflight");
predictionFile = dir(fullfile(outputDir, 'runs', '**', ...
    'predictions.csv'));
fileId = fopen(fullfile(predictionFile(1).folder, ...
    predictionFile(1).name), 'a');
fileCleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, newline, 'char');
clear fileCleanup
verifyError(testCase, @() mdt.runH14ControlledBatch( ...
    outputDir, "preflight"), 'mdt:H14ResumeArtifactMismatch');
clear cleanup
end

function removeTemp(path)
if isfolder(path)
    rmdir(path, 's');
end
end

function removeFile(path)
if isfile(path)
    delete(path);
end
end

function root = projectRoot()
root = string(fileparts(fileparts(mfilename('fullpath'))));
end

function limits = guardLimits()
limits = struct('hardWallSeconds', 12*3600, ...
    'hardOutputBytes', 5*1024^3, 'minimumFreeBytes', 5*1024^3, ...
    'stallMinutes', 30, 'maxConsecutiveFailures', 3, ...
    'maxFailureFraction', 0.005);
end

function state = guardState()
state = struct('elapsedWallSeconds', 60, 'outputBytes', 1024, ...
    'freeBytes', 20*1024^3, 'minutesSinceProgress', 0, ...
    'consecutiveFailedRuns', 0, 'attemptedRuns', 100, ...
    'failedRuns', 0, 'protocolViolation', false);
end
