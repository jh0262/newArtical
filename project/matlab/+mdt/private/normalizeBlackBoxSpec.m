function spec = normalizeBlackBoxSpec(spec)
%NORMALIZEBLACKBOXSPEC Validate and normalize a mixed-variable specification.

required = {'continuousLower', 'continuousUpper', ...
    'discreteCardinalities', 'orderedDiscreteCount', 'constraintScales'};
if ~isstruct(spec) || ~isscalar(spec) || ~all(isfield(spec, required))
    error('mdt:InvalidBlackBoxVariableSpec', ...
        'variableSpec must contain continuous bounds, discrete cardinalities, orderedDiscreteCount, and constraintScales.');
end

lower = reshape(spec.continuousLower, 1, []);
upper = reshape(spec.continuousUpper, 1, []);
if isempty(lower) || ~isnumeric(lower) || ~isnumeric(upper) || ...
        ~isequal(size(lower), size(upper)) || ...
        any(~isfinite(lower)) || any(~isfinite(upper)) || ...
        any(lower >= upper)
    error('mdt:InvalidBlackBoxVariableSpec', ...
        'Continuous bounds must be aligned finite vectors with lower < upper.');
end

cardinalities = reshape(spec.discreteCardinalities, 1, []);
if isempty(cardinalities) || ~isnumeric(cardinalities) || ...
        any(~isfinite(cardinalities)) || any(cardinalities < 1) || ...
        any(cardinalities ~= floor(cardinalities))
    error('mdt:InvalidBlackBoxVariableSpec', ...
        'Discrete cardinalities must be positive finite integers.');
end

orderedCount = spec.orderedDiscreteCount;
if ~isscalar(orderedCount) || ~isfinite(orderedCount) || ...
        orderedCount < 0 || orderedCount ~= floor(orderedCount) || ...
        orderedCount > numel(cardinalities)
    error('mdt:InvalidBlackBoxVariableSpec', ...
        'orderedDiscreteCount must lie between zero and the number of discrete variables.');
end

constraintScales = reshape(spec.constraintScales, 1, []);
if isempty(constraintScales) || ~isnumeric(constraintScales) || ...
        any(~isfinite(constraintScales)) || any(constraintScales <= 0)
    error('mdt:InvalidBlackBoxVariableSpec', ...
        'constraintScales must contain positive finite values.');
end

stateCount = 1;
for value = cardinalities
    if stateCount > flintmax/value
        error('mdt:BlackBoxStateCountTooLarge', ...
            'The discrete state count must not exceed flintmax.');
    end
    stateCount = stateCount*value;
end

spec.continuousLower = lower;
spec.continuousUpper = upper;
spec.discreteCardinalities = cardinalities;
spec.orderedDiscreteCount = orderedCount;
spec.constraintScales = constraintScales;
spec.continuousCount = numel(lower);
spec.discreteCount = numel(cardinalities);
spec.dimension = spec.continuousCount + spec.discreteCount;
spec.discreteStateCount = stateCount;
end

