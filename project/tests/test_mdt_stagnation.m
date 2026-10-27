function tests = test_mdt_stagnation
tests = functiontests(localfunctions);
end

function testFrozenH10Design(testCase)
design = mdt.makeH10StagnationDesign();
verifyEqual(testCase, design.matrixRow, "H10-STALL-DIAG");
verifyEqual(testCase, numel(design.instances), 2);
verifyEqual(testCase, design.seeds, 94101:94106);
verifyEqual(testCase, design.expectedRuns, 12);
verifyEqual(testCase, design.stagnationHorizon, 8);
verifyEqual(testCase, design.actionableBudgetFraction, 0.80);
verifyEqual(testCase, design.confirmedRunThreshold, 4);
end

function testDetectsActionableJointStagnation(testCase)
result = makeSyntheticResult(true);
diagnostic = mdt.detectOptimizationStagnation(result, 4, 0, 1e-12, 0.80);

verifyTrue(testCase, diagnostic.triggered);
verifyTrue(testCase, diagnostic.actionableStagnation);
verifyEqual(testCase, diagnostic.firstTriggerGeneration, 6);
verifyEqual(testCase, diagnostic.maximumStagnationLength, 10);
verifyEqual(testCase, diagnostic.triggeredGenerations, (6:12)');
end

function testAnyProgressBreaksJointStagnation(testCase)
result = makeSyntheticResult(false);
diagnostic = mdt.detectOptimizationStagnation(result, 4, 0, 1e-12, 0.80);

verifyFalse(testCase, diagnostic.triggered);
verifyFalse(testCase, diagnostic.actionableStagnation);
verifyEqual(testCase, diagnostic.maximumStagnationLength, 2);
verifyTrue(testCase, isempty(diagnostic.triggeredGenerations));
end

function testMalformedTraceIsRejected(testCase)
result = makeSyntheticResult(true);
result.trace = result.trace(:, 1:8);
verifyError(testCase, @() mdt.detectOptimizationStagnation( ...
    result, 4, 0, 1e-12, 0.80), 'mdt:InvalidStagnationInput');
end

function testTinyDiagnosticBatchWritesImmutableEvidence(testCase)
outputDir = string(tempname);
cleanup = onCleanup(@() removeTemporaryDirectory(outputDir));
design = makeTinyDesign();
summary = mdt.runH10StagnationDiagnostic(outputDir, design);

verifyEqual(testCase, summary.completedRuns, 1);
verifyEqual(testCase, summary.failedRuns, 0);
verifyTrue(testCase, isfile(fullfile(outputDir, 'batch_manifest.json')));
verifyTrue(testCase, isfile(fullfile(outputDir, 'h10_stagnation_results.csv')));
verifyTrue(testCase, isfile(fullfile(outputDir, 'runs', ...
    'D-3-3-H10-TEST', 'seed-17', 'attempt-1', 'result.mat')));
verifyError(testCase, @() mdt.runH10StagnationDiagnostic( ...
    outputDir, design), 'mdt:OutputAlreadyExists');
end

function result = makeSyntheticResult(stagnant)
generations = 12;
newFeasible = [1, 1, zeros(1, generations-2)];
pcr = [0.10, 0.20, 0.30, 0.30*ones(1, generations-2)];
hv = [0.10, 0.20, 0.30, 0.30*ones(1, generations-2)]';
archiveSize = [2, 3, 4, 4*ones(1, generations-2)]';
if ~stagnant
    progressGenerations = 3:3:12;
    newFeasible(progressGenerations) = 1;
end
trace = zeros(generations+1, 12);
trace(:, 9) = archiveSize;
trace(:, 10) = hv;
result = struct();
result.metrics = struct('pcrTimeline', [0, pcr]);
result.trace = trace;
result.audit = struct( ...
    'newFeasibleDiscreteStateTimeline', newFeasible);
end

function design = makeTinyDesign()
operator = struct('F', 0.30, 'CR', 0.50, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 2);
item = struct('instanceId', "D-3-3-H10-TEST", 'family', "D", ...
    'q', 3, 'L', 3, 'rho', 0.05, 'lambda', 1, 'N', 10, ...
    'budget', 30, 'archiveCapacity', 10);
design = struct('schema', "mdt.h10-stagnation-design.v1.0", ...
    'matrixRow', "H10-STALL-DIAG", 'scope', "UNIT_TEST", ...
    'algorithm', "B5S", 'instances', item, 'seeds', 17, ...
    'operator', operator, 'stagnationHorizon', 2, ...
    'pcrTolerance', 0, 'hvTolerance', 1e-12, ...
    'actionableBudgetFraction', 0.80, 'confirmedRunThreshold', 1, ...
    'requiredTriggeredInstances', 1, 'expectedRuns', 1, ...
    'fixedEvaluationBudget', 30);
end

function removeTemporaryDirectory(path)
if isfolder(path)
    rmdir(path, 's');
end
end
