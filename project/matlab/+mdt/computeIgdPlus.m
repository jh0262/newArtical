function value = computeIgdPlus(approximation, referenceSet)
%COMPUTEIGDPLUS Compute IGD+ for minimized objectives.

if ~isnumeric(approximation) || size(approximation, 2) ~= 2 || ...
        any(~isfinite(approximation), 'all') || ~isnumeric(referenceSet) || ...
        size(referenceSet, 2) ~= 2 || isempty(referenceSet) || ...
        any(~isfinite(referenceSet), 'all')
    error('mdt:InvalidIgdPlusInput', ...
        'approximation must be finite N-by-2 and referenceSet finite nonempty M-by-2.');
end
if isempty(approximation)
    value = Inf;
    return;
end

nearest = zeros(size(referenceSet, 1), 1);
for i = 1:size(referenceSet, 1)
    positiveDifference = max(approximation-referenceSet(i, :), 0);
    distances = sqrt(sum(positiveDifference.^2, 2));
    nearest(i) = min(distances);
end
value = mean(nearest);
end
