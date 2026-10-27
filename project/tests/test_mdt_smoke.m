function tests = test_mdt_smoke
%TEST_MDT_SMOKE Integration tests for the fixed-seed one-generation bundle.

tests = functiontests(localfunctions);
end

function testSmokeBundleIsDeterministic(testCase)
dirA = tempname;
dirB = tempname;
cleanup = onCleanup(@() cleanupDirectories(dirA, dirB));

stateBefore = rng;
resultA = mdt.runB0B1Smoke(dirA);
resultB = mdt.runB0B1Smoke(dirB);
stateAfter = rng;

verifyEqual(testCase, stateAfter, stateBefore);
verifyEqual(testCase, resultA.initialPopulation, resultB.initialPopulation);
verifyEqual(testCase, resultA.offspringB0, resultB.offspringB0);
verifyEqual(testCase, resultA.offspringB1, resultB.offspringB1);
verifyEqual(testCase, resultA.metrics, resultB.metrics);
verifyEqual(testCase, resultA.offspringB0(:, 1:2), resultA.offspringB1(:, 1:2));
end

function testSmokeBundleWritesRequiredEvidence(testCase)
outputDir = tempname;
cleanup = onCleanup(@() cleanupDirectories(outputDir));

result = mdt.runB0B1Smoke(outputDir);
requiredFiles = [
    "config.json"
    "initial_population.csv"
    "donor_indices.csv"
    "cross_mask.csv"
    "round_draw.csv"
    "category_draw.csv"
    "offspring_b0.csv"
    "offspring_b1.csv"
    "objectives_parent.csv"
    "constraints_parent.csv"
    "objectives_b0.csv"
    "constraints_b0.csv"
    "objectives_b1.csv"
    "constraints_b1.csv"
    "metrics.json"
    "environment.json"
    "manifest.json"
    "stdout.log"
    "stderr.log"];

for i = 1:numel(requiredFiles)
    verifyTrue(testCase, isfile(fullfile(outputDir, requiredFiles(i))), ...
        "Missing smoke artifact: " + requiredFiles(i));
end

manifest = jsondecode(fileread(fullfile(outputDir, "manifest.json")));
verifyEqual(testCase, string(manifest.status), "SMOKE_COMPLETE");
verifyEqual(testCase, manifest.evaluationsPerBranch, 60);
verifyEqual(testCase, manifest.requiredArtifactCount, numel(requiredFiles));
verifyEqual(testCase, result.metrics.nfeTimeline, [0, 30, 60]);
end

function cleanupDirectories(varargin)
for i = 1:nargin
    if isfolder(varargin{i})
        rmdir(varargin{i}, 's');
    end
end
end
