function tests = test_mdt_h13_statistics
%TEST_MDT_H13_STATISTICS Confirmatory H13 paired-analysis contracts.

tests = functiontests(localfunctions);
end

function testSyntheticGoldCoversSuccessFailureAndInconclusive(testCase)
rows = makeSyntheticRows();
stats = mdt.computeH13Statistics(rows, 1000, 4000, 2026083101);

verifyEqual(testCase, stats.algorithmRuns, 450);
verifyEqual(testCase, stats.pairedSets, 90);
verifyEqual(testCase, string({stats.problems.problemId}), ...
    ["RCM06", "RCM19", "RCM25"]);
verifyEqual(testCase, string({stats.problems.branch}), ...
    ["success", "failure", "inconclusive"]);
for problem = stats.problems
    verifyEqual(testCase, numel(problem.comparisons), 4);
    verifyEqual(testCase, [problem.comparisons.nPairs], 30*ones(1, 4));
    verifyEqual(testCase, sort(string({problem.comparisons.baseline})), ...
        sort(["B1", "N2", "NSGAII", "CCMO"]));
    verifyGreaterThanOrEqual(testCase, ...
        [problem.comparisons.holmAdjustedP], ...
        [problem.comparisons.rawPermutationP]-1e-15);
end
rcm06 = stats.problems(1);
ccmo06 = rcm06.comparisons(string({rcm06.comparisons.baseline}) == "CCMO");
verifyGreaterThan(testCase, ccmo06.hodgesLehmann, 0);
verifyGreaterThan(testCase, ccmo06.bootstrapCi95(1), 0);
verifyLessThan(testCase, ccmo06.holmAdjustedP, 0.05);
rcm19 = stats.problems(2);
b119 = rcm19.comparisons(string({rcm19.comparisons.baseline}) == "B1");
verifyLessThanOrEqual(testCase, b119.hodgesLehmann, 0);
end

function testRowOrderDoesNotChangeStatistics(testCase)
rows = makeSyntheticRows();
forward = mdt.computeH13Statistics(rows, 400, 1000, 91);
reverse = mdt.computeH13Statistics(rows(end:-1:1, :), 400, 1000, 91);

for i = 1:numel(forward.problems)
    verifyEqual(testCase, ...
        [forward.problems(i).comparisons.hodgesLehmann], ...
        [reverse.problems(i).comparisons.hodgesLehmann], ...
        'AbsTol', 1e-15);
    verifyEqual(testCase, ...
        [forward.problems(i).comparisons.rawPermutationP], ...
        [reverse.problems(i).comparisons.rawPermutationP], ...
        'AbsTol', 1e-15);
end
end

function testMissingRunBlocksConfirmatoryAnalysis(testCase)
rows = makeSyntheticRows();
verifyError(testCase, @() mdt.computeH13Statistics(rows(1:end-1, :), ...
    100, 200, 7), 'mdt:InvalidH13ResultCoverage');
end

function testAnalysisWriterCreatesHashedNonOverwritingBundle(testCase)
base = string(tempname);
mkdir(base);
cleanup = onCleanup(@() removeTemp(base));
inputPath = fullfile(base, "results.csv");
outputDir = fullfile(base, "analysis");
writetable(makeSyntheticRows(), inputPath);

summary = mdt.runH13ResultAnalysis(inputPath, outputDir, 200, 800, 71);

verifyEqual(testCase, summary.status, "COMPLETE");
verifyEqual(testCase, summary.comparisons, 12);
verifyTrue(testCase, isfile(fullfile(outputDir, 'h13_statistics.json')));
verifyTrue(testCase, isfile(fullfile(outputDir, 'h13_comparisons.csv')));
verifyTrue(testCase, isfile(fullfile(outputDir, ...
    'h13_algorithm_summaries.csv')));
verifyTrue(testCase, isfile(fullfile(outputDir, 'analysis_manifest.json')));
verifyError(testCase, @() mdt.runH13ResultAnalysis( ...
    inputPath, outputDir, 10, 20, 71), 'mdt:H13AnalysisOutputCollision');
clear cleanup
end

function rows = makeSyntheticRows()
problems = ["RCM06", "RCM19", "RCM25"];
algorithms = ["B1", "B5S", "N2", "NSGAII", "CCMO"];
rows = table('Size', [450, 15], 'VariableTypes', ...
    {'string','string','double','double','double','double','double', ...
    'double','double','double','double','double','logical','string','string'}, ...
    'VariableNames', {'problemId','algorithm','seed','nominalBudget', ...
    'executionBudget','actualNfe','normalizedFeasibleHv', ...
    'finalFeasibleRate','feasibleNdSize','meanNormalizedCv', ...
    'runtimeSeconds','firstFeasibleNfe','feasibleEventObserved', ...
    'status','runId'});
cursor = 0;
for problem = problems
    for seed = 13001:13030
        jitter = (seed-13015)*1e-5;
        for algorithm = algorithms
            cursor = cursor+1;
            rows.problemId(cursor) = problem;
            rows.algorithm(cursor) = algorithm;
            rows.seed(cursor) = seed;
            rows.nominalBudget(cursor) = 20000;
            rows.executionBudget(cursor) = 20000;
            rows.actualNfe(cursor) = 20000;
            rows.normalizedFeasibleHv(cursor) = syntheticHv( ...
                problem, algorithm, seed)+jitter;
            rows.finalFeasibleRate(cursor) = 1;
            rows.feasibleNdSize(cursor) = 80;
            rows.meanNormalizedCv(cursor) = 0;
            rows.runtimeSeconds(cursor) = 1;
            rows.firstFeasibleNfe(cursor) = 100;
            rows.feasibleEventObserved(cursor) = true;
            rows.status(cursor) = "completed";
            rows.runId(cursor) = problem+"__"+algorithm+ ...
                "__seed-"+seed;
        end
    end
end
end

function value = syntheticHv(problem, algorithm, seed)
switch problem
    case "RCM06"
        values = struct('B1', 0.65, 'B5S', 0.70, 'N2', 0.62, ...
            'NSGAII', 0.63, 'CCMO', 0.60);
        slopes = struct('B1', 0, 'B5S', 0.002, 'N2', -0.0005, ...
            'NSGAII', 0.0005, 'CCMO', -0.001);
    case "RCM19"
        values = struct('B1', 0.52, 'B5S', 0.50, 'N2', 0.45, ...
            'NSGAII', 0.46, 'CCMO', 0.44);
        slopes = struct('B1', 0, 'B5S', 0, 'N2', 0, ...
            'NSGAII', 0, 'CCMO', 0);
    case "RCM25"
        values = struct('B1', 0.39, 'B5S', 0.40, 'N2', 0.38, ...
            'NSGAII', 0.39, 'CCMO', 0.40);
        slopes = struct('B1', 0, 'B5S', 0.001, 'N2', 0, ...
            'NSGAII', 0, 'CCMO', 0.001);
end
value = values.(char(algorithm))+ ...
    slopes.(char(algorithm))*(seed-13015);
end

function removeTemp(path)
if isfolder(path)
    rmdir(path, 's');
end
end
