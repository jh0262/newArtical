function value = computeMeanComponentIgdPlus(approximation, referenceSet, componentIds)
%COMPUTEMEANCOMPONENTIGDPLUS Average component-specific IGD+ with equal weights.

if ~isnumeric(componentIds) || numel(componentIds) ~= size(referenceSet, 1) || ...
        any(~isfinite(componentIds)) || any(componentIds < 1) || ...
        any(componentIds ~= floor(componentIds))
    error('mdt:InvalidReferenceComponents', ...
        'componentIds must be positive integer labels aligned with referenceSet.');
end
componentIds = reshape(componentIds, [], 1);
components = unique(componentIds, 'sorted');
componentValues = zeros(numel(components), 1);
for i = 1:numel(components)
    componentReference = referenceSet(componentIds == components(i), :);
    componentValues(i) = mdt.computeIgdPlus(approximation, componentReference);
end
value = mean(componentValues);
end
