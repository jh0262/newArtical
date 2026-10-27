function tests = test_mdt_operators
tests = functiontests(localfunctions);
end

function setupOnce(~)
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'matlab'));
end

function testScheduleUsesDistinctDonors(testCase)
before = rng;
schedule = mdt.makeDESchedule(10, 5, 0.9, 12345);
after = rng;

verifyEqual(testCase, after, before);
verifySize(testCase, schedule.donorIndices, [10, 3]);
for i = 1:10
    donors = schedule.donorIndices(i, :);
    verifyEqual(testCase, numel(unique(donors)), 3);
    verifyFalse(testCase, any(donors == i));
    verifyTrue(testCase, any(schedule.crossMask(i, :)));
end
end

function testScheduleIsDeterministic(testCase)
a = mdt.makeDESchedule(10, 5, 0.7, 20260829);
b = mdt.makeDESchedule(10, 5, 0.7, 20260829);
verifyEqual(testCase, a, b);
end

function testB0GoldOffspring(testCase)
[population, schedule, cfg, op] = goldFixture();
offspring = mdt.generateRoundDE(population, cfg, op, schedule);

verifyEqual(testCase, offspring(1, :), [0.7, 0.3, 2, 2, 1], 'AbsTol', 1e-14);
verifyTrue(testCase, all(isfinite(offspring), 'all'));
verifyGreaterThanOrEqual(testCase, offspring, zeros(size(offspring)));
verifyLessThanOrEqual(testCase, offspring(:, 1:2), ones(4, 2));
verifyLessThanOrEqual(testCase, offspring(:, 3:end), 2*ones(4, 3));
end

function testB1TypeClosure(testCase)
[population, schedule, cfg, op] = goldFixture();
offspring = mdt.generateTypePreservingDE(population, cfg, op, schedule);

verifyTrue(testCase, all(isfinite(offspring), 'all'));
verifyEqual(testCase, offspring(:, 3:4), round(offspring(:, 3:4)));
verifyGreaterThanOrEqual(testCase, offspring(:, 3:end), zeros(4, 3));
verifyLessThanOrEqual(testCase, offspring(:, 3:end), 2*ones(4, 3));
verifyEqual(testCase, offspring(4, 5), 1);
end

function testB0B1ContinuousColumnsAreIdentical(testCase)
[population, schedule, cfg, op] = goldFixture();
b0 = mdt.generateRoundDE(population, cfg, op, schedule);
b1 = mdt.generateTypePreservingDE(population, cfg, op, schedule);
verifyEqual(testCase, b1(:, 1:2), b0(:, 1:2), 'AbsTol', 1e-14);
end

function testB1CategoryPermutationEquivariance(testCase)
[population, schedule, cfg, op] = goldFixture();
canonical = mdt.generateTypePreservingDE(population, cfg, op, schedule);

permutation = [2, 0, 1];
permutedPopulation = population;
permutedPopulation(:, 5) = reshape(permutation(population(:, 5)+1), [], 1);
permuted = mdt.generateTypePreservingDE(permutedPopulation, cfg, op, schedule);
expectedCategories = reshape(permutation(canonical(:, 5)+1), [], 1);

verifyEqual(testCase, permuted(:, 5), expectedCategories);
verifyEqual(testCase, permuted(:, 1:4), canonical(:, 1:4), 'AbsTol', 1e-14);
end

function testInvalidPopulationRejected(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1.0);
op = struct('F', 0.5, 'CR', 0.9, 'FCategory', 0.5);
schedule = mdt.makeDESchedule(4, 5, 0.9, 1);
bad = zeros(4, 4);
verifyError(testCase, @() mdt.generateRoundDE(bad, cfg, op, schedule), ...
    'mdt:InvalidPopulation');
end

function [population, schedule, cfg, op] = goldFixture()
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1.0);
op = struct('F', 0.5, 'CR', 1.0, 'FCategory', 0.5);
population = [
    0.2, 0.4, 0, 0, 0;
    0.8, 0.6, 1, 1, 1;
    0.4, 0.2, 2, 2, 2;
    0.6, 0.8, 0, 1, 2];
schedule = struct();
schedule.donorIndices = [2, 3, 4; 1, 3, 4; 1, 2, 4; 1, 2, 3];
schedule.crossMask = true(4, 5);
schedule.roundDraw = 0.25*ones(4, 5);
schedule.categoryDraw = 0.60*ones(4, 5);
schedule.seed = NaN;
schedule.CR = 1.0;
end

