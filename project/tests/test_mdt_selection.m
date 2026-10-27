function tests = test_mdt_selection
%TEST_MDT_SELECTION Gold and metamorphic tests for environmental selection.

tests = functiontests(localfunctions);
end

function testFeasibleCandidatesHavePriority(testCase)
cfg = fixtureConfig();
X = fixturePopulation();
obj = [0, 0; 0.1, 0.1; 10, 10; 11, 11];
con = [1, -0.1; 0.2, 0; 0, -0.1; 0, -0.1];

[nextX, ~, nextCon] = mdt.selectPopulation(X, obj, con, 2, cfg);

verifyEqual(testCase, sortrows(nextX), sortrows(X(3:4, :)), 'AbsTol', 1e-14);
verifyTrue(testCase, all(nextCon <= 0, 'all'));
end

function testCriticalFrontKeepsObjectiveBoundaries(testCase)
cfg = fixtureConfig();
X = fixturePopulation();
obj = [0, 1; 0.5, 0.5; 1, 0; 0.6, 0.6];
con = -0.1*ones(4, 2);

[~, nextObj] = mdt.selectPopulation(X, obj, con, 2, cfg);

expected = [0, 1; 1, 0];
verifyEqual(testCase, sortrows(nextObj), sortrows(expected), 'AbsTol', 1e-14);
end

function testInfeasibleFillUsesNormalizedViolation(testCase)
cfg = fixtureConfig();
X = fixturePopulation();
obj = [1, 1; 0.4, 0.7; 0.3, 0.8; 0.2, 0.9];
con = [0, -0.1; 0.2, 0; 0, 0.07; 0.3, 0];

[nextX, ~, nextCon, info] = mdt.selectPopulation(X, obj, con, 3, cfg);

verifyEqual(testCase, sortrows(nextX), sortrows(X(1:3, :)), 'AbsTol', 1e-14);
verifyEqual(testCase, sort(info.totalViolation), [0; 0.2; 0.2], 'AbsTol', 1e-14);
verifyEqual(testCase, sum(all(nextCon <= 0, 2)), 1);
end

function testSelectionIsRowPermutationInvariant(testCase)
cfg = fixtureConfig();
X = [fixturePopulation(); 0.3, 0.5, 2, 0, 1; 0.7, 0.5, 1, 2, 0];
obj = [0, 1; 0.5, 0.5; 1, 0; 0.6, 0.6; 0.25, 0.8; 0.8, 0.25];
con = [-0.1*ones(5, 2); 0.1, 0];
permutation = [6, 2, 5, 1, 4, 3];

[selectedA, objA, conA] = mdt.selectPopulation(X, obj, con, 4, cfg);
[selectedB, objB, conB] = mdt.selectPopulation( ...
    X(permutation, :), obj(permutation, :), con(permutation, :), 4, cfg);

verifyEqual(testCase, sortrows([selectedA, objA, conA]), ...
    sortrows([selectedB, objB, conB]), 'AbsTol', 1e-14);
end

function testSelectionRejectsNonfiniteInput(testCase)
cfg = fixtureConfig();
X = fixturePopulation();
obj = zeros(4, 2);
obj(2, 1) = NaN;
con = zeros(4, 2);

verifyError(testCase, @() mdt.selectPopulation(X, obj, con, 2, cfg), ...
    'mdt:InvalidEvaluatedCandidates');
end

function cfg = fixtureConfig()
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
end

function X = fixturePopulation()
X = [
    0.1, 0.5, 0, 0, 0;
    0.2, 0.5, 1, 1, 1;
    0.8, 0.5, 2, 2, 2;
    0.9, 0.5, 0, 1, 2];
end
