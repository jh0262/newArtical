function hit = computeFirstHitNfe(X, obj, con, nfe, budget, cfg, truth)
%COMPUTEFIRSTHITNFE Compute component first-hit times with right censoring.

count = validateEvaluatedCandidates(X, obj, con, cfg);
nfe = reshape(nfe, [], 1);
if numel(nfe) ~= count || any(~isfinite(nfe)) || any(nfe < 1) || ...
        any(nfe ~= floor(nfe)) || any(diff(nfe) <= 0) || ...
        ~isscalar(budget) || ~isfinite(budget) || budget < nfe(end) || ...
        budget ~= floor(budget)
    error('mdt:InvalidNfeHistory', ...
        'nfe must be strictly increasing positive integers ending no later than budget.');
end
required = {'componentIdByState', 'paretoRelevantByComponent', 'nComponents'};
if ~isstruct(truth) || ~all(isfield(truth, required))
    error('mdt:InvalidTruth', 'truth is incomplete for first-hit analysis.');
end

componentIds = find(truth.paretoRelevantByComponent);
time = budget*ones(numel(componentIds), 1);
eventObserved = false(numel(componentIds), 1);
feasible = all(con <= 0, 2);
discrete = round(X(:, 3:end));
powers = cfg.q.^((cfg.L-1):-1:0);
externalRank = discrete*powers';
candidateComponent = truth.componentIdByState(externalRank+1);

for i = 1:count
    component = candidateComponent(i);
    relevantIndex = find(componentIds == component, 1);
    if ~feasible(i) || isempty(relevantIndex) || eventObserved(relevantIndex)
        continue;
    end
    priorFeasible = find(feasible(1:i));
    dominated = false;
    for j = reshape(priorFeasible, 1, [])
        if j ~= i && all(obj(j, :) <= obj(i, :)) && any(obj(j, :) < obj(i, :))
            dominated = true;
            break;
        end
    end
    if ~dominated
        time(relevantIndex) = nfe(i);
        eventObserved(relevantIndex) = true;
    end
end

hit = struct();
hit.schema = "mdt.first-hit-nfe.v0.1";
hit.componentIds = componentIds;
hit.time = time;
hit.eventObserved = eventObserved;
hit.censored = ~eventObserved;
hit.budget = budget;
end
