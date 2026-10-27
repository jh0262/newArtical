function tests = test_mdt_diagnostics
tests = functiontests(localfunctions);
end

function setupOnce(~)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'matlab'));
end

function testPcrGoldValue(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1.0);
truth = mdt.enumerateTruth(cfg);
s1 = truth.validDiscreteStates(1, :);
s2 = truth.validDiscreteStates(2, :);
X = [
    0.2, 0.5, s1;
    0.8, 0.5, s2;
    0.2, 0.5, s1;
    0.5, 0.5, 0, 0, 1];
[obj, con] = mdt.evaluate(X, cfg);
diag = mdt.computeDiagnostics(X, obj, con, cfg, truth);

verifyEqual(testCase, diag.paretoComponentRecall, 2/9, 'AbsTol', 1e-14);
verifyEqual(testCase, sum(diag.hitParetoComponents), 2);
verifyEqual(testCase, diag.duplicateRate, 1/4, 'AbsTol', 1e-14);
verifyEqual(testCase, diag.discreteConstraintInvalidRate, 1/4, 'AbsTol', 1e-14);
verifyEqual(testCase, diag.bandConstraintInvalidRate, 0, 'AbsTol', 1e-14);
end

function testIrrelevantComponentIsNotCounted(testCase)
cfg = mdt.makeInstance("IR", 3, 3, 0.15, 1.0);
truth = mdt.enumerateTruth(cfg);
X = [
    0.2, 0.5, 0, 0, 0;
    0.2, 0.5, 0, 1, 2];
[obj, con] = mdt.evaluate(X, cfg);
diag = mdt.computeDiagnostics(X, obj, con, cfg, truth);

verifyEqual(testCase, diag.paretoComponentRecall, 1/5, 'AbsTol', 1e-14);
verifyEqual(testCase, sum(diag.hitParetoComponents), 1);
verifyEqual(testCase, sum(diag.nondominatedMask), 1);
end

function testPcrAucGoldValue(testCase)
value = mdt.computePcrAuc([0, 10, 20], [0, 0.5, 1.0], 20);
verifyEqual(testCase, value, 0.5, 'AbsTol', 1e-14);
end

function testPcrAucRejectsInvalidTimeline(testCase)
verifyError(testCase, @() mdt.computePcrAuc([0, 10, 10], [0, 0.5, 1], 20), ...
    'mdt:InvalidNfeTimeline');
verifyError(testCase, @() mdt.computePcrAuc([0, 10, 20], [0, 1.2, 1], 20), ...
    'mdt:InvalidPcrValues');
end

