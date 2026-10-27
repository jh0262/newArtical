function tests = test_mdt_quality_metrics
%TEST_MDT_QUALITY_METRICS Deterministic tests for E2 quality metrics.

tests = functiontests(localfunctions);
end

function testHypervolumeGoldValue(testCase)
objectives = [0.2, 0.8; 0.8, 0.2];
value = mdt.computeHypervolume2D(objectives, [1, 1]);
verifyEqual(testCase, value, 0.28, 'AbsTol', 1e-12);
end

function testHypervolumeIgnoresDominatedPoints(testCase)
base = [0.2, 0.8; 0.8, 0.2];
augmented = [base; 0.9, 0.9; base(1, :)];
verifyEqual(testCase, mdt.computeHypervolume2D(augmented, [1, 1]), ...
    mdt.computeHypervolume2D(base, [1, 1]), 'AbsTol', 1e-12);
end

function testHypervolumeIsRowPermutationInvariant(testCase)
objectives = [0.1, 0.9; 0.4, 0.5; 0.8, 0.2];
permutation = [3, 1, 2];
verifyEqual(testCase, mdt.computeHypervolume2D(objectives, [1, 1]), ...
    mdt.computeHypervolume2D(objectives(permutation, :), [1, 1]), ...
    'AbsTol', 1e-12);
end

function testIgdPlusGoldValue(testCase)
approximation = [0.2, 0.9; 0.9, 0.2];
reference = [0.2, 0.8; 0.8, 0.2];
value = mdt.computeIgdPlus(approximation, reference);
verifyEqual(testCase, value, 0.1, 'AbsTol', 1e-12);
end

function testIgdPlusIsTranslationInvariant(testCase)
approximation = [0.2, 0.9; 0.9, 0.2];
reference = [0.2, 0.8; 0.8, 0.2];
translation = [3, -2];
verifyEqual(testCase, mdt.computeIgdPlus(approximation, reference), ...
    mdt.computeIgdPlus(approximation+translation, reference+translation), ...
    'AbsTol', 1e-12);
end

function testIgdPlusReturnsInfinityForEmptyApproximation(testCase)
value = mdt.computeIgdPlus(zeros(0, 2), [0.2, 0.8]);
verifyTrue(testCase, isinf(value));
end

function testMeanComponentIgdPlusUsesEqualWeights(testCase)
reference = [0, 1; 0.1, 0.9; 0.2, 0.8; 1, 0];
componentIds = [1; 1; 1; 2];
approximation = reference(1:3, :);

globalValue = mdt.computeIgdPlus(approximation, reference);
componentValue = mdt.computeMeanComponentIgdPlus( ...
    approximation, reference, componentIds);

verifyEqual(testCase, globalValue, 0.2, 'AbsTol', 1e-12);
verifyEqual(testCase, componentValue, 0.4, 'AbsTol', 1e-12);
end

function testReferenceFrontHasEqualComponentCounts(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
truth = mdt.enumerateTruth(cfg);
[reference, componentIds] = mdt.makeReferenceFront(truth, 5);
relevant = find(truth.paretoRelevantByComponent);

verifyEqual(testCase, size(reference, 1), 5*numel(relevant));
for i = 1:numel(relevant)
    verifyEqual(testCase, sum(componentIds == relevant(i)), 5);
end
verifyEqual(testCase, sum(reference, 2), ones(size(reference, 1), 1), ...
    'AbsTol', 1e-12);
end

function testFirstHitGoldTimeline(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
truth = mdt.enumerateTruth(cfg);
relevant = find(truth.paretoRelevantByComponent);
stateA = stateForComponent(truth, relevant(1));
stateB = stateForComponent(truth, relevant(2));
X = [
    0.1, 0.0, stateA;
    0.2, 0.5, stateB;
    0.3, 0.5, stateA];
[obj, con] = mdt.evaluate(X, cfg);

hit = mdt.computeFirstHitNfe(X, obj, con, [1; 2; 3], 5, cfg, truth);
indexA = find(hit.componentIds == relevant(1));
indexB = find(hit.componentIds == relevant(2));

verifyEqual(testCase, hit.time(indexA), 3);
verifyEqual(testCase, hit.time(indexB), 2);
verifyTrue(testCase, hit.eventObserved(indexA));
verifyTrue(testCase, hit.eventObserved(indexB));
verifyEqual(testCase, hit.time(~hit.eventObserved), ...
    5*ones(sum(~hit.eventObserved), 1));
end

function testFirstHitExcludesIrrelevantComponents(testCase)
cfg = mdt.makeInstance("IR", 3, 3, 0.15, 1);
truth = mdt.enumerateTruth(cfg);
irrelevant = find(~truth.paretoRelevantByComponent, 1);
state = stateForComponent(truth, irrelevant);
X = [0.2, 0.5, state];
[obj, con] = mdt.evaluate(X, cfg);

hit = mdt.computeFirstHitNfe(X, obj, con, 1, 4, cfg, truth);

verifyFalse(testCase, any(hit.componentIds == irrelevant));
verifyFalse(testCase, any(hit.eventObserved));
verifyEqual(testCase, hit.time, 4*ones(size(hit.time)));
end

function testFirstHitRejectsInvalidNfe(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
truth = mdt.enumerateTruth(cfg);
X = [0.2, 0.5, truth.validDiscreteStates(1, :); ...
    0.3, 0.5, truth.validDiscreteStates(2, :)];
[obj, con] = mdt.evaluate(X, cfg);

verifyError(testCase, ...
    @() mdt.computeFirstHitNfe(X, obj, con, [1; 1], 4, cfg, truth), ...
    'mdt:InvalidNfeHistory');
end

function state = stateForComponent(truth, componentId)
row = find(truth.componentIdByValidState == componentId, 1);
state = truth.validDiscreteStates(row, :);
end
