function [nextX, nextObj, nextCon, info] = selectPopulationNiching( ...
    X, obj, con, N, cfg)
%SELECTPOPULATIONNICHING Feasibility-first selection with mixed-space niching.

count = validateEvaluatedCandidates(X, obj, con, cfg);
if ~isscalar(N) || ~isfinite(N) || N < 1 || N > count || N ~= floor(N)
    error('mdt:InvalidSelectionSize', ...
        'N must be a positive integer no greater than the candidate count.');
end

feasible = all(con <= 0, 2);
selected = zeros(0, 1);
frontRank = Inf(count, 1);
crowding = zeros(count, 1);
feasibleIndices = find(feasible);
normalizedX = normalizeMixedDecision(X, cfg);

if ~isempty(feasibleIndices)
    [fronts, localRank] = nondominatedFronts(obj(feasibleIndices, :));
    frontRank(feasibleIndices) = localRank;
    for frontNumber = 1:numel(fronts)
        frontIndices = feasibleIndices(fronts{frontNumber});
        frontCrowding = crowdingDistance(obj(frontIndices, :), X(frontIndices, :));
        crowding(frontIndices) = frontCrowding;
        remainingSlots = N-numel(selected);
        if remainingSlots <= 0
            break;
        end
        if numel(frontIndices) <= remainingSlots
            [~, order] = sortrows([obj(frontIndices, :), X(frontIndices, :)]);
            selected = [selected; frontIndices(order)]; %#ok<AGROW>
        else
            chosen = maximinTruncate(frontIndices, remainingSlots, selected, ...
                normalizedX, frontCrowding, obj, X);
            selected = [selected; chosen]; %#ok<AGROW>
            break;
        end
    end
end

totalViolation = constraintViolation(con, cfg);
if numel(selected) < N
    infeasibleIndices = find(~feasible);
    [~, order] = sortrows([totalViolation(infeasibleIndices), ...
        obj(infeasibleIndices, :), X(infeasibleIndices, :)]);
    needed = N-numel(selected);
    selected = [selected; infeasibleIndices(order(1:needed))];
end

nextX = X(selected, :);
nextObj = obj(selected, :);
nextCon = con(selected, :);
info = struct();
info.schema = "mdt.environmental-selection.v0.1";
info.strategy = "ordinary_decision_niching";
info.truthUsedBySelection = false;
info.sourceIndices = selected;
info.feasibleMask = feasible(selected);
info.frontRank = frontRank(selected);
info.crowdingDistance = crowding(selected);
info.totalViolation = totalViolation(selected);
end

function chosen = maximinTruncate(candidates, slots, alreadySelected, ...
    normalizedX, crowding, obj, X)
chosen = zeros(0, 1);
available = candidates(:);
crowdingByIndex = zeros(size(X, 1), 1);
crowdingByIndex(candidates) = crowding;

while numel(chosen) < slots
    reference = [alreadySelected; chosen];
    if isempty(reference)
        score = crowdingByIndex(available);
        score(isinf(score)) = realmax;
        [~, order] = sortrows([-score, obj(available, :), X(available, :)]);
    else
        minimumDistance = zeros(numel(available), 1);
        for i = 1:numel(available)
            delta = normalizedX(reference, :) - normalizedX(available(i), :);
            minimumDistance(i) = min(sqrt(sum(delta.^2, 2)));
        end
        crowdingScore = crowdingByIndex(available);
        crowdingScore(isinf(crowdingScore)) = realmax;
        [~, order] = sortrows([-minimumDistance, -crowdingScore, ...
            obj(available, :), X(available, :)]);
    end
    chosen(end+1, 1) = available(order(1)); %#ok<AGROW>
    available(order(1)) = [];
end
end

function normalized = normalizeMixedDecision(X, cfg)
normalized = X;
if cfg.q > 1
    normalized(:, 3:4) = X(:, 3:4)/(cfg.q-1);
end
for j = 5:size(X, 2)
    normalized(:, j) = double(X(:, j) ~= 0);
end
% Categorical coordinates are replaced below by label-invariant one-hot blocks.
if cfg.L > 2
    base = normalized(:, 1:4);
    categorical = zeros(size(X, 1), (cfg.L-2)*cfg.q);
    cursor = 0;
    for j = 5:size(X, 2)
        levels = round(X(:, j))+1;
        block = zeros(size(X, 1), cfg.q);
        block(sub2ind(size(block), (1:size(X, 1))', levels)) = 1/sqrt(2);
        categorical(:, cursor+(1:cfg.q)) = block;
        cursor = cursor+cfg.q;
    end
    normalized = [base, categorical];
end
end

function value = constraintViolation(con, cfg)
value = max(con(:, 1), 0);
bandScale = 0.5-cfg.rho;
if bandScale > 0
    value = value + max(con(:, 2), 0)/bandScale;
end
end
