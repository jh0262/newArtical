function diag = computeDiagnostics(X, obj, con, cfg, truth)
%COMPUTEDIAGNOSTICS Compute PCR and phenotype/constraint diagnostics.

N = size(X, 1);
if N < 1 || size(X, 2) ~= 2+cfg.L || size(obj, 1) ~= N || ...
        size(obj, 2) ~= 2 || size(con, 1) ~= N || size(con, 2) < 2 || ...
        any(~isfinite(X), 'all') || any(~isfinite(obj), 'all') || ...
        any(~isfinite(con), 'all')
    error('mdt:InvalidDiagnosticInput', 'X, obj, and con have incompatible shapes or values.');
end

feasible = all(con <= 0, 2);
nondominated = false(N, 1);
feasibleIndices = find(feasible);
for localI = 1:numel(feasibleIndices)
    i = feasibleIndices(localI);
    dominated = false;
    for localJ = 1:numel(feasibleIndices)
        j = feasibleIndices(localJ);
        if i ~= j && all(obj(j, :) <= obj(i, :)) && any(obj(j, :) < obj(i, :))
            dominated = true;
            break;
        end
    end
    nondominated(i) = ~dominated;
end

d = round(X(:, 3:end));
powers = cfg.q.^((cfg.L-1):-1:0);
externalRank = d*powers';
componentIds = truth.componentIdByState(externalRank+1);
hitComponents = false(truth.nComponents, 1);
eligible = nondominated & componentIds > 0;
hitComponents(unique(componentIds(eligible))) = true;
hitParetoComponents = hitComponents & truth.paretoRelevantByComponent;

diag = struct();
diag.schema = "mdt.diagnostics.v0.1";
diag.feasibleMask = feasible;
diag.nondominatedMask = nondominated;
diag.componentIdByCandidate = componentIds;
diag.hitParetoComponents = hitParetoComponents;
diag.paretoComponentRecall = sum(hitParetoComponents)/truth.nParetoRelevantComponents;
diag.duplicateRate = (N-size(unique(X, 'rows'), 1))/N;
diag.discreteConstraintInvalidRate = mean(con(:, 1) > 0);
diag.bandConstraintInvalidRate = mean(con(:, 2) > 0);
end

