function tests = test_mdt_selection_smoke
%TEST_MDT_SELECTION_SMOKE Integration tests for the five-generation bundle.

tests = functiontests(localfunctions);
end

function testSelectionSmokeIsDeterministic(testCase)
dirA = tempname;
dirB = tempname;
cleanup = onCleanup(@() cleanupDirectories(dirA, dirB));

stateBefore = rng;
resultA = mdt.runB0B1SelectionSmoke(dirA);
resultB = mdt.runB0B1SelectionSmoke(dirB);
stateAfter = rng;

verifyEqual(testCase, stateAfter, stateBefore);
verifyEqual(testCase, resultA.finalPopulationB0, resultB.finalPopulationB0);
verifyEqual(testCase, resultA.finalPopulationB1, resultB.finalPopulationB1);
verifyEqual(testCase, resultA.archiveB0, resultB.archiveB0);
verifyEqual(testCase, resultA.archiveB1, resultB.archiveB1);
verifyEqual(testCase, resultA.metrics, resultB.metrics);
end

function testSelectionSmokeWritesRequiredEvidence(testCase)
outputDir = tempname;
cleanup = onCleanup(@() cleanupDirectories(outputDir));

result = mdt.runB0B1SelectionSmoke(outputDir);
requiredFiles = [
    "config.json"
    "initial_population.csv"
    "schedule_donors.csv"
    "schedule_cross_mask.csv"
    "schedule_round_draw.csv"
    "schedule_category_draw.csv"
    "evaluated_b0.csv"
    "evaluated_b1.csv"
    "population_trace_b0.csv"
    "population_trace_b1.csv"
    "archive_b0.csv"
    "archive_b1.csv"
    "metrics.json"
    "environment.json"
    "manifest.json"
    "stdout.log"
    "stderr.log"];

for i = 1:numel(requiredFiles)
    verifyTrue(testCase, isfile(fullfile(outputDir, requiredFiles(i))), ...
        "Missing selection smoke artifact: " + requiredFiles(i));
end

manifest = jsondecode(fileread(fullfile(outputDir, "manifest.json")));
verifyEqual(testCase, string(manifest.status), "SELECTION_SMOKE_COMPLETE");
verifyEqual(testCase, manifest.evaluationsPerBranch, 180);
verifyEqual(testCase, manifest.requiredArtifactCount, numel(requiredFiles));
projectRoot = fileparts(fileparts(mfilename('fullpath')));
matlabSources = dir(fullfile(projectRoot, 'matlab', '**', '*.m'));
verifyEqual(testCase, numel(manifest.sourceHashes), numel(matlabSources)+1);
verifyEqual(testCase, result.metrics.nfeTimeline, 0:30:180);
verifyGreaterThanOrEqual(testCase, diff(result.metrics.pcrTimelineB0), ...
    zeros(1, 6));
verifyGreaterThanOrEqual(testCase, diff(result.metrics.pcrTimelineB1), ...
    zeros(1, 6));
verifyLessThanOrEqual(testCase, size(result.archiveB0.X, 1), 30);
verifyLessThanOrEqual(testCase, size(result.archiveB1.X, 1), 30);
end

function cleanupDirectories(varargin)
for i = 1:nargin
    if isfolder(varargin{i})
        rmdir(varargin{i}, 's');
    end
end
end
