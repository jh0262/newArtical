function labels = labelH14Candidates(X, oracle)
%LABELH14CANDIDATES Apply H14 truth labels outside the optimizer path.

required = {'Q', 'continuousDimension', 'componentsPerState', ...
    'allowedStates', 'centers', 'radius', 'truthRole'};
if ~isstruct(oracle) || ~all(isfield(oracle, required)) || ...
        string(oracle.truthRole) ~= "metrics_and_preflight_only"
    error('mdt:H14InvalidOracle', ...
        'A complete metrics-only H14 oracle is required.');
end
if ~isnumeric(X) || size(X, 2) ~= oracle.continuousDimension+1 || ...
        any(~isfinite(X), 'all')
    error('mdt:H14InvalidCandidates', ...
        'X must be a finite N-by-5 numeric matrix.');
end
x = X(:, 1:oracle.continuousDimension);
state = X(:, end);
if any(x < 0, 'all') || any(x > 1, 'all') || ...
        any(state < 0) || any(state >= oracle.Q) || ...
        any(state ~= floor(state))
    error('mdt:H14CandidateOutOfBounds', ...
        'Candidates are outside the H14 variable bounds.');
end
n = size(X, 1);
[allowedState, stateIndex] = ismember(state, oracle.allowedStates);
componentId = zeros(n, 1);
normalizedDistance = inf(n, 1);
for row = reshape(find(allowedState), 1, [])
    centerRows = (stateIndex(row)-1)*oracle.componentsPerState+ ...
        (1:oracle.componentsPerState);
    distance = sum(((x(row, :)-oracle.centers(centerRows, :))/ ...
        oracle.radius).^2, 2);
    [normalizedDistance(row), local] = min(distance);
    componentId(row) = (stateIndex(row)-1)*oracle.componentsPerState+local;
end
feasible = allowedState & normalizedDistance <= 1;
componentId(~feasible) = 0;
labels = struct();
labels.schema = "mdt.h14-candidate-labels.v1.0";
labels.allowedState = allowedState;
labels.feasible = feasible;
labels.allowedStateIndex = stateIndex;
labels.componentId = componentId;
labels.normalizedDistance = normalizedDistance;
labels.truthUsedByAlgorithm = false;
end
