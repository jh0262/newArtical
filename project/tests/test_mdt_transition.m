function tests = test_mdt_transition
tests = functiontests(localfunctions);
end

function setupOnce(~)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'matlab'));
end

function testQ3F05GoldDistribution(testCase)
diag = mdt.enumerateRoundTransition(3, 0.5);
verifyEqual(testCase, diag.counts, [7, 9, 11]);
verifyEqual(testCase, diag.probabilities, [7, 9, 11]/27, 'AbsTol', 1e-14);
verifyEqual(testCase, diag.totalVariationFromUniform, 2/27, 'AbsTol', 1e-14);
end

function testQ5F08GoldDistribution(testCase)
diag = mdt.enumerateRoundTransition(5, 0.8);
verifyEqual(testCase, diag.counts, [32, 19, 23, 19, 32]);
verifyEqual(testCase, diag.totalVariationFromUniform, 14/125, 'AbsTol', 1e-14);
end

function testKnownUnbiasedCombination(testCase)
diag = mdt.enumerateRoundTransition(3, 0.3);
verifyEqual(testCase, diag.counts, [9, 9, 9]);
verifyEqual(testCase, diag.totalVariationFromUniform, 0, 'AbsTol', 1e-14);
end

function testProbabilityConservationProperty(testCase)
for q = [2, 3, 5, 7]
    for F = [0.0, 0.3, 0.5, 0.8, 1.0]
        diag = mdt.enumerateRoundTransition(q, F);
        verifyEqual(testCase, sum(diag.counts), q^3);
        verifyEqual(testCase, sum(diag.probabilities), 1, 'AbsTol', 1e-14);
        verifyGreaterThanOrEqual(testCase, diag.probabilities, zeros(1, q));
        verifyLessThanOrEqual(testCase, diag.probabilities, ones(1, q));
    end
end
end

function testPermutationSensitivityDetectsNumericEncoding(testCase)
diag = mdt.enumeratePermutationSensitivity(3, 0.5);
verifySize(testCase, diag.semanticDistributions, [factorial(3), 3]);
verifyEqual(testCase, sum(diag.semanticDistributions, 2), ones(factorial(3), 1), ...
    'AbsTol', 1e-14);
verifyGreaterThan(testCase, diag.maxJensenShannonDivergence, 0);
end

function testUniformTransitionIsPermutationInvariant(testCase)
diag = mdt.enumeratePermutationSensitivity(3, 0.3);
verifyEqual(testCase, diag.maxJensenShannonDivergence, 0, 'AbsTol', 1e-14);
end

function testInvalidTransitionParameters(testCase)
verifyError(testCase, @() mdt.enumerateRoundTransition(1, 0.5), ...
    'mdt:InvalidLevelCount');
verifyError(testCase, @() mdt.enumerateRoundTransition(3, -0.1), ...
    'mdt:InvalidScaleFactor');
end
