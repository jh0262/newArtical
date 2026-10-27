function [nextX, nextObj, nextCon, info] = selectPopulation(X, obj, con, N, cfg)
%SELECTPOPULATION Feasibility-first deterministic environmental selection.

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
            [~, order] = sortrows([-frontCrowding, ...
                obj(frontIndices, :), X(frontIndices, :)]);
            selected = [selected; frontIndices(order(1:remainingSlots))]; %#ok<AGROW>
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
info.sourceIndices = selected;
info.feasibleMask = feasible(selected);
info.frontRank = frontRank(selected);
info.crowdingDistance = crowding(selected);
info.totalViolation = totalViolation(selected);
end

function value = constraintViolation(con, cfg)
value = max(con(:, 1), 0);
bandScale = 0.5-cfg.rho;
if bandScale > 0
    value = value + max(con(:, 2), 0)/bandScale;
end
end
