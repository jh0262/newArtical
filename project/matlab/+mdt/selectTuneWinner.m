function winner = selectTuneWinner(rows)
%SELECTTUNEWINNER Select one configuration using the frozen robust lexicographic rule.

required = {'configId', 'seed', 'pcrAuc', 'finalPcr', 'finalHv', 'duplicateRate'};
if ~istable(rows) || ~all(ismember(required, rows.Properties.VariableNames)) || ...
        isempty(rows) || any(~isfinite(rows.seed)) || ...
        any(~isfinite(rows.pcrAuc)) || any(~isfinite(rows.finalPcr)) || ...
        any(~isfinite(rows.finalHv)) || any(~isfinite(rows.duplicateRate))
    error('mdt:InvalidTuneResults', ...
        'rows must contain finite configId/seed/PCR/HV/duplicate tuning results.');
end
rows.configId = string(rows.configId);
configIds = unique(rows.configId, 'sorted');
referenceSeeds = unique(rows.seed(rows.configId == configIds(1)), 'sorted');
if isempty(referenceSeeds)
    error('mdt:IncompleteTuneCoverage', 'Every configuration must have seed coverage.');
end

summary = table('Size', [numel(configIds), 6], ...
    'VariableTypes', {'string','double','double','double','double','double'}, ...
    'VariableNames', {'configId','medianPcrAuc','worstPcrAuc', ...
    'medianFinalPcr','medianFinalHv','medianDuplicateRate'});
for i = 1:numel(configIds)
    selected = rows.configId == configIds(i);
    seeds = unique(rows.seed(selected), 'sorted');
    if ~isequal(seeds, referenceSeeds) || sum(selected) ~= numel(referenceSeeds)
        error('mdt:IncompleteTuneCoverage', ...
            'Every configuration must contain exactly the same seed set once.');
    end
    summary.configId(i) = configIds(i);
    summary.medianPcrAuc(i) = median(rows.pcrAuc(selected));
    summary.worstPcrAuc(i) = min(rows.pcrAuc(selected));
    summary.medianFinalPcr(i) = median(rows.finalPcr(selected));
    summary.medianFinalHv(i) = median(rows.finalHv(selected));
    summary.medianDuplicateRate(i) = median(rows.duplicateRate(selected));
end

[~, order] = sortrows([-summary.medianPcrAuc, -summary.worstPcrAuc, ...
    -summary.medianFinalPcr, -summary.medianFinalHv, ...
    summary.medianDuplicateRate, double(categorical(summary.configId))]);
best = summary(order(1), :);
winner = struct();
winner.schema = "mdt.tune-winner.v0.1";
winner.configId = best.configId;
winner.medianPcrAuc = best.medianPcrAuc;
winner.worstPcrAuc = best.worstPcrAuc;
winner.medianFinalPcr = best.medianFinalPcr;
winner.medianFinalHv = best.medianFinalHv;
winner.medianDuplicateRate = best.medianDuplicateRate;
winner.selectionRule = [
    "max median AUC_PCR"
    "max worst-seed AUC_PCR"
    "max median final PCR"
    "max median final HV"
    "min median duplicate rate"
    "lexicographically smallest config ID"];
end

