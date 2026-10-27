function tests = test_mdt_h12_public_comparison
%TEST_MDT_H12_PUBLIC_COMPARISON H12 public comparison contract tests.

tests = functiontests(localfunctions);
end

function testRWMOP19MetadataAndTypeMapping(testCase)
benchmark = mdt.makeRWMOP19Benchmark();

verifyEqual(testCase, benchmark.id, "RCM19");
verifyEqual(testCase, benchmark.sourceProblemIndex, 19);
verifyEqual(testCase, benchmark.variableSpec.continuousLower, ...
    [250, 250, 250, 6, 4, 40, 10]);
verifyEqual(testCase, benchmark.variableSpec.continuousUpper, ...
    [2500, 2500, 2500, 20, 16, 700, 450]);
verifyEqual(testCase, benchmark.variableSpec.discreteCardinalities, ...
    [3, 3, 3]);
verifyEqual(testCase, benchmark.variableSpec.orderedDiscreteCount, 3);
verifyEqual(testCase, benchmark.platemoEncoding, ...
    [1, 1, 1, 1, 1, 1, 1, 2, 2, 2]);
verifyEqual(testCase, benchmark.internalVariableOrder, ...
    ["V1", "V2", "V3", "TL1", "TL2", "B1", "B2", ...
    "N1_code", "N2_code", "N3_code"]);
end

function testRWMOP19MatchesOfficialSnapshotGoldenValues(testCase)
benchmark = mdt.makeRWMOP19Benchmark();
X = [
    1000, 1200, 1400, 10, 8, 200, 100, 0, 1, 2
    250, 250, 250, 6, 4, 40, 10, 0, 0, 0
    2500, 2500, 2500, 20, 16, 700, 450, 2, 2, 2];

[actualObj, actualCon] = benchmark.evaluator(X);
expectedObj = [
    108876.68977514371, 31200, 3600
    20598.010186989704, 200200, 14000
    246006.46663723752, 11803.174603174604, 1853.968253968254];
expectedCon = [
    -2400, -200, 0, -300, -2, 0, -22, 8, -12, -20
    8000, -130, -70, -60, 2, 14, 2, 12, 0, 0
    -4146.0317460317456, 700, 2300, 1650, -52, -40, -52, ...
        -32, -44, -44];

verifyEqual(testCase, actualObj, expectedObj, 'AbsTol', 1e-10);
verifyEqual(testCase, actualCon, expectedCon, 'AbsTol', 1e-10);
end

function testRWMOP19HasFeasibleSentinel(testCase)
benchmark = mdt.makeRWMOP19Benchmark();
X = [2500, 2500, 2500, 20, 16, 300, 150, 2, 2, 2];

[obj, con] = benchmark.evaluator(X);

verifyEqual(testCase, obj, ...
    [246006.46663723752, 22533.333333333336, 4800], ...
    'AbsTol', 1e-10);
verifyLessThanOrEqual(testCase, con, 1e-12*ones(1, 10));
end

function testRWMOP25MetadataGoldenValuesAndSentinel(testCase)
benchmark = mdt.makeRWMOP25Benchmark();
X = [0, 0; 0.5, 1; 1.6, 0];

[actualObj, actualCon] = benchmark.evaluator(X);
expectedObj = [0, 0; 2, -1.25; 3.2, -2.56];
expectedCon = [1.25, -1.6; 0, -0.1; -1.31, 0];

verifyEqual(testCase, benchmark.id, "RCM25");
verifyEqual(testCase, benchmark.variableSpec.continuousLower, 0);
verifyEqual(testCase, benchmark.variableSpec.continuousUpper, 1.6);
verifyEqual(testCase, benchmark.variableSpec.discreteCardinalities, 2);
verifyEqual(testCase, benchmark.variableSpec.orderedDiscreteCount, 0);
verifyEqual(testCase, benchmark.platemoEncoding, [1, 4]);
verifyEqual(testCase, actualObj, expectedObj, 'AbsTol', 1e-12);
verifyEqual(testCase, actualCon, expectedCon, 'AbsTol', 1e-12);
verifyLessThanOrEqual(testCase, actualCon(2, :), 1e-12*ones(1, 2));
end

