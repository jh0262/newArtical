function tests = test_mdt_h14_controlled_benchmark
%TEST_MDT_H14_CONTROLLED_BENCHMARK H14 model and firewall contracts.

tests = functiontests(localfunctions);
end

function testDesignCountsAndFormalGate(testCase)
design = mdt.makeH14Design();
verifyEqual(testCase, design.expectedMainRuns, 5760);
verifyEqual(testCase, design.expectedBoundaryRuns, 960);
verifyEqual(testCase, design.expectedFormalRuns, 6720);
verifyTrue(testCase, design.formalPerformanceAuthorized);
verifyFalse(testCase, design.formalStartAuthorized);
verifyEqual(testCase, design.analysisUnit, "landscape_instance");
end

function testConnectedAndDispersedStateTopologies(testCase)
[~, connected] = mdt.makeH14ControlledBenchmark(16, "connected", 1, 7);
[~, dispersed] = mdt.makeH14ControlledBenchmark(16, "dispersed", 1, 7);
verifyEqual(testCase, connected.allowedStateCount, 4);
verifyEqual(testCase, diff(connected.allowedStates), ones(3, 1));
verifyGreaterThanOrEqual(testCase, diff(dispersed.allowedStates), ...
    4*ones(3, 1));
verifyEqual(testCase, numel(unique(dispersed.allowedStates)), 4);
end

function testFourContinuousComponentsAreDisjoint(testCase)
[~, oracle] = mdt.makeH14ControlledBenchmark(16, "dispersed", 4, 19);
for stateIndex = 1:oracle.allowedStateCount
    rows = (stateIndex-1)*4+(1:4);
    distance = inf(4);
    for i = 1:4
        for j = (i+1):4
            distance(i, j) = norm(oracle.centers(rows(i), :)- ...
                oracle.centers(rows(j), :));
        end
    end
    verifyGreaterThan(testCase, min(distance, [], 'all'), 2*oracle.radius);
end
end

function testEvaluatorAndObserverAgreeOnFeasibility(testCase)
[benchmark, oracle] = mdt.makeH14ControlledBenchmark(16, "connected", 4, 23);
state = oracle.allowedStates(2);
rows = (2-1)*4+(1:4);
X = [oracle.centers(rows, :), repmat(state, 4, 1)];
[obj, con] = benchmark.evaluator(X);
labels = mdt.labelH14Candidates(X, oracle);
verifyTrue(testCase, all(con <= 0));
verifyTrue(testCase, all(labels.feasible));
verifyEqual(testCase, labels.componentId, rows');
verifyTrue(testCase, all(isfinite(obj), 'all'));
end

function testDisallowedStateIsInfeasibleAndFinite(testCase)
[benchmark, oracle] = mdt.makeH14ControlledBenchmark(16, "dispersed", 1, 5);
disallowed = setdiff((0:15)', oracle.allowedStates);
X = [0.5*ones(1, 4), disallowed(1)];
[obj, con] = benchmark.evaluator(X);
labels = mdt.labelH14Candidates(X, oracle);
verifyGreaterThan(testCase, con, 0);
verifyFalse(testCase, labels.allowedState);
verifyFalse(testCase, labels.feasible);
verifyTrue(testCase, all(isfinite(obj), 'all'));
end

function testParetoSegmentsAreOrderedAndNondominated(testCase)
[benchmark, oracle] = mdt.makeH14ControlledBenchmark(16, "connected", 1, 31);
M = oracle.componentCount;
X = zeros(2*M, 5);
for component = 1:M
    center = oracle.centers(component, :);
    stateIndex = ceil(component/oracle.componentsPerState);
    state = oracle.allowedStates(stateIndex);
    X(2*component-1, :) = [center-oracle.radius*[1, 0, 0, 0], state];
    X(2*component, :) = [center+oracle.radius*[1, 0, 0, 0], state];
end
[obj, con] = benchmark.evaluator(X);
verifyLessThanOrEqual(testCase, con, 1e-12*ones(size(con)));
verifyEqual(testCase, min(obj(:, 1)), 0, 'AbsTol', 1e-12);
verifyEqual(testCase, min(obj(:, 2)), 0, 'AbsTol', 1e-12);
verifyFalse(testCase, any(strictlyDominated(obj, 1e-12)));
end

function testConstructionDoesNotMutateGlobalRandomStream(testCase)
rng(7781, 'twister');
expected = rand(1, 5);
rng(7781, 'twister');
mdt.makeH14ControlledBenchmark(256, "dispersed", 4, 41);
actual = rand(1, 5);
verifyEqual(testCase, actual, expected, 'AbsTol', 0);
end

function testBoundaryHasOneFeasibleDiscreteState(testCase)
[benchmark, oracle] = mdt.makeH14ControlledBenchmark(2, "boundary", 1, 12);
verifyEqual(testCase, oracle.allowedStateCount, 1);
state = oracle.allowedStates;
X = [oracle.centers, state];
[~, con] = benchmark.evaluator(X);
verifyLessThanOrEqual(testCase, con, 0);
verifyError(testCase, @() mdt.makeH14ControlledBenchmark(2, ...
    "connected", 1, 12), 'mdt:H14InvalidLayout');
end

function dominated = strictlyDominated(obj, tolerance)
n = size(obj, 1);
dominated = false(n, 1);
for i = 1:n
    dominated(i) = any(all(obj <= obj(i, :)+tolerance, 2) & ...
        any(obj < obj(i, :)-tolerance, 2));
end
end
