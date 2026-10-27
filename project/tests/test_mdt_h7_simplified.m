function tests = test_mdt_h7_simplified
tests = functiontests(localfunctions);
end

function testB5IsFixedTruthFreeLeastVisitedInjection(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.05, 1);
op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10);
result = mdt.runOptimizer("B5", cfg, op, 700, 20, 80, 20);
verifyEqual(testCase, result.audit.noveltyFractionTimeline, ...
    0.05*ones(1, 3), 'AbsTol', 1e-14);
verifyFalse(testCase, result.audit.truthUsedBySelection);
verifyFalse(testCase, result.audit.truthUsedByGeneration);
verifyEqual(testCase, result.audit.noveltyTargeting, "least_visited");
end

function testH7DesignIsFrozenAndComplete(testCase)
design = mdt.makeH7Design();
verifyEqual(testCase, string({design.instances.instanceId}), ...
    ["D-5-4-H7", "IR-5-4-H7", "WM-5-3-H7", ...
    "WM-3-5-H7", "DM2-7-4-H7"]);
verifyEqual(testCase, design.seeds, 83201:83220);
verifyEqual(testCase, design.algorithms, ["B1", "N2", "B4", "B5"]);
verifyEqual(testCase, design.expectedSets, 100);
verifyEqual(testCase, design.expectedAlgorithmRuns, 400);
verifyEqual(testCase, design.superiorityThreshold, 0.01);
verifyEqual(testCase, design.noninferiorityMargin, -0.005);
end

function testH7SetAuditRequiresFourMatchedTruthFreeRuns(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.05, 1);
de = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10);
n2op = struct('crossoverProbability', 0.9, ...
    'mutationProbability', 1/(2+cfg.L), 'etaC', 20, 'etaM', 20);
runs = struct();
runs.B1 = mdt.runOptimizer("B1", cfg, de, 702, 20, 80, 20);
runs.N2 = mdt.runOptimizer("N2", cfg, n2op, 702, 20, 80, 20);
runs.B4 = mdt.runOptimizer("B4", cfg, de, 702, 20, 80, 20);
runs.B5 = mdt.runOptimizer("B5", cfg, de, 702, 20, 80, 20);
audit = mdt.validateH7ComparisonSet(runs, "D-3-3-X");
verifyEqual(testCase, audit.status, "PASS");
verifyTrue(testCase, audit.allTruthFree);
verifyTrue(testCase, audit.sameInitialPopulation);
end

function testH7StatisticsRecoverSuperiorityAndNoninferiority(testCase)
instances = ["I1", "I2", "I3", "I4", "I5"];
algorithms = ["B1", "N2", "B4", "B5"];
rows = table();
for instance = instances
    for seed = 1:8
        setId = instance + "__seed-" + seed;
        for algorithm = algorithms
            auc = 0.40;
            if algorithm == "B4"
                auc = 0.421;
            elseif algorithm == "B5"
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
stats = mdt.computeH7Statistics(rows, 400, 1000, 9);
verifyTrue(testCase, stats.superiority(1).claimReady);
verifyTrue(testCase, stats.superiority(2).claimReady);
verifyEqual(testCase, stats.noninferiority.overallEstimand, -0.001, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, stats.noninferiority.claimReady);
end

function testH7BatchRefusesOverwrite(testCase)
outputDir = string(tempname);
mkdir(outputDir);
cleanup = onCleanup(@() removeIfPresent(outputDir));
verifyError(testCase, @() mdt.runH7Batch(outputDir), ...
    'mdt:OutputAlreadyExists');
end

function removeIfPresent(path)
if isfolder(path)
    rmdir(path, 's');
end
end
