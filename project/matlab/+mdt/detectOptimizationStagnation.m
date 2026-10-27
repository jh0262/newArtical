function diagnostic = detectOptimizationStagnation( ...
    result, horizon, pcrTolerance, hvTolerance, actionableBudgetFraction)
%DETECTOPTIMIZATIONSTAGNATION Detect frozen joint B5S stagnation events.

if ~isstruct(result) || ~isscalar(result) || ...
        ~all(isfield(result, {'metrics', 'trace', 'audit'})) || ...
        ~isfield(result.metrics, 'pcrTimeline') || ...
        ~isfield(result.audit, 'newFeasibleDiscreteStateTimeline') || ...
        ~isnumeric(result.trace) || size(result.trace, 2) < 10
    error('mdt:InvalidStagnationInput', ...
        'result must contain PCR, trace archive/HV columns, and new-feasible-state history.');
end
if ~isscalar(horizon) || ~isfinite(horizon) || horizon < 1 || ...
        horizon ~= floor(horizon) || ...
        ~isscalar(pcrTolerance) || ~isfinite(pcrTolerance) || ...
        pcrTolerance < 0 || ~isscalar(hvTolerance) || ...
        ~isfinite(hvTolerance) || hvTolerance < 0 || ...
        ~isscalar(actionableBudgetFraction) || ...
        ~isfinite(actionableBudgetFraction) || ...
        actionableBudgetFraction <= 0 || actionableBudgetFraction > 1
    error('mdt:InvalidStagnationParameters', ...
        'horizon and nonnegative tolerances must be valid, with budget fraction in (0,1].');
end

newFeasible = reshape( ...
    result.audit.newFeasibleDiscreteStateTimeline, [], 1);
generations = numel(newFeasible);
pcr = reshape(result.metrics.pcrTimeline, [], 1);
if numel(pcr) ~= generations+2 || size(result.trace, 1) ~= generations+1
    error('mdt:InvalidStagnationInput', ...
        'PCR, trace, and generation histories are not aligned.');
end
pcrCheckpoint = pcr(2:end);
pcrGain = diff(pcrCheckpoint);
hvGain = diff(result.trace(:, 10));
archiveGrowth = diff(result.trace(:, 9));
if any(~isfinite([newFeasible; pcrGain; hvGain; archiveGrowth])) || ...
        any(newFeasible < 0) || any(newFeasible ~= floor(newFeasible))
    error('mdt:InvalidStagnationInput', ...
        'Stagnation histories must contain aligned finite values.');
end

jointStagnant = newFeasible == 0 & ...
    pcrGain <= pcrTolerance & ...
    hvGain <= hvTolerance & ...
    archiveGrowth <= 0;
streakLength = zeros(generations, 1);
for generation = 1:generations
    if jointStagnant(generation)
        if generation == 1
            streakLength(generation) = 1;
        else
            streakLength(generation) = streakLength(generation-1)+1;
        end
    end
end
triggeredGenerations = find(streakLength >= horizon);
firstTrigger = NaN;
if ~isempty(triggeredGenerations)
    firstTrigger = triggeredGenerations(1);
end
maximumLength = max([0; streakLength]);
actionableLimit = floor(actionableBudgetFraction*generations);
actionable = ~isnan(firstTrigger) && firstTrigger <= actionableLimit;

diagnostic = struct();
diagnostic.schema = "mdt.optimization-stagnation-diagnostic.v1.0";
diagnostic.horizon = horizon;
diagnostic.pcrTolerance = pcrTolerance;
diagnostic.hvTolerance = hvTolerance;
diagnostic.actionableBudgetFraction = actionableBudgetFraction;
diagnostic.generations = generations;
diagnostic.triggered = ~isempty(triggeredGenerations);
diagnostic.actionableStagnation = actionable;
diagnostic.firstTriggerGeneration = firstTrigger;
diagnostic.maximumStagnationLength = maximumLength;
diagnostic.triggeredGenerations = triggeredGenerations;
diagnostic.jointStagnantTimeline = jointStagnant;
diagnostic.streakLengthTimeline = streakLength;
diagnostic.newFeasibleDiscreteStateTimeline = newFeasible;
diagnostic.pcrGainTimeline = pcrGain;
diagnostic.hvGainTimeline = hvGain;
diagnostic.archiveGrowthTimeline = archiveGrowth;
end