function testNewAdaptersRejectInvalidDiscreteCodes(testCase)
b19 = mdt.makeRWMOP19Benchmark();
b25 = mdt.makeRWMOP25Benchmark();

verifyError(testCase, @() b19.evaluator( ...
    [1000, 1200, 1400, 10, 8, 200, 100, 0, 1.5, 2]), ...
    'mdt:RWMOP19InvalidDiscreteCode');
verifyError(testCase, @() b25.evaluator([0.5, 2]), ...
    'mdt:RWMOP25InvalidDiscreteCode');
end

function testH12RegistryIncludesThreeAndExcludesConflicts(testCase)
registry = mdt.makeH12PublicBenchmarkSet();

verifyEqual(testCase, string({registry.included.id}), ...
    ["RCM06", "RCM19", "RCM25"]);
verifyEqual(testCase, string({registry.excluded.id}), ...
    ["RCM01", "RCM15", "RCM29"]);
verifyTrue(testCase, contains(registry.excluded(3).reason, ...
    "equation (71)"));
end

function testInternalComparatorsShareInitialPopulationAndBudget(testCase)
benchmark = mdt.makeRWMOP25Benchmark();
commonOp = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10, 'crossoverProbability', 0.9, ...
    'mutationProbability', 0.5, 'etaC', 20, 'etaM', 20);
algorithms = ["B1", "B5S", "N2"];
results = cell(size(algorithms));
for i = 1:numel(algorithms)
    results{i} = mdt.runBlackBoxComparator(algorithms(i), ...
        benchmark.evaluator, benchmark.variableSpec, commonOp, ...
        12025, 12, 36, 24);
    verifyEqual(testCase, results{i}.audit.evaluatorCalls, 36);
    verifyFalse(testCase, results{i}.audit.truthUsed);
    verifyEqual(testCase, results{i}.algorithm, algorithms(i));
end

verifyEqual(testCase, results{1}.audit.initialPopulation, ...
    results{2}.audit.initialPopulation);
verifyEqual(testCase, results{1}.audit.initialPopulation, ...
    results{3}.audit.initialPopulation);
repeat = mdt.runBlackBoxComparator("N2", benchmark.evaluator, ...
    benchmark.variableSpec, commonOp, 12025, 12, 36, 24);
verifyEqual(testCase, repeat.finalPopulation, results{3}.finalPopulation);
verifyEqual(testCase, repeat.trace, results{3}.trace);
end

function testPlatEMOBaselinesObeyExactBudgetAndRestoreState(testCase)
benchmark = mdt.makeRWMOP25Benchmark();
algorithms = ["NSGAII", "CCMO"];
for algorithm = algorithms
    result = mdt.runPlatEMOBaseline(algorithm, benchmark, ...
        12025, 12, 36);
    verifyEqual(testCase, result.audit.evaluatorCalls, 36);
    verifyEqual(testCase, result.audit.hiddenEvaluatorCalls, 0);
    verifyTrue(testCase, result.audit.pathRestored);
    verifyTrue(testCase, result.audit.rngRestored);
    verifyEqual(testCase, result.finalPopulation.X(:, 2), ...
        round(result.finalPopulation.X(:, 2)));
    verifyGreaterThanOrEqual(testCase, result.finalPopulation.X(:, 2), ...
        zeros(12, 1));
    verifyLessThanOrEqual(testCase, result.finalPopulation.X(:, 2), ...
        ones(12, 1));
end

first = mdt.runPlatEMOBaseline("NSGAII", benchmark, 12025, 12, 36);
second = mdt.runPlatEMOBaseline("NSGAII", benchmark, 12025, 12, 36);
verifyEqual(testCase, second.finalPopulation, first.finalPopulation);
end

function testH12SmokeCompletesFrozenMatrixWithoutFormalRuns(testCase)
summary = mdt.runH12PublicComparisonSmoke();

verifyEqual(testCase, summary.completedCombinations, 15);
verifyEqual(testCase, summary.totalCombinations, 15);
verifyEqual(testCase, summary.formalPerformanceRuns, 0);
verifyTrue(testCase, summary.allPassed);
verifyEqual(testCase, unique([summary.runs.evaluatorCalls]), 36);
verifyEqual(testCase, summary.scope, ...
    "execution smoke only; no public performance comparison");
end

