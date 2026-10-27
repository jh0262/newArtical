function tests = test_mdt_h14_b5r
%TEST_MDT_H14_B5R Equal-frequency random-targeting control contracts.

tests = functiontests(localfunctions);
end

function testRandomControlSharesRowsAndInjectionCountWithSparseTargeting(testCase)
variableSpec = makeSpec(16);
offspring = [linspace(0, 1, 20)', 0.5*ones(20, 3), zeros(20, 1)];
ledger = mdt.makeSparseLedger(16);
ledger = mdt.observeSparseLedger(ledger, [0; 1; 1; 7]);
[~, sparseInfo] = mdt.injectNovelDiscreteStatesSparseBlackBox( ...
    offspring, variableSpec, ledger, 4, 991, "affine");
[randomOffspring, randomInfo] = ...
    mdt.injectRandomDiscreteStatesBlackBox( ...
    offspring, variableSpec, 4, 991);
verifyEqual(testCase, randomInfo.selectedRows, sparseInfo.selectedRows);
verifyEqual(testCase, randomInfo.injectionCount, sparseInfo.injectionCount);
verifyEqual(testCase, numel(unique(randomInfo.selectedRanks)), 4);
verifyGreaterThanOrEqual(testCase, randomInfo.selectedRanks, zeros(4, 1));
verifyLessThan(testCase, randomInfo.selectedRanks, 16*ones(4, 1));
verifyEqual(testCase, randomOffspring(randomInfo.selectedRows, end), ...
    randomInfo.selectedRanks);
verifyFalse(testCase, randomInfo.truthUsedByGeneration);
end

function testB5RAndB5SShareInitializationScheduleAndFrequency(testCase)
[benchmark, oracle] = mdt.makeH14ControlledBenchmark(16, ...
    "dispersed", 1, 17);
design = mdt.makeH14Design();
op = design.operators.B5R;
b5r = mdt.runBlackBoxComparator("B5R", benchmark.evaluator, ...
    benchmark.variableSpec, op, 821, 20, 100, 20);
b5s = mdt.runBlackBoxComparator("B5S", benchmark.evaluator, ...
    benchmark.variableSpec, op, 821, 20, 100, 20);
verifyEqual(testCase, b5r.audit.initialPopulation, ...
    b5s.audit.initialPopulation);
verifyEqual(testCase, b5r.audit.scheduleSeeds, b5s.audit.scheduleSeeds);
verifyEqual(testCase, b5r.audit.noveltyFractionTimeline, ...
    b5s.audit.noveltyFractionTimeline);
verifyEqual(testCase, b5r.audit.noveltyInjectionCountTimeline, ...
    b5s.audit.noveltyInjectionCountTimeline);
verifyEqual(testCase, b5r.audit.evaluatorCalls, 100);
verifyFalse(testCase, b5r.audit.truthUsed);
verifyEqual(testCase, b5r.audit.noveltyTargeting, ...
    "uniform_rejection_without_replacement");
[auc, metricAudit] = mdt.computeH14FeasibleStateCoverageAUC(b5r, oracle);
verifyGreaterThanOrEqual(testCase, auc, 0);
verifyLessThanOrEqual(testCase, auc, 1);
verifyTrue(testCase, metricAudit.truthUsedByMetrics);
verifyFalse(testCase, metricAudit.truthUsedByAlgorithm);
end

function testCoverageAucHasExactGold(testCase)
result = struct();
result.traceColumns = ["checkpoint", "nfe", ...
    "newFeasibleDiscreteStates"];
result.trace = [1, 100, 1; 2, 200, 1; 3, 300, 0; 4, 400, 2];
result.audit = struct('truthUsed', false, ...
    'truthUsedBySelection', false, 'truthUsedByGeneration', false);
oracle = struct('allowedStateCount', 4, ...
    'truthRole', "metrics_and_preflight_only");
[value, audit] = mdt.computeH14FeasibleStateCoverageAUC(result, oracle);
verifyEqual(testCase, audit.coverage, [0.25; 0.5; 0.5; 1]);
verifyEqual(testCase, value, 0.4375, 'AbsTol', 1e-14);
end

function testRandomInjectionDoesNotMutateGlobalStream(testCase)
rng(9901, 'twister');
expected = rand(1, 4);
rng(9901, 'twister');
offspring = [zeros(8, 4), zeros(8, 1)];
mdt.injectRandomDiscreteStatesBlackBox(offspring, makeSpec(16), 4, 11);
actual = rand(1, 4);
verifyEqual(testCase, actual, expected, 'AbsTol', 0);
end

function testRandomControlDoesNotMaterializeLargeStateSpace(testCase)
Q = 1e12;
offspring = [zeros(8, 4), zeros(8, 1)];
[~, info] = mdt.injectRandomDiscreteStatesBlackBox( ...
    offspring, makeSpec(Q), 5, 901);
verifyEqual(testCase, numel(unique(info.selectedRanks)), 5);
verifyGreaterThanOrEqual(testCase, info.selectedRanks, zeros(5, 1));
verifyLessThan(testCase, info.selectedRanks, Q*ones(5, 1));
verifyEqual(testCase, info.scheduler, ...
    "uniform_rejection_without_replacement");
end

function variableSpec = makeSpec(Q)
variableSpec = struct('continuousLower', zeros(1, 4), ...
    'continuousUpper', ones(1, 4), ...
    'discreteCardinalities', Q, 'orderedDiscreteCount', 1, ...
    'constraintScales', 1);
end
