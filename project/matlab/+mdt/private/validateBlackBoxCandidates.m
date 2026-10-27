function count = validateBlackBoxCandidates(X, obj, con, spec)
%VALIDATEBLACKBOXCANDIDATES Validate aligned black-box evaluations.

spec = normalizeBlackBoxSpec(spec);
count = size(X, 1);
if ~isnumeric(X) || count < 1 || size(X, 2) ~= spec.dimension || ...
        ~isnumeric(obj) || size(obj, 1) ~= count || size(obj, 2) < 2 || ...
        ~isnumeric(con) || size(con, 1) ~= count || ...
        size(con, 2) ~= numel(spec.constraintScales) || ...
        any(~isfinite(X), 'all') || any(~isfinite(obj), 'all') || ...
        any(~isfinite(con), 'all')
    error('mdt:InvalidBlackBoxEvaluation', ...
        'X, objectives, and constraints must be finite aligned matrices with at least two objectives and the declared constraint columns.');
end

C = spec.continuousCount;
if any(X(:, 1:C) < spec.continuousLower, 'all') || ...
        any(X(:, 1:C) > spec.continuousUpper, 'all')
    error('mdt:InvalidBlackBoxEvaluation', ...
        'Continuous decision variables are outside their declared bounds.');
end
discrete = X(:, C+1:end);
if any(discrete ~= round(discrete), 'all') || any(discrete < 0, 'all')
    error('mdt:InvalidBlackBoxEvaluation', ...
        'Discrete decision variables must be zero-based integers.');
end
for j = 1:spec.discreteCount
    if any(discrete(:, j) >= spec.discreteCardinalities(j))
        error('mdt:InvalidBlackBoxEvaluation', ...
            'A discrete decision variable exceeds its declared cardinality.');
    end
end
end

