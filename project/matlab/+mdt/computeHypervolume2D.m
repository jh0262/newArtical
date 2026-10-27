function value = computeHypervolume2D(objectives, referencePoint)
%COMPUTEHYPERVOLUME2D Exact dominated hypervolume for two minimized objectives.

if ~isnumeric(objectives) || size(objectives, 2) ~= 2 || ...
        any(~isfinite(objectives), 'all') || ~isnumeric(referencePoint) || ...
        ~isequal(size(referencePoint), [1, 2]) || any(~isfinite(referencePoint))
    error('mdt:InvalidHypervolumeInput', ...
        'objectives must be finite N-by-2 and referencePoint finite 1-by-2.');
end

eligible = all(objectives < referencePoint, 2);
objectives = unique(objectives(eligible, :), 'rows');
if isempty(objectives)
    value = 0;
    return;
end

[~, rank] = nondominatedFronts(objectives);
objectives = sortrows(objectives(rank == 1, :), [1, 2]);
value = 0;
previousSecondObjective = referencePoint(2);
for i = 1:size(objectives, 1)
    height = previousSecondObjective-objectives(i, 2);
    if height > 0
        value = value + (referencePoint(1)-objectives(i, 1))*height;
        previousSecondObjective = objectives(i, 2);
    end
end
end
