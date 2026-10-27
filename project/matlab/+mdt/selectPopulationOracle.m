function [nextX, nextObj, nextCon, info] = selectPopulationOracle( ...
    X, obj, con, N, cfg, minimumQuota)
%SELECTPOPULATIONORACLE Diagnostic upper bound with true-component quotas.

count = validateEvaluatedCandidates(X, obj, con, cfg);
if ~isscalar(N) || ~isfinite(N) || N < 1 || N > count || N ~= floor(N)
    error('mdt:InvalidSelectionSize', ...
        'N must be a positive integer no greater than the candidate count.');
end
if ~isscalar(minimumQuota) || ~isfinite(minimumQuota) || ...
        minimumQuota < 1 || minimumQuota ~= floor(minimumQuota)
    error('mdt:InvalidComponentQuota', ...
        'minimumQuota must be a positive integer.');
end

truth = mdt.enumerateTruth(cfg);
relevant = find(truth.paretoRelevantByComponent);
if minimumQuota*numel(relevant) > floor(N/2)
    error('mdt:OracleQuotaExceedsCapacity', ...
        'The frozen oracle quota exceeds half of the population capacity.');
end

feasible = all(con <= 0, 2);
componentId = zeros(count, 1);
if any(feasible)
    powers = cfg.q.^((cfg.L-1):-1:0);
    ranks = round(X(feasible, 3:end))*powers';
    componentId(feasible) = truth.componentIdByState(ranks+1);
end

protected = zeros(0, 1);
for component = reshape(relevant, 1, [])
    candidates = find(feasible & componentId == component);
    quota = min(minimumQuota, numel(candidates));
    if quota == 0
        continue;
    end
    [~, ~, ~, localInfo] = mdt.selectPopulation( ...
        X(candidates, :), obj(candidates, :), con(candidates, :), quota, cfg);
    protected = [protected; candidates(localInfo.sourceIndices)]; %#ok<AGROW>
end
protected = unique(protected, 'stable');

remainingMask = true(count, 1);
remainingMask(protected) = false;
remaining = find(remainingMask);
needed = N-numel(protected);
if needed > 0
    [~, ~, ~, fillInfo] = mdt.selectPopulation( ...
        X(remaining, :), obj(remaining, :), con(remaining, :), needed, cfg);
    selected = [protected; remaining(fillInfo.sourceIndices)];
else
    selected = protected;
end

nextX = X(selected, :);
nextObj = obj(selected, :);
nextCon = con(selected, :);
info = struct();
info.schema = "mdt.environmental-selection.v0.1";
info.strategy = "oracle_component_protection";
info.truthUsedBySelection = true;
info.minimumQuota = minimumQuota;
info.sourceIndices = selected;
info.protectedMask = ismember(selected, protected);
info.protectedCount = numel(protected);
info.selectedComponentIds = componentId(selected);
info.representedRelevantComponents = ...
    unique(componentId(feasible & ismember(componentId, relevant)));
end
