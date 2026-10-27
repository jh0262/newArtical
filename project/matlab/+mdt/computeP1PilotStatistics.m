function stats = computeP1PilotStatistics(rows, bootstrapReplicates, bootstrapSeed)
%COMPUTEP1PILOTSTATISTICS Describe the frozen stratified EXP-P1 pilot.

arguments
    rows table
    bootstrapReplicates (1,1) double {mustBeInteger,mustBePositive} = 20000
    bootstrapSeed (1,1) double {mustBeInteger,mustBeNonnegative} = 2026083001
end

required = {'instanceId','algorithm','seed','pairId','pcrAuc', ...
    'finalPcr','finalHv','duplicateRate','noFeasibleCheckpointRate'};
if ~all(ismember(required, rows.Properties.VariableNames))
    error('mdt:InvalidP1Results', 'P1 result table is missing required columns.');
end
if any(~ismember(string(rows.algorithm), ["B0", "B1"]))
    error('mdt:InvalidP1Results', 'P1 rows must contain only B0 and B1.');
end

instanceIds = unique(string(rows.instanceId), 'stable');
byInstanceCells = cell(1, numel(instanceIds));
aucDifferences = cell(1, numel(instanceIds));
feasibilityFailurePairs = 0;
totalPairs = 0;

for i = 1:numel(instanceIds)
    subset = rows(string(rows.instanceId) == instanceIds(i), :);
    pairIds = unique(string(subset.pairId), 'stable');
    differences = makeDifferenceTable(subset, pairIds);
    aucDifferences{i} = differences.pcrAuc;
    totalPairs = totalPairs+height(differences);
    feasibilityFailurePairs = feasibilityFailurePairs + ...
        sum(differences.anyNeverFeasible);

    item = struct();
    item.instanceId = instanceIds(i);
    item.nPairs = height(differences);
    item.hodgesLehmannAuc = mdt.hodgesLehmannPaired(differences.pcrAuc);
    item.medianAucDifference = median(differences.pcrAuc);
    item.meanAucDifference = mean(differences.pcrAuc);
    item.minAucDifference = min(differences.pcrAuc);
    item.maxAucDifference = max(differences.pcrAuc);
    item.positiveAucPairs = sum(differences.pcrAuc > 0);
    item.negativeAucPairs = sum(differences.pcrAuc < 0);
    item.zeroAucPairs = sum(differences.pcrAuc == 0);
    item.hodgesLehmannFinalPcr = ...
        mdt.hodgesLehmannPaired(differences.finalPcr);
    item.hodgesLehmannFinalHv = ...
        mdt.hodgesLehmannPaired(differences.finalHv);
    item.hodgesLehmannDuplicateRate = ...
        mdt.hodgesLehmannPaired(differences.duplicateRate);
    item.minimumPairId = differences.pairId( ...
        find(differences.pcrAuc == min(differences.pcrAuc), 1));
    byInstanceCells{i} = item;
end

byInstance = [byInstanceCells{:}];
instanceEstimates = [byInstance.hodgesLehmannAuc];
overallEstimand = median(instanceEstimates);
stream = RandStream('mt19937ar', 'Seed', bootstrapSeed);
bootstrap = zeros(bootstrapReplicates, 1);
for replicate = 1:bootstrapReplicates
    estimates = zeros(1, numel(aucDifferences));
    for i = 1:numel(aucDifferences)
        d = aucDifferences{i};
        sample = d(randi(stream, numel(d), numel(d), 1));
        estimates(i) = mdt.hodgesLehmannPaired(sample);
    end
    bootstrap(replicate) = median(estimates);
end

allAuc = vertcat(aucDifferences{:});
stats = struct();
stats.schema = "mdt.p1-pilot-statistics.v0.1";
stats.scope = "PILOT_DESCRIPTIVE_NOT_H2_CONFIRMATION";
stats.instances = numel(instanceIds);
stats.pairs = totalPairs;
stats.algorithmRuns = height(rows);
stats.byInstance = byInstance;
stats.overallEstimand = overallEstimand;
stats.bootstrapCi95 = [empiricalQuantile(bootstrap, 0.025), ...
    empiricalQuantile(bootstrap, 0.975)];
stats.bootstrapReplicates = bootstrapReplicates;
stats.bootstrapSeed = bootstrapSeed;
stats.overallPairMedian = median(allAuc);
stats.overallPairMean = mean(allAuc);
stats.positivePairs = sum(allAuc > 0);
stats.negativePairs = sum(allAuc < 0);
stats.zeroPairs = sum(allAuc == 0);
stats.minimumAucDifference = min(allAuc);
stats.maximumAucDifference = max(allAuc);
stats.ceiling = struct( ...
    'finalPcrOneRateB0', mean(rows.finalPcr(string(rows.algorithm) == "B0") == 1), ...
    'finalPcrOneRateB1', mean(rows.finalPcr(string(rows.algorithm) == "B1") == 1), ...
    'aucAbove098RateB0', mean(rows.pcrAuc(string(rows.algorithm) == "B0") >= 0.98), ...
    'aucAbove098RateB1', mean(rows.pcrAuc(string(rows.algorithm) == "B1") >= 0.98));
stats.guardrails = struct( ...
    'feasibilityFailurePairs', feasibilityFailurePairs, ...
    'feasibilityFailureRate', feasibilityFailurePairs/totalPairs, ...
    'feasibilityPass', feasibilityFailurePairs/totalPairs <= 0.20);
end

function differences = makeDifferenceTable(subset, pairIds)
count = numel(pairIds);
differences = table('Size', [count, 6], 'VariableTypes', ...
    {'string','double','double','double','double','logical'}, ...
    'VariableNames', {'pairId','pcrAuc','finalPcr','finalHv', ...
    'duplicateRate','anyNeverFeasible'});
for i = 1:count
    pair = subset(string(subset.pairId) == pairIds(i), :);
    b0 = pair(string(pair.algorithm) == "B0", :);
    b1 = pair(string(pair.algorithm) == "B1", :);
    if height(b0) ~= 1 || height(b1) ~= 1 || b0.seed ~= b1.seed
        error('mdt:InvalidP1PairCoverage', ...
            'Every pair ID must contain exactly one seed-matched B0 and B1 row.');
    end
    differences.pairId(i) = pairIds(i);
    differences.pcrAuc(i) = b1.pcrAuc-b0.pcrAuc;
    differences.finalPcr(i) = b1.finalPcr-b0.finalPcr;
    differences.finalHv(i) = b1.finalHv-b0.finalHv;
    differences.duplicateRate(i) = b1.duplicateRate-b0.duplicateRate;
    differences.anyNeverFeasible(i) = ...
        b0.noFeasibleCheckpointRate == 1 || ...
        b1.noFeasibleCheckpointRate == 1;
end
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
