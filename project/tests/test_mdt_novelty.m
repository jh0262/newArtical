function tests = test_mdt_novelty
tests = functiontests(localfunctions);
end

function testNoveltyFractionIncreasesOnlyWithStagnation(testCase)
verifyEqual(testCase, mdt.computeNoveltyFraction(0, 0.1, 0.4, 5), ...
    0.1, 'AbsTol', 1e-12);
verifyEqual(testCase, mdt.computeNoveltyFraction(2.5, 0.1, 0.4, 5), ...
    0.25, 'AbsTol', 1e-12);
verifyEqual(testCase, mdt.computeNoveltyFraction(5, 0.1, 0.4, 5), ...
    0.4, 'AbsTol', 1e-12);
verifyEqual(testCase, mdt.computeNoveltyFraction(50, 0.1, 0.4, 5), ...
    0.4, 'AbsTol', 1e-12);
end

function testNoveltyInjectionChoosesLeastVisitedStates(testCase)
cfg = mdt.makeInstance("D", 2, 3, 0.15, 1);
offspring = [linspace(0, 1, 4)', 0.5*ones(4, 1), zeros(4, 3)];
visitCounts = [0; 0; 1; 1; 2; 2; 3; 3];
[injected, info] = mdt.injectNovelDiscreteStates( ...
    offspring, cfg, visitCounts, 2, 123);

verifyEqual(testCase, injected(:, 1:2), offspring(:, 1:2));
verifyEqual(testCase, sort(info.selectedRanks), [0; 1]);
verifyEqual(testCase, numel(unique(info.selectedRows)), 2);
powers = cfg.q.^((cfg.L-1):-1:0);
actualRanks = round(injected(info.selectedRows, 3:end))*powers';
verifyEqual(testCase, sort(actualRanks), [0; 1]);
verifyFalse(testCase, info.truthUsedByGeneration);
end

function testNoveltyInjectionIsDeterministic(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
offspring = [linspace(0, 1, 10)', 0.5*ones(10, 1), zeros(10, 3)];
visits = zeros(cfg.Q, 1);
[a, infoA] = mdt.injectNovelDiscreteStates(offspring, cfg, visits, 5, 99);
[b, infoB] = mdt.injectNovelDiscreteStates(offspring, cfg, visits, 5, 99);
verifyEqual(testCase, a, b);
verifyEqual(testCase, infoA.selectedRows, infoB.selectedRows);
verifyEqual(testCase, infoA.selectedRanks, infoB.selectedRanks);
end

function testB4UsesNoTruthAndRecordsAdaptiveInjection(testCase)
cfg = mdt.makeInstance("D", 2, 3, 0.15, 1);
op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.1, 'noveltyFractionMax', 0.4, ...
    'stagnationHorizon', 5);
result = mdt.runOptimizer("B4", cfg, op, 456, 16, 64, 16);

verifyFalse(testCase, result.audit.truthUsedBySelection);
verifyFalse(testCase, result.audit.truthUsedByGeneration);
verifyEqual(testCase, result.audit.selectionStrategy, "objective_crowding");
verifySize(testCase, result.audit.noveltyFractionTimeline, [1, 3]);
verifyGreaterThan(testCase, result.audit.noveltyInjectionCountTimeline, ...
    zeros(1, 3));
verifyLessThanOrEqual(testCase, result.audit.noveltyInjectionCountTimeline, ...
    16*ones(1, 3));
verifyGreaterThanOrEqual(testCase, ...
    result.audit.seenFeasibleDiscreteStatesFinal, 1);
end

function testB4RejectsMissingNoveltyParameters(testCase)
cfg = mdt.makeInstance("D", 2, 3, 0.15, 1);
op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75);
verifyError(testCase, @() mdt.runOptimizer("B4", cfg, op, 1, 16, 64, 16), ...
    'mdt:MissingNoveltyParameters');
end

function testB4TuneGridIsBalancedAndUnique(testCase)
grid = mdt.makeB4TuneGrid();
verifyEqual(testCase, numel(grid), 8);
verifyEqual(testCase, numel(unique(string({grid.configId}))), 8);
verifyEqual(testCase, unique([grid.noveltyFractionMin]), [0.02, 0.05]);
verifyEqual(testCase, unique([grid.noveltyFractionMax]), [0.2, 0.3]);
verifyEqual(testCase, unique([grid.stagnationHorizon]), [3, 10]);
verifyTrue(testCase, all([grid.noveltyFractionMin] <= ...
    [grid.noveltyFractionMax]));
end

function testB4TuneBatchRefusesOverwrite(testCase)
outputDir = string(tempname);
mkdir(outputDir);
cleanup = onCleanup(@() removeIfPresent(outputDir));
verifyError(testCase, @() mdt.runB4TuneBatch(outputDir), ...
    'mdt:OutputAlreadyExists');
end

function removeIfPresent(path)
if isfolder(path)
    rmdir(path, 's');
end
end
