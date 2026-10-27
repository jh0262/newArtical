function stats = computeH6Statistics(rows, bootstrapReplicates, ...
    permutationReplicates, randomSeed)
%COMPUTEH6STATISTICS Frozen H6 paired effects, CI and Holm correction.

arguments
    rows table
    bootstrapReplicates (1,1) double {mustBeInteger,mustBePositive} = 20000
    permutationReplicates (1,1) double {mustBeInteger,mustBePositive} = 50000
    randomSeed (1,1) double {mustBeInteger,mustBeNonnegative} = 83090
end
required = {'instanceId','algorithm','seed','setId','pcrAuc', ...
    'finalPcr','finalHv','runtimeSeconds'};
if ~all(ismember(required, rows.Properties.VariableNames))
    error('mdt:InvalidH6Results', ...
        'H6 results are missing required columns.');
end
expectedAlgorithms = ["B1"; "B4F"; "B4R"; "B4"; "N2"];
if ~isequal(sort(unique(string(rows.algorithm))), sort(expectedAlgorithms))
    error('mdt:InvalidH6Results', ...
        'H6 results must contain B1/B4F/B4R/B4/N2 only.');
end

instances = unique(string(rows.instanceId), 'stable');
baselines = ["N2", "B1", "B4F", "B4R"];
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
        item = struct('instanceId', instances(instanceIndex), ...
            'nPairs', height(differences), ...
            'hodgesLehmannAuc', mdt.hodgesLehmannPaired(differences.auc), ...
            'medianAuc', median(differences.auc), ...
            'meanAuc', mean(differences.auc), ...
            'minimumAuc', min(differences.auc), ...
            'maximumAuc', max(differences.auc), ...
            'positivePairs', sum(differences.auc > 0), ...
            'negativePairs', sum(differences.auc < 0), ...
            'zeroPairs', sum(differences.auc == 0), ...
            'hodgesLehmannFinalPcr', ...
            mdt.hodgesLehmannPaired(differences.finalPcr), ...
            'hodgesLehmannFinalHv', ...
            mdt.hodgesLehmannPaired(differences.finalHv), ...
            'medianRuntimeRatio', median(differences.runtimeRatio));
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
    comparisonCells{comparisonIndex} = struct( ...
        'comparisonId', "B4-minus-" + baseline, ...
        'baseline', baseline, 'byInstance', byInstance, ...
        'overallEstimand', overall, 'bootstrapCi95', ci, ...
        'rawPermutationP', p, 'holmAdjustedP', NaN, ...
        'ciLowerPositive', ci(1) > 0, ...
        'overallFinalPcrShift', overallPcr, ...
        'overallFinalHvShift', overallHv, ...
        'finalPcrGuardrailPassed', overallPcr >= -0.02, ...
        'hvGuardrailPassed', overallHv >= -0.01, ...
        'medianRuntimeRatio', median([byInstance.medianRuntimeRatio]));
end

comparisons = [comparisonCells{:}];
adjusted = mdt.holmAdjust(rawP);
for i = 1:numel(comparisons)
    comparisons(i).holmAdjustedP = adjusted(i);
    comparisons(i).holmSignificant = adjusted(i) < 0.05;
    comparisons(i).statisticallyPositive = ...
        comparisons(i).ciLowerPositive && comparisons(i).holmSignificant;
    comparisons(i).practicalThreshold = double(ismember( ...
        comparisons(i).baseline, ["N2", "B1"]))*0.01;
    comparisons(i).practicalThresholdPassed = ...
        mdt.exceedsPracticalThreshold(comparisons(i).overallEstimand, ...
        comparisons(i).practicalThreshold);
    comparisons(i).claimReady = comparisons(i).statisticallyPositive && ...
        comparisons(i).practicalThresholdPassed && ...
        comparisons(i).finalPcrGuardrailPassed && ...
        comparisons(i).hvGuardrailPassed;
end

stats = struct('schema', "mdt.h6-statistics.v0.1", ...
    'scope', "H6_FROZEN_GENERALIZATION_AND_ABLATION", ...
    'instances', numel(instances), ...
    'seedsPerInstance', height(rows)/(numel(instances)*5), ...
    'algorithmRuns', height(rows), ...
    'bootstrapReplicates', bootstrapReplicates, ...
    'permutationReplicates', permutationReplicates, ...
    'randomSeed', randomSeed, 'multiplicityCorrection', "Holm", ...
    'comparisons', comparisons);
end

function differences = pairDifferences(subset, setIds, baseline)
differences = table('Size', [numel(setIds), 5], 'VariableTypes', ...
    {'string','double','double','double','double'}, 'VariableNames', ...
    {'setId','auc','finalPcr','finalHv','runtimeRatio'});
for i = 1:numel(setIds)
    setRows = subset(string(subset.setId) == setIds(i), :);
    b4 = setRows(string(setRows.algorithm) == "B4", :);
    control = setRows(string(setRows.algorithm) == baseline, :);
    if height(b4) ~= 1 || height(control) ~= 1 || b4.seed ~= control.seed
        error('mdt:InvalidH6SetCoverage', ...
            'Each H6 set requires one seed-matched B4 and baseline row.');
    end
    differences.setId(i) = setIds(i);
    differences.auc(i) = b4.pcrAuc-control.pcrAuc;
    differences.finalPcr(i) = b4.finalPcr-control.finalPcr;
    differences.finalHv(i) = b4.finalHv-control.finalHv;
    differences.runtimeRatio(i) = b4.runtimeSeconds/control.runtimeSeconds;
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
