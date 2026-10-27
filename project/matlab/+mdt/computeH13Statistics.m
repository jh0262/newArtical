function stats = computeH13Statistics(rows, bootstrapReplicates, ...
    permutationReplicates, randomSeed)
%COMPUTEH13STATISTICS Frozen paired analysis for the H13 formal matrix.

arguments
    rows table
    bootstrapReplicates (1,1) double {mustBeInteger,mustBePositive} = 20000
    permutationReplicates (1,1) double {mustBeInteger,mustBePositive} = 50000
    randomSeed (1,1) double {mustBeInteger,mustBeNonnegative} = 2026083101
end

required = {'problemId','algorithm','seed','nominalBudget', ...
    'executionBudget','actualNfe','normalizedFeasibleHv', ...
    'finalFeasibleRate','feasibleNdSize','meanNormalizedCv', ...
    'runtimeSeconds','firstFeasibleNfe','feasibleEventObserved', ...
    'status','runId'};
if ~all(ismember(required, rows.Properties.VariableNames))
    error('mdt:InvalidH13Results', ...
        'H13 results are missing required columns.');
end
problems = ["RCM06", "RCM19", "RCM25"];
algorithms = ["B1", "B5S", "N2", "NSGAII", "CCMO"];
if height(rows) ~= 450 || ...
        ~isequal(sort(unique(string(rows.problemId))), sort(problems(:))) || ...
        ~isequal(sort(unique(string(rows.algorithm))), sort(algorithms(:))) || ...
        numel(unique(string(rows.runId))) ~= 450 || ...
        any(string(rows.status) ~= "completed")
    error('mdt:InvalidH13ResultCoverage', ...
        'H13 confirmatory analysis requires 450 unique completed runs.');
end
numericColumns = {'seed','nominalBudget','executionBudget','actualNfe', ...
    'normalizedFeasibleHv','finalFeasibleRate','feasibleNdSize', ...
    'meanNormalizedCv','runtimeSeconds','firstFeasibleNfe'};
for column = numericColumns
    if any(~isfinite(rows.(column{1})))
        error('mdt:InvalidH13Results', ...
            'H13 result columns must contain only finite values.');
    end
end
if any(rows.actualNfe ~= rows.executionBudget)
    error('mdt:InvalidH13Results', ...
        'H13 actual NFE must equal the frozen execution budget.');
end

