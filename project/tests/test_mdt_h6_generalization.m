function tests = test_mdt_h6_generalization
tests = functiontests(localfunctions);
end

function testStressFamiliesHaveAnalyticCountsAndDisconnectedTruth(testCase)
wm = mdt.makeInstance("WM", 5, 4, 0.025, 1);
wmTruth = mdt.enumerateTruth(wm);
verifyEqual(testCase, size(wmTruth.validDiscreteStates, 1), 125);
verifyEqual(testCase, wmTruth.nComponents, 125);
verifyEqual(testCase, wmTruth.feasibleFractionAnalytic, 0.01, ...
    'AbsTol', 1e-14);

dm2 = mdt.makeInstance("DM2", 5, 4, 0.025, 1);
dm2Truth = mdt.enumerateTruth(dm2);
verifyEqual(testCase, size(dm2Truth.validDiscreteStates, 1), 25);
verifyEqual(testCase, dm2Truth.nComponents, 25);
verifyEqual(testCase, dm2Truth.feasibleFractionAnalytic, 0.002, ...
    'AbsTol', 1e-14);
end

function testStressFamilyPermutationIsSemantic(testCase)
canonical = mdt.makeInstance("WM", 3, 4, 0.05, 1, [0, 1, 2]);
permuted = mdt.makeInstance("WM", 3, 4, 0.05, 1, [2, 0, 1]);
xCanonical = [0.2, 0.5, 0, 0, 0, 0];
xPermuted = [0.2, 0.5, 0, 0, 1, 1];
[objA, conA] = mdt.evaluate(xCanonical, canonical);
[objB, conB] = mdt.evaluate(xPermuted, permuted);
verifyEqual(testCase, objA, objB, 'AbsTol', 1e-14);
verifyEqual(testCase, conA, conB, 'AbsTol', 1e-14);
end

function testRandomInjectionIsDeterministicAndTruthFree(testCase)
cfg = mdt.makeInstance("WM", 3, 4, 0.05, 1);
offspring = [linspace(0, 1, 12)', 0.5*ones(12, 1), zeros(12, 4)];
[a, infoA] = mdt.injectRandomDiscreteStates(offspring, cfg, 5, 77);
[b, infoB] = mdt.injectRandomDiscreteStates(offspring, cfg, 5, 77);
verifyEqual(testCase, a, b);
verifyEqual(testCase, infoA.selectedRows, infoB.selectedRows);
verifyEqual(testCase, infoA.selectedRanks, infoB.selectedRanks);
verifyEqual(testCase, numel(unique(infoA.selectedRanks)), 5);
verifyFalse(testCase, infoA.truthUsedByGeneration);
end

function testMixedNsga2GeneratorPreservesDomainAndSeed(testCase)
cfg = mdt.makeInstance("WM", 3, 4, 0.05, 1);
N = 20;
stream = RandStream('mt19937ar', 'Seed', 12);
population = [rand(stream, N, 2), floor(cfg.q*rand(stream, N, cfg.L))];
[obj, con] = mdt.evaluate(population, cfg);
op = struct('crossoverProbability', 0.9, 'mutationProbability', ...
    1/(2+cfg.L), 'etaC', 20, 'etaM', 20);
a = mdt.generateMixedNSGA2(population, obj, con, cfg, op, 88);
b = mdt.generateMixedNSGA2(population, obj, con, cfg, op, 88);
verifyEqual(testCase, a, b);
verifySize(testCase, a, size(population));
verifyGreaterThanOrEqual(testCase, a(:, 1:2), zeros(N, 2));
verifyLessThanOrEqual(testCase, a(:, 1:2), ones(N, 2));
verifyEqual(testCase, a(:, 3:end), round(a(:, 3:end)));
verifyGreaterThanOrEqual(testCase, a(:, 3:end), zeros(N, cfg.L));
verifyLessThanOrEqual(testCase, a(:, 3:end), ...
    (cfg.q-1)*ones(N, cfg.L));
end

function testAblationsAndNsga2ExposeTruthBoundary(testCase)
cfg = mdt.makeInstance("WM", 3, 4, 0.05, 1);
op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10);
fixed = mdt.runOptimizer("B4F", cfg, op, 901, 20, 80, 20);
random = mdt.runOptimizer("B4R", cfg, op, 901, 20, 80, 20);
n2op = struct('crossoverProbability', 0.9, ...
    'mutationProbability', 1/(2+cfg.L), 'etaC', 20, 'etaM', 20);
