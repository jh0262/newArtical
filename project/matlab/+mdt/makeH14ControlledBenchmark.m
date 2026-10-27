function [benchmark, oracle] = makeH14ControlledBenchmark( ...
    Q, stateLayout, componentsPerState, landscapeSeed)
%MAKEH14CONTROLLEDBENCHMARK Build a controlled fractured-feasibility problem.
%
% The returned benchmark is the algorithm-facing object. The separate oracle
% contains labels for metrics and preflight checks and must never be passed to
% an optimizer.

arguments
    Q (1,1) double
    stateLayout (1,1) string
    componentsPerState (1,1) double
    landscapeSeed (1,1) double
end
if ~isfinite(Q) || Q ~= floor(Q) || Q < 2 || ...
        ~(Q == 2 || mod(Q, 4) == 0)
    error('mdt:H14InvalidCardinality', ...
        'Q must be 2 or an integer multiple of four.');
end
stateLayout = lower(stateLayout);
if Q == 2
    if stateLayout ~= "boundary"
        error('mdt:H14InvalidLayout', ...
            'Q=2 uses the boundary layout.');
    end
elseif ~ismember(stateLayout, ["connected", "dispersed"])
    error('mdt:H14InvalidLayout', ...
        'Q>=4 uses connected or dispersed state layouts.');
end
if ~ismember(componentsPerState, [1, 4])
    error('mdt:H14InvalidComponentCount', ...
        'componentsPerState must be 1 or 4.');
end
if ~isfinite(landscapeSeed) || landscapeSeed < 0 || ...
        landscapeSeed ~= floor(landscapeSeed)
    error('mdt:H14InvalidLandscapeSeed', ...
        'landscapeSeed must be a nonnegative integer.');
end

continuousDimension = 4;
radius = 0.20;
if Q == 2
    allowedStateCount = 1;
    allowedStates = mod(landscapeSeed, 2);
else
    allowedStateCount = Q/4;
    if stateLayout == "connected"
        maxOffset = Q-allowedStateCount;
        offset = mod(landscapeSeed, maxOffset+1);
        allowedStates = offset+(0:(allowedStateCount-1));
    else
        step = Q/allowedStateCount;
        offset = mod(landscapeSeed, step);
        allowedStates = offset+step*(0:(allowedStateCount-1));
    end
end
allowedStates = reshape(double(allowedStates), [], 1);

stream = RandStream('mt19937ar', 'Seed', landscapeSeed);
centers = makeCenters(stream, allowedStateCount, ...
    componentsPerState, continuousDimension, radius);
componentCount = allowedStateCount*componentsPerState;
componentIds = (1:componentCount)';
anchorStart = (componentIds-1)/componentCount;
segmentWidth = 1/componentCount;

privateModel = struct();
privateModel.Q = Q;
privateModel.continuousDimension = continuousDimension;
privateModel.componentsPerState = componentsPerState;
privateModel.allowedStates = allowedStates;
privateModel.centers = centers;
privateModel.radius = radius;
privateModel.componentCount = componentCount;
privateModel.anchorStart = anchorStart;
privateModel.segmentWidth = segmentWidth;

variableSpec = struct( ...
    'continuousLower', zeros(1, continuousDimension), ...
    'continuousUpper', ones(1, continuousDimension), ...
    'discreteCardinalities', Q, ...
    'orderedDiscreteCount', 1, ...
    'constraintScales', 1);
benchmark = struct();
benchmark.schema = "mdt.h14-controlled-benchmark.v1.0";
benchmark.id = sprintf("H14-Q%d-%s-L%d-S%d", Q, ...
    upper(char(stateLayout)), componentsPerState, landscapeSeed);
benchmark.name = "Controlled fractured mixed-discrete feasible region";
benchmark.family = "H14-controlled-fracture";
benchmark.variableSpec = variableSpec;
benchmark.internalVariableOrder = ["x1", "x2", "x3", "x4", "state"];
benchmark.objectiveCount = 2;
benchmark.objectiveSense = ["min", "min"];
benchmark.constraintSense = "componentwise <= 0";
benchmark.idealPoint = [0, 0];
benchmark.nadirPoint = [1, 1];
benchmark.hvReferencePoint = [1.1, 1.1];
benchmark.evaluator = @(X) evaluatePrivate(X, privateModel);
benchmark.truthAvailableToAlgorithm = false;
benchmark.claimBoundary = [ ...
    "Synthetic analytical benchmark for mechanism testing only; ", ...
    "not engineering or physical validation."];

