function tests = test_mdt_public_benchmarks
%TEST_MDT_PUBLIC_BENCHMARKS H11 public benchmark adapter tests.

tests = functiontests(localfunctions);
end

function testRWMOP6MetadataAndTypeMapping(testCase)
benchmark = mdt.makeRWMOP6Benchmark();

verifyEqual(testCase, benchmark.id, "RCM06");
verifyEqual(testCase, benchmark.name, "Speed Reducer Design");
verifyEqual(testCase, benchmark.sourceDoi, ...
    "10.1016/j.swevo.2021.100961");
verifyEqual(testCase, benchmark.sourceProblemIndex, 6);
verifyEqual(testCase, benchmark.variableSpec.continuousLower, ...
    [2.6, 0.7, 7.3, 7.3, 2.9, 5.0]);
verifyEqual(testCase, benchmark.variableSpec.continuousUpper, ...
    [3.6, 0.8, 8.3, 8.3, 3.9, 5.5]);
verifyEqual(testCase, benchmark.variableSpec.discreteCardinalities, 12);
verifyEqual(testCase, benchmark.variableSpec.orderedDiscreteCount, 1);
verifyEqual(testCase, benchmark.externalVariableOrder, ...
    ["x1", "x2", "x3_integer", "x4", "x5", "x6", "x7"]);
verifyEqual(testCase, benchmark.internalVariableOrder, ...
    ["x1", "x2", "x4", "x5", "x6", "x7", "x3_code"]);
end

function testRWMOP6MatchesOfficialSnapshotGoldenValues(testCase)
benchmark = mdt.makeRWMOP6Benchmark();
X = [
    3.0, 0.75, 8.0, 8.0, 3.5, 5.25, 3
    2.6, 0.70, 7.3, 7.3, 2.9, 5.00, 0
    3.6, 0.80, 8.3, 8.3, 3.9, 5.50, 11];

[actualObj, actualCon] = benchmark.evaluator(X);
expectedObj = [
    3578.428178517500, 963.2928021200187
    2352.346111452960, 1695.9638774580585
    7144.694967784963, 694.5866953529555];
expectedCon = [
    -0.007407407407407404, -0.001034241788958770, ...
    -0.2906739347954472, -0.4732041905359395, -25.0, -8.0, ...
    1.0, -0.850000000000000, -0.325000000000000, ...
    -336.7071978799813, 17.7206290099479
    0.009135278042841075, 0.000200295263670226, ...
    -0.0559350489571071, -0.4658299083032177, -28.1, ...
    -8.285714285714285, 1.285714285714285, -1.050000000000001, ...
    0.100000000000000, 395.9638774580585, 154.6575197122713
    -0.02153604497354498, -0.001962116411029821, ...
    -0.4077960231935114, -0.4902391282685620, -17.6, -7.5, ...
    0.5, -0.550000000000001, -0.350000000000000, ...
    -605.4133046470445, -95.5034689449557];

verifyEqual(testCase, actualObj, expectedObj, 'AbsTol', 1e-10);
verifyEqual(testCase, actualCon, expectedCon, 'AbsTol', 1e-10);
end

function testRWMOP6RejectsInvalidDiscreteCode(testCase)
benchmark = mdt.makeRWMOP6Benchmark();
X = [3.0, 0.75, 8.0, 8.0, 3.5, 5.25, 3.5];

verifyError(testCase, @() benchmark.evaluator(X), ...
    'mdt:RWMOP6InvalidDiscreteCode');
end

function testRWMOP6HasPublishedFeasibleSentinel(testCase)
benchmark = mdt.makeRWMOP6Benchmark();
X = [3.5, 0.7, 8.3, 8.3, 3.9, 5.5, 11];

[obj, con] = benchmark.evaluator(X);

verifyTrue(testCase, all(isfinite(obj), 'all'));
verifyLessThanOrEqual(testCase, con, 1e-12*ones(1, 11));
end

function testRWMOP6RunsThroughTruthFreeB5S(testCase)
benchmark = mdt.makeRWMOP6Benchmark();
op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10);

result = mdt.runB5SparseBlackBox(benchmark.evaluator, ...
    benchmark.variableSpec, op, 11006, 12, 36, 24);

verifyEqual(testCase, result.metrics.evaluations, 36);
verifyEqual(testCase, result.audit.truthUsed, false);
verifyEqual(testCase, result.audit.discreteStateCount, 12);
verifyEqual(testCase, result.finalPopulation.X(:, 7), ...
    round(result.finalPopulation.X(:, 7)));
verifyGreaterThanOrEqual(testCase, result.finalPopulation.X(:, 7), ...
    zeros(12, 1));
verifyLessThanOrEqual(testCase, result.finalPopulation.X(:, 7), ...
    11*ones(12, 1));
end