n2 = mdt.runOptimizer("N2", cfg, n2op, 901, 20, 80, 20);
verifyEqual(testCase, fixed.audit.noveltyFractionTimeline, ...
    0.05*ones(1, 3), 'AbsTol', 1e-14);
verifyFalse(testCase, random.audit.truthUsedByGeneration);
verifyFalse(testCase, n2.audit.truthUsedBySelection);
verifyFalse(testCase, n2.audit.truthUsedByGeneration);
verifyEqual(testCase, n2.audit.selectionStrategy, ...
    "nsga2_rank_crowding");
end

function testH6DesignIsFrozenAndComplete(testCase)
design = mdt.makeH6Design();
verifyEqual(testCase, string({design.instances.instanceId}), ...
    ["WM-5-4-OOD", "WM-7-3-SPARSE", ...
    "DM2-5-4-SPARSE", "WM-3-6-HDIM"]);
verifyEqual(testCase, design.seeds, 83001:83015);
verifyEqual(testCase, design.algorithms, ...
    ["B1", "B4F", "B4R", "B4", "N2"]);
verifyEqual(testCase, design.expectedSets, 60);
verifyEqual(testCase, design.expectedAlgorithmRuns, 300);
verifyEqual(testCase, design.primaryMetric, "AUC_PCR");
verifyEqual(testCase, design.multiplicityCorrection, "Holm");
end

function testH6SetAuditRequiresFiveMatchedTruthFreeRuns(testCase)
cfg = mdt.makeInstance("WM", 3, 4, 0.05, 1);
de = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10);
n2op = struct('crossoverProbability', 0.9, ...
    'mutationProbability', 1/(2+cfg.L), 'etaC', 20, 'etaM', 20);
runs = struct();
runs.B1 = mdt.runOptimizer("B1", cfg, de, 101, 20, 80, 20);
runs.B4F = mdt.runOptimizer("B4F", cfg, de, 101, 20, 80, 20);
runs.B4R = mdt.runOptimizer("B4R", cfg, de, 101, 20, 80, 20);
runs.B4 = mdt.runOptimizer("B4", cfg, de, 101, 20, 80, 20);
runs.N2 = mdt.runOptimizer("N2", cfg, n2op, 101, 20, 80, 20);
audit = mdt.validateH6ComparisonSet(runs, "WM-3-4-X");
verifyEqual(testCase, audit.status, "PASS");
verifyTrue(testCase, audit.sameInitialPopulation);
verifyTrue(testCase, audit.allTruthFree);
end

function testH6StatisticsRecoverConstantEffects(testCase)
instances = ["I1", "I2", "I3", "I4"];
algorithms = ["B1", "B4F", "B4R", "B4", "N2"];
rows = table();
for instance = instances
    for seed = 1:8
        setId = instance + "__seed-" + seed;
        for algorithm = algorithms
            auc = 0.40;
            if algorithm == "B4"
                auc = 0.42;
            end
            row = table(instance, algorithm, seed, setId, auc, 1.0, ...
                0.7, 0.01, 'VariableNames', {'instanceId','algorithm', ...
                'seed','setId','pcrAuc','finalPcr','finalHv', ...
                'runtimeSeconds'});
            rows = [rows; row]; %#ok<AGROW>
        end
    end
end
stats = mdt.computeH6Statistics(rows, 400, 1000, 4);
verifyEqual(testCase, [stats.comparisons.overallEstimand], ...
    0.02*ones(1, 4), 'AbsTol', 1e-12);
for comparison = stats.comparisons
    verifyEqual(testCase, comparison.bootstrapCi95, [0.02, 0.02], ...
        'AbsTol', 1e-12);
    verifyTrue(testCase, comparison.statisticallyPositive);
end
end

function testH6BatchRefusesOverwrite(testCase)
outputDir = string(tempname);
mkdir(outputDir);
cleanup = onCleanup(@() removeIfPresent(outputDir));
verifyError(testCase, @() mdt.runH6Batch(outputDir), ...
    'mdt:OutputAlreadyExists');
end

function removeIfPresent(path)
if isfolder(path)
    rmdir(path, 's');
end
end
