function tests = test_mdt_h5_confirmation
tests = functiontests(localfunctions);
end

function testH5ConfirmationDesignIsIndependentAndComplete(testCase)
design = mdt.makeH5ConfirmDesign();
verifyEqual(testCase, string({design.instances.instanceId}), ...
    ["D-5-3-U", "D-7-3-V", "D-3-4-U"]);
verifyEqual(testCase, design.seeds, 2026090401:2026090430);
verifyEqual(testCase, design.algorithms, ["B0", "B1", "B2", "B4"]);
verifyEqual(testCase, design.expectedSets, 90);
verifyEqual(testCase, design.expectedAlgorithmRuns, 360);
verifyEqual(testCase, design.primaryMetric, "AUC_PCR");
verifyEqual(testCase, design.practicalThreshold, 0.01);
verifyEqual(testCase, design.multiplicityCorrection, "Holm");
end

function testH5SetAuditRequiresFourMatchedNonOracleRuns(testCase)
cfg = mdt.makeInstance("D", 2, 3, 0.15, 1);
op0 = struct('F', 0.6, 'CR', 0.45, 'FCategory', 0.5);
op1 = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75);
op4 = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10);
runs = struct();
runs.B0 = mdt.runOptimizer("B0", cfg, op0, 123, 16, 64, 16);
runs.B1 = mdt.runOptimizer("B1", cfg, op1, 123, 16, 64, 16);
runs.B2 = mdt.runOptimizer("B2", cfg, op1, 123, 16, 64, 16);
runs.B4 = mdt.runOptimizer("B4", cfg, op4, 123, 16, 64, 16);
audit = mdt.validateH5ComparisonSet(runs, "D-2-3-X");
verifyEqual(testCase, audit.status, "PASS");
verifyTrue(testCase, audit.allTruthFree);
verifyTrue(testCase, audit.sameInitialPopulation);
verifyTrue(testCase, audit.sameScheduleSeeds);

runs.B2.audit.truthUsedBySelection = true;
verifyError(testCase, ...
    @() mdt.validateH5ComparisonSet(runs, "D-2-3-X"), ...
    'mdt:H5SetMismatch');
end

function testH5ConfirmBatchRefusesOverwrite(testCase)
outputDir = string(tempname);
mkdir(outputDir);
cleanup = onCleanup(@() removeIfPresent(outputDir));
verifyError(testCase, @() mdt.runH5ConfirmBatch(outputDir), ...
    'mdt:OutputAlreadyExists');
end

function testHolmAdjustmentIsMonotoneInSortedOrder(testCase)
adjusted = mdt.holmAdjust([0.01, 0.04, 0.03]);
verifyEqual(testCase, adjusted, [0.03, 0.06, 0.06], 'AbsTol', 1e-12);
end

function testPracticalThresholdDoesNotPassOnRoundoff(testCase)
verifyFalse(testCase, mdt.exceedsPracticalThreshold(0.01, 0.01));
verifyFalse(testCase, mdt.exceedsPracticalThreshold( ...
    0.01+10*eps(0.01), 0.01));
verifyTrue(testCase, mdt.exceedsPracticalThreshold(0.010001, 0.01));
end

function testH5StatisticsRecoverConstantPositiveEffect(testCase)
instances = ["I1", "I2", "I3"];
algorithms = ["B0", "B1", "B2", "B4"];
rows = table();
for instance = instances
    for seed = 1:10
        setId = instance + "__seed-" + seed;
        for algorithm = algorithms
            auc = 0.4;
            if algorithm == "B4"
                auc = 0.42;
            end
            row = table(instance, algorithm, seed, setId, auc, 1.0, 0.7, ...
                'VariableNames', {'instanceId','algorithm','seed','setId', ...
                'pcrAuc','finalPcr','finalHv'});
            rows = [rows; row]; %#ok<AGROW>
        end
    end
end
stats = mdt.computeH5ConfirmStatistics(rows, 500, 2000, 77);
verifyEqual(testCase, [stats.comparisons.overallEstimand], ...
    0.02*ones(1, 3), 'AbsTol', 1e-12);
for comparison = stats.comparisons
    verifyEqual(testCase, comparison.bootstrapCi95, [0.02, 0.02], ...
        'AbsTol', 1e-12);
    verifyTrue(testCase, comparison.practicalThresholdPassed);
    verifyTrue(testCase, comparison.hvGuardrailPassed);
end
end

function removeIfPresent(path)
if isfolder(path)
    rmdir(path, 's');
end
end
