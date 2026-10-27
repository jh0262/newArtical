function stats = computeH5ConfirmStatistics( ...
    rows, bootstrapReplicates, permutationReplicates, randomSeed)
%COMPUTEH5CONFIRMSTATISTICS Frozen H5 effect, CI and multiplicity analysis.

arguments
    rows table
    bootstrapReplicates (1,1) double {mustBeInteger,mustBePositive} = 20000
    permutationReplicates (1,1) double {mustBeInteger,mustBePositive} = 50000
    randomSeed (1,1) double {mustBeInteger,mustBeNonnegative} = 2026090501
end
required = {'instanceId','algorithm','seed','setId','pcrAuc', ...
    'finalPcr','finalHv'};
if ~all(ismember(required, rows.Properties.VariableNames))
    error('mdt:InvalidH5Results', 'H5 results are missing required columns.');
end
algorithms = unique(string(rows.algorithm));
if ~isequal(sort(algorithms), sort(["B0"; "B1"; "B2"; "B4"]))
    error('mdt:InvalidH5Results', 'H5 results must contain B0/B1/B2/B4 only.');
end

instances = unique(string(rows.instanceId), 'stable');
baselines = ["B0", "B1", "B2"];
comparisonCells = cell(1, numel(baselines));
rawP = zeros(1, numel(baselines));
for comparisonIndex = 1:numel(baselines)
    baseline = baselines(comparisonIndex);
    aucByInstance = cell(1, numel(instances));
    byInstanceCells = cell(1, numel(instances));
    for instanceIndex = 1:numel(instances)
        subset = rows(string(rows.instanceId) == instances(instanceIndex), :);
        setIds = unique(string(subset.setId), 'stable');
        differences = pairDifferences(subset, setIds, baseline);
        aucByInstance{instanceIndex} = differences.auc;
        item = struct();
        item.instanceId = instances(instanceIndex);
        item.nPairs = height(differences);
        item.hodgesLehmannAuc = mdt.hodgesLehmannPaired(differences.auc);
        item.medianAuc = median(differences.auc);
        item.meanAuc = mean(differences.auc);
        item.minimumAuc = min(differences.auc);
        item.maximumAuc = max(differences.auc);
        item.positivePairs = sum(differences.auc > 0);
        item.negativePairs = sum(differences.auc < 0);
        item.zeroPairs = sum(differences.auc == 0);
        item.hodgesLehmannFinalPcr = ...
            mdt.hodgesLehmannPaired(differences.finalPcr);
        item.hodgesLehmannFinalHv = ...
            mdt.hodgesLehmannPaired(differences.finalHv);
        byInstanceCells{instanceIndex} = item;
    end
    byInstance = [byInstanceCells{:}];
    overall = median([byInstance.hodgesLehmannAuc]);
    overallPcr = median([byInstance.hodgesLehmannFinalPcr]);
    overallHv = median([byInstance.hodgesLehmannFinalHv]);
    bootstrap = stratifiedBootstrap(aucByInstance, bootstrapReplicates, ...
        randomSeed+comparisonIndex-1);
    ci = [empiricalQuantile(bootstrap, 0.025), ...
        empiricalQuantile(bootstrap, 0.975)];
    p = stratifiedSignFlipP(aucByInstance, overall, ...
        permutationReplicates, randomSeed+100+comparisonIndex);
    rawP(comparisonIndex) = p;

    comparison = struct();
    comparison.comparisonId = "B4-minus-" + baseline;
    comparison.baseline = baseline;
    comparison.byInstance = byInstance;
    comparison.overallEstimand = overall;
    comparison.bootstrapCi95 = ci;
    comparison.rawPermutationP = p;
    comparison.holmAdjustedP = NaN;
    comparison.practicalThreshold = 0.01;
    comparison.practicalThresholdPassed = ...
        mdt.exceedsPracticalThreshold(overall, 0.01);
    comparison.ciLowerPositive = ci(1) > 0;
    comparison.overallFinalPcrShift = overallPcr;
    comparison.overallFinalHvShift = overallHv;
    comparison.hvGuardrailPassed = overallHv >= -0.01;
    comparison.finalPcrGuardrailPassed = overallPcr >= 0;
    comparisonCells{comparisonIndex} = comparison;
end

adjusted = mdt.holmAdjust(rawP);
comparisons = [comparisonCells{:}];
for i = 1:numel(comparisons)
    comparisons(i).holmAdjustedP = adjusted(i);
    comparisons(i).holmSignificant = adjusted(i) < 0.05;
    comparisons(i).claimReady = comparisons(i).practicalThresholdPassed && ...
        comparisons(i).ciLowerPositive && comparisons(i).holmSignificant && ...
        comparisons(i).hvGuardrailPassed && ...
        comparisons(i).finalPcrGuardrailPassed;
end

stats = struct();
stats.schema = "mdt.h5-confirm-statistics.v0.1";
stats.scope = "CONFIRMATORY_FIXED_DESIGN";
stats.instances = numel(instances);
stats.seedsPerInstance = height(rows)/(numel(instances)*4);
stats.algorithmRuns = height(rows);
stats.bootstrapReplicates = bootstrapReplicates;
stats.permutationReplicates = permutationReplicates;
stats.randomSeed = randomSeed;
stats.multiplicityCorrection = "Holm";
stats.comparisons = comparisons;
stats.allComparisonsPracticalAndPositive = all([comparisons.claimReady]);
end

function differences = pairDifferences(subset, setIds, baseline)
differences = table('Size', [numel(setIds), 4], 'VariableTypes', ...
    {'string','double','double','double'}, 'VariableNames', ...
    {'setId','auc','finalPcr','finalHv'});
for i = 1:numel(setIds)
    setRows = subset(string(subset.setId) == setIds(i), :);
    b4 = setRows(string(setRows.algorithm) == "B4", :);
    control = setRows(string(setRows.algorithm) == baseline, :);
    if height(b4) ~= 1 || height(control) ~= 1 || b4.seed ~= control.seed
        error('mdt:InvalidH5SetCoverage', ...
            'Each set must have one seed-matched B4 and baseline row.');
    end
    differences.setId(i) = setIds(i);
    differences.auc(i) = b4.pcrAuc-control.pcrAuc;
    differences.finalPcr(i) = b4.finalPcr-control.finalPcr;
    differences.finalHv(i) = b4.finalHv-control.finalHv;
end
end

function values = stratifiedBootstrap(differences, count, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
values = zeros(count, 1);
for replicate = 1:count
    estimates = zeros(1, numel(differences));
    for i = 1:numel(differences)
        d = differences{i};
        sample = d(randi(stream, numel(d), numel(d), 1));
        estimates(i) = mdt.hodgesLehmannPaired(sample);
    end
    values(replicate) = median(estimates);
end
end

function p = stratifiedSignFlipP(differences, observed, count, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
exceed = 0;
for replicate = 1:count
    estimates = zeros(1, numel(differences));
    for i = 1:numel(differences)
        d = differences{i};
        signs = 2*(rand(stream, numel(d), 1) >= 0.5)-1;
        estimates(i) = mdt.hodgesLehmannPaired(d.*signs);
    end
    exceed = exceed + (median(estimates) >= observed);
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