problemCells = cell(1, numel(problems));
for problemIndex = 1:numel(problems)
    problemId = problems(problemIndex);
    subset = rows(string(rows.problemId) == problemId, :);
    seeds = sort(unique(subset.seed));
    if height(subset) ~= 150 || numel(seeds) ~= 30
        error('mdt:InvalidH13ResultCoverage', ...
            'Each H13 problem requires 30 five-algorithm paired sets.');
    end
    validatePairs(subset, seeds, algorithms);
    baselines = ["B1", "N2", "NSGAII", "CCMO"];
    comparisonCells = cell(1, numel(baselines));
    rawP = zeros(1, numel(baselines));
    for comparisonIndex = 1:numel(baselines)
        baseline = baselines(comparisonIndex);
        differences = pairedDifferences(subset, seeds, baseline);
        estimate = mdt.hodgesLehmannPaired(differences.hv);
        bootstrap = bootstrapHodgesLehmann(differences.hv, ...
            bootstrapReplicates, randomSeed+100*problemIndex+ ...
            comparisonIndex);
        ci = [empiricalQuantile(bootstrap, 0.025), ...
            empiricalQuantile(bootstrap, 0.975)];
        p = twoSidedSignFlipP(differences.hv, estimate, ...
            permutationReplicates, randomSeed+1000+ ...
            100*problemIndex+comparisonIndex);
        rawP(comparisonIndex) = p;
        item = struct();
        item.comparisonId = problemId+"__B5S-minus-"+baseline;
        item.baseline = baseline;
        item.nPairs = numel(seeds);
        item.hodgesLehmann = estimate;
        item.bootstrapCi95 = ci;
        item.rawPermutationP = p;
        item.holmAdjustedP = NaN;
        item.holmSignificant = false;
        item.meanDifference = mean(differences.hv);
        item.medianDifference = median(differences.hv);
        item.iqrDifference = empiricalQuantile(differences.hv, 0.75)- ...
            empiricalQuantile(differences.hv, 0.25);
        item.minimumDifference = min(differences.hv);
        item.maximumDifference = max(differences.hv);
        item.positivePairs = sum(differences.hv > 0);
        item.negativePairs = sum(differences.hv < 0);
        item.zeroPairs = sum(differences.hv == 0);
        item.secondary = secondarySummary(differences);
        comparisonCells{comparisonIndex} = item;
    end
    adjusted = mdt.holmAdjust(rawP);
    comparisons = [comparisonCells{:}];
    for comparisonIndex = 1:numel(comparisons)
        comparisons(comparisonIndex).holmAdjustedP = ...
            adjusted(comparisonIndex);
        comparisons(comparisonIndex).holmSignificant = ...
            adjusted(comparisonIndex) < 0.05;
    end
    b1 = comparisons(string({comparisons.baseline}) == "B1");
    ccmo = comparisons(string({comparisons.baseline}) == "CCMO");
    success = ccmo.hodgesLehmann > 0 && ...
        ccmo.bootstrapCi95(1) > 0 && ccmo.holmAdjustedP < 0.05 && ...
        b1.hodgesLehmann > 0;
    failure = (ccmo.holmAdjustedP < 0.05 && ...
        ccmo.bootstrapCi95(2) < 0) || b1.hodgesLehmann <= 0;
    branch = "inconclusive";
    if success
        branch = "success";
    elseif failure
        branch = "failure";
    end
    problem = struct();
    problem.hypothesisId = "H13-"+problemId;
    problem.problemId = problemId;
    problem.nSeeds = numel(seeds);
    problem.familyId = problemId+"-B5S-four-baselines";
    problem.multiplicityCorrection = "Holm";
    problem.comparisons = comparisons;
    problem.algorithmSummaries = summarizeAlgorithms(subset, algorithms);
    problem.branch = branch;
    problem.successConditionMet = success;
    problem.failureConditionMet = failure;
    problemCells{problemIndex} = problem;
end

stats = struct();
stats.schema = "mdt.h13-statistics.v1.0";
stats.scope = "CONFIRMATORY_FROZEN_H13";
stats.unitOfAnalysis = "problem-matched paired seed";
stats.primaryMetric = "final normalized feasible HV";
stats.test = "two-sided Monte Carlo paired sign-flip on Hodges-Lehmann";
stats.ci = "paired percentile bootstrap of Hodges-Lehmann";
stats.multiplicityCorrection = "Holm within each problem family";
stats.algorithmRuns = height(rows);
stats.pairedSets = 90;
stats.bootstrapReplicates = bootstrapReplicates;
stats.permutationReplicates = permutationReplicates;
stats.randomSeed = randomSeed;
stats.problems = [problemCells{:}];
end

function validatePairs(rows, seeds, algorithms)
for seed = seeds'
    paired = rows(rows.seed == seed, :);
    if height(paired) ~= 5 || ...
            ~isequal(sort(string(paired.algorithm)), sort(algorithms(:))) || ...
            numel(unique(paired.executionBudget)) ~= 1 || ...
            numel(unique(paired.problemId)) ~= 1
        error('mdt:InvalidH13ResultCoverage', ...
            'Every H13 pair must contain five matched algorithms.');
    end
end
end

function differences = pairedDifferences(rows, seeds, baseline)
n = numel(seeds);
differences = table('Size', [n, 7], 'VariableTypes', ...
    {'double','double','double','double','double','double','double'}, ...
    'VariableNames', {'seed','hv','feasibleRate','feasibleNdSize', ...
    'meanNormalizedCv','runtimeSeconds','firstFeasibleNfe'});