oracle = privateModel;
oracle.schema = "mdt.h14-controlled-oracle.v1.0";
oracle.benchmarkId = benchmark.id;
oracle.stateLayout = stateLayout;
oracle.landscapeSeed = landscapeSeed;
oracle.allowedStateCount = allowedStateCount;
oracle.componentIds = componentIds;
oracle.truthRole = "metrics_and_preflight_only";
end

function centers = makeCenters(stream, K, L, d, radius)
centers = zeros(K*L, d);
minimumSpacing = 2.10*radius;
for stateIndex = 1:K
    accepted = zeros(0, d);
    attempts = 0;
    while size(accepted, 1) < L
        attempts = attempts+1;
        if attempts > 10000
            error('mdt:H14CenterGenerationFailed', ...
                'Unable to generate separated component centers.');
        end
        candidate = radius+(1-2*radius)*rand(stream, 1, d);
        if isempty(accepted) || all(vecnorm(accepted-candidate, 2, 2) ...
                >= minimumSpacing)
            accepted(end+1, :) = candidate; %#ok<AGROW>
        end
    end
    rows = (stateIndex-1)*L+(1:L);
    centers(rows, :) = accepted;
end
end

function [obj, con] = evaluatePrivate(X, model)
[stateIndex, localComponent, scaled, minNormalizedDistance] = ...
    classifyCandidates(X, model);
n = size(X, 1);
obj = zeros(n, 2);
con = zeros(n, 1);
allowed = stateIndex > 0;

if any(allowed)
    rows = find(allowed);
    component = (stateIndex(rows)-1)*model.componentsPerState+ ...
        localComponent(rows);
    y = scaled(rows, :);
    width = model.segmentWidth;
    alpha = width/4;
    beta = width/4;
    orthogonalPenalty = beta*sum(y(:, 2:end).^2, 2);
    anchor = model.anchorStart(component);
    obj(rows, 1) = anchor+alpha*(y(:, 1)+1).^2+orthogonalPenalty;
    obj(rows, 2) = 1-anchor-width+ ...
        alpha*(y(:, 1)-1).^2+orthogonalPenalty;
    con(rows) = minNormalizedDistance(rows)-1;
end

if any(~allowed)
    rows = find(~allowed);
    x = X(rows, 1:model.continuousDimension);
    state = X(rows, end);
    obj(rows, 1) = 2+mean(x.^2, 2)+state/model.Q;
    obj(rows, 2) = 2+mean((1-x).^2, 2)+(model.Q-1-state)/model.Q;
    nearestState = min(abs(state-model.allowedStates'), [], 2);
    con(rows) = 1+nearestState/max(model.Q-1, 1);
end
end

function [stateIndex, localComponent, scaled, minNormalizedDistance] = ...
    classifyCandidates(X, model)
if ~isnumeric(X) || size(X, 2) ~= model.continuousDimension+1 || ...
        any(~isfinite(X), 'all')
    error('mdt:H14InvalidCandidates', ...
        'X must be a finite N-by-5 numeric matrix.');
end
x = X(:, 1:model.continuousDimension);
state = X(:, end);
if any(x < 0, 'all') || any(x > 1, 'all') || ...
        any(state < 0) || any(state >= model.Q) || ...
        any(state ~= floor(state))
    error('mdt:H14CandidateOutOfBounds', ...
        'Continuous variables must be in [0,1] and state in 0:(Q-1).');
end
n = size(X, 1);
stateIndex = zeros(n, 1);
localComponent = zeros(n, 1);
scaled = zeros(n, model.continuousDimension);
minNormalizedDistance = inf(n, 1);
[isAllowed, matchedIndex] = ismember(state, model.allowedStates);
for row = reshape(find(isAllowed), 1, [])
    stateIndex(row) = matchedIndex(row);
    centerRows = (matchedIndex(row)-1)*model.componentsPerState+ ...
        (1:model.componentsPerState);
    offsets = x(row, :)-model.centers(centerRows, :);
    normalizedDistances = sum((offsets/model.radius).^2, 2);
    [minNormalizedDistance(row), localComponent(row)] = ...
        min(normalizedDistances);
    scaled(row, :) = offsets(localComponent(row), :)/model.radius;
end
end
