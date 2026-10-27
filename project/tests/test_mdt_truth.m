function tests = test_mdt_truth
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'matlab'));
testCase.TestData.projectRoot = projectRoot;
end

function testDisconnectedTruthCounts(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1.0);
truth = mdt.enumerateTruth(cfg);

verifyEqual(testCase, size(truth.validDiscreteStates, 1), 9);
verifyEqual(testCase, truth.nComponents, 9);
verifyEqual(testCase, truth.nParetoRelevantComponents, 9);
verifyEqual(testCase, truth.feasibleFractionAnalytic, 0.10, 'AbsTol', 1e-14);
verifyEqual(testCase, unique(truth.componentIdByValidState), (1:9)');
end

function testConnectedMatchedControl(testCase)
cfg = mdt.makeInstance("C", 3, 3, 0.15, 1.0);
truth = mdt.enumerateTruth(cfg);

verifyEqual(testCase, size(truth.validDiscreteStates, 1), 9);
verifyEqual(testCase, truth.nComponents, 1);
verifyEqual(testCase, truth.nParetoRelevantComponents, 1);
verifyEqual(testCase, truth.feasibleFractionAnalytic, 0.10, 'AbsTol', 1e-14);
end

function testDisconnectedCountProperty(testCase)
for q = [2, 3, 5]
    for L = [3, 4]
        cfg = mdt.makeInstance("D", q, L, 0.10, 1.0);
        truth = mdt.enumerateTruth(cfg);
        expected = q^(L-1);
        verifyEqual(testCase, size(truth.validDiscreteStates, 1), expected);
        verifyEqual(testCase, truth.nComponents, expected);
    end
end
end

function testObjectiveAndConstraintGoldValues(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1.0);

xPareto = [0.25, 0.50, 0, 0, 0];
[objPareto, conPareto] = mdt.evaluate(xPareto, cfg);
p = 0.25 / 27;
verifyEqual(testCase, objPareto, [p, 1-p], 'AbsTol', 1e-14);
verifyEqual(testCase, conPareto, [0, -0.15], 'AbsTol', 1e-14);

xBand = [0.25, 0.60, 0, 0, 0];
[objBand, conBand] = mdt.evaluate(xBand, cfg);
verifyEqual(testCase, objBand, objPareto + 0.01, 'AbsTol', 1e-14);
verifyLessThanOrEqual(testCase, conBand(2), 0);
verifyTrue(testCase, all(objPareto < objBand));

xInvalid = [0.25, 0.50, 0, 0, 1];
[~, conInvalid] = mdt.evaluate(xInvalid, cfg);
verifyEqual(testCase, conInvalid(1), 1);
end

function testParetoSegmentsMatchValidStates(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1.0);
truth = mdt.enumerateTruth(cfg);

verifySize(testCase, truth.paretoSegments, [9, 2]);
verifyGreaterThanOrEqual(testCase, truth.paretoSegments(:, 1), zeros(9, 1));
verifyLessThanOrEqual(testCase, truth.paretoSegments(:, 2), ones(9, 1));
verifyEqual(testCase, truth.paretoSegments(:, 2) - truth.paretoSegments(:, 1), ...
    repmat(1/27, 9, 1), 'AbsTol', 1e-14);
end

function testCategoryLabelPermutationMetamorphic(testCase)
cfgCanonical = mdt.makeInstance("D", 3, 3, 0.15, 1.0, [0, 1, 2]);
cfgPermuted = mdt.makeInstance("D", 3, 3, 0.15, 1.0, [2, 0, 1]);

% External category code 1 under cfgPermuted maps to canonical label 0.
xCanonical = [0.25, 0.50, 0, 0, 0];
xPermuted = [0.25, 0.50, 0, 0, 1];
[objCanonical, conCanonical] = mdt.evaluate(xCanonical, cfgCanonical);
[objPermuted, conPermuted] = mdt.evaluate(xPermuted, cfgPermuted);

verifyEqual(testCase, objPermuted, objCanonical, 'AbsTol', 1e-14);
verifyEqual(testCase, conPermuted, conCanonical, 'AbsTol', 1e-14);

truthCanonical = mdt.enumerateTruth(cfgCanonical);
truthPermuted = mdt.enumerateTruth(cfgPermuted);
verifyEqual(testCase, sortrows(truthPermuted.paretoSegments), ...
    sortrows(truthCanonical.paretoSegments), 'AbsTol', 1e-14);
verifyEqual(testCase, truthPermuted.nComponents, truthCanonical.nComponents);
end

function testIrrelevantComponentIsPointwiseDominated(testCase)
cfg = mdt.makeInstance("IR", 3, 3, 0.15, 1.0);
truth = mdt.enumerateTruth(cfg);
verifyEqual(testCase, truth.nComponents, 9);
verifyEqual(testCase, truth.nParetoRelevantComponents, 5);

% First two lexicographic valid states form one objective-space pair.
xRelevant = [0.20, 0.50, 0, 0, 0];
xIrrelevant = [0.20, 0.50, 0, 1, 2];
[objRelevant, conRelevant] = mdt.evaluate(xRelevant, cfg);
[objIrrelevant, conIrrelevant] = mdt.evaluate(xIrrelevant, cfg);

verifyLessThanOrEqual(testCase, conRelevant, zeros(1, 2));
verifyLessThanOrEqual(testCase, conIrrelevant, zeros(1, 2));
verifyEqual(testCase, objIrrelevant, objRelevant + cfg.delta, 'AbsTol', 1e-14);
verifyTrue(testCase, all(objRelevant < objIrrelevant));
end

function testInvalidConfigurationRejected(testCase)
verifyError(testCase, @() mdt.makeInstance("D", 1, 3, 0.15, 1.0), ...
    'mdt:InvalidLevelCount');
verifyError(testCase, @() mdt.makeInstance("D", 3, 2, 0.15, 1.0), ...
    'mdt:InvalidDiscreteDimension');
verifyError(testCase, @() mdt.makeInstance("D", 3, 3, 0.60, 1.0), ...
    'mdt:InvalidRho');
end