for i = 1:n
    paired = rows(rows.seed == seeds(i), :);
    candidate = paired(string(paired.algorithm) == "B5S", :);
    control = paired(string(paired.algorithm) == baseline, :);
    if height(candidate) ~= 1 || height(control) ~= 1
        error('mdt:InvalidH13ResultCoverage', ...
            'Each seed requires one B5S and one baseline result.');
    end
    differences.seed(i) = seeds(i);
    differences.hv(i) = candidate.normalizedFeasibleHv- ...
        control.normalizedFeasibleHv;
    differences.feasibleRate(i) = candidate.finalFeasibleRate- ...
        control.finalFeasibleRate;
    differences.feasibleNdSize(i) = candidate.feasibleNdSize- ...
        control.feasibleNdSize;
    differences.meanNormalizedCv(i) = candidate.meanNormalizedCv- ...
        control.meanNormalizedCv;
    differences.runtimeSeconds(i) = candidate.runtimeSeconds- ...
        control.runtimeSeconds;
    differences.firstFeasibleNfe(i) = candidate.firstFeasibleNfe- ...
        control.firstFeasibleNfe;
end
end

function summary = secondarySummary(differences)
summary = struct( ...
    'hodgesLehmannFeasibleRate', ...
    mdt.hodgesLehmannPaired(differences.feasibleRate), ...
    'hodgesLehmannFeasibleNdSize', ...
    mdt.hodgesLehmannPaired(differences.feasibleNdSize), ...
    'hodgesLehmannMeanNormalizedCv', ...
    mdt.hodgesLehmannPaired(differences.meanNormalizedCv), ...
    'hodgesLehmannRuntimeSeconds', ...
    mdt.hodgesLehmannPaired(differences.runtimeSeconds), ...
    'hodgesLehmannFirstFeasibleNfe', ...
    mdt.hodgesLehmannPaired(differences.firstFeasibleNfe));
end

function summaries = summarizeAlgorithms(rows, algorithms)
cells = cell(1, numel(algorithms));
for i = 1:numel(algorithms)
    subset = rows(string(rows.algorithm) == algorithms(i), :);
    item = struct();
    item.algorithm = algorithms(i);
    item.n = height(subset);
    item.meanHv = mean(subset.normalizedFeasibleHv);
    item.standardDeviationHv = std(subset.normalizedFeasibleHv);
    item.medianHv = median(subset.normalizedFeasibleHv);
    item.iqrHv = empiricalQuantile(subset.normalizedFeasibleHv, 0.75)- ...
        empiricalQuantile(subset.normalizedFeasibleHv, 0.25);
    item.minimumHv = min(subset.normalizedFeasibleHv);
    item.maximumHv = max(subset.normalizedFeasibleHv);
    item.meanFeasibleRate = mean(subset.finalFeasibleRate);
    item.meanFeasibleNdSize = mean(subset.feasibleNdSize);
    item.meanNormalizedCv = mean(subset.meanNormalizedCv);
    item.medianRuntimeSeconds = median(subset.runtimeSeconds);
    item.medianFirstFeasibleNfe = median(subset.firstFeasibleNfe);
    cells{i} = item;
end
summaries = [cells{:}];
end

function values = bootstrapHodgesLehmann(differences, count, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
n = numel(differences);
values = zeros(count, 1);
for replicate = 1:count
    sample = differences(randi(stream, n, n, 1));
    values(replicate) = mdt.hodgesLehmannPaired(sample);
end
end

function p = twoSidedSignFlipP(differences, observed, count, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
exceed = 0;
tolerance = 16*eps(max(1, abs(observed)));
for replicate = 1:count
    signs = 2*(rand(stream, numel(differences), 1) >= 0.5)-1;
    permuted = mdt.hodgesLehmannPaired(differences.*signs);
    exceed = exceed+(abs(permuted) >= abs(observed)-tolerance);
end
p = (exceed+1)/(count+1);
end

function value = empiricalQuantile(values, probability)
values = sort(values(:));
position = 1+(numel(values)-1)*probability;
lower = floor(position);
upper = ceil(position);
if lower == upper
    value = values(lower);
else
    weight = position-lower;
    value = (1-weight)*values(lower)+weight*values(upper);
end
end
