function [value, audit] = computeNormalizedFeasibleHV( ...
    objectives, constraints, idealPoint, nadirPoint, referencePoint)
%COMPUTENORMALIZEDFEASIBLEHV Exact feasible HV for two or three objectives.

if ~isnumeric(objectives) || ~ismatrix(objectives) || ...
        ~ismember(size(objectives, 2), [2, 3]) || ...
        any(~isfinite(objectives), 'all')
    error('mdt:InvalidNormalizedHypervolumeInput', ...
        'objectives must be a finite N-by-2 or N-by-3 matrix.');
end
if ~isnumeric(constraints) || size(constraints, 1) ~= size(objectives, 1) || ...
        any(~isfinite(constraints), 'all')
    error('mdt:InvalidNormalizedHypervolumeInput', ...
        'constraints must be finite with one row per objective row.');
end
M = size(objectives, 2);
if ~isnumeric(idealPoint) || ~isnumeric(nadirPoint) || ...
        ~isnumeric(referencePoint) || ...
        ~isequal(size(idealPoint), [1, M]) || ...
        ~isequal(size(nadirPoint), [1, M]) || ...
        ~isequal(size(referencePoint), [1, M]) || ...
        any(~isfinite([idealPoint, nadirPoint, referencePoint])) || ...
        any(nadirPoint <= idealPoint) || any(referencePoint <= nadirPoint)
    error('mdt:InvalidNormalizedHypervolumeReference', ...
        'ideal, nadir, and reference points must be ordered finite rows.');
end

feasible = all(constraints <= 0, 2);
scale = nadirPoint-idealPoint;
normalizedReference = (referencePoint-idealPoint)./scale;
normalized = (objectives(feasible, :)-idealPoint)./scale;
eligible = all(normalized < normalizedReference, 2);
normalized = unique(normalized(eligible, :), 'rows');
if isempty(normalized)
    value = 0;
    nondominatedCount = 0;
else
    [~, rank] = nondominatedFronts(normalized);
    normalized = normalized(rank == 1, :);
    nondominatedCount = size(normalized, 1);
    if M == 2
        value = mdt.computeHypervolume2D(normalized, normalizedReference);
    else
        value = exactHypervolume3D(normalized, normalizedReference);
    end
end

audit = struct();
audit.schema = "mdt.normalized-feasible-hv-audit.v1.0";
audit.feasibleCount = nnz(feasible);
audit.infeasibleCount = nnz(~feasible);
audit.referenceEligibleCount = nnz(eligible);
audit.nondominatedCount = nondominatedCount;
audit.normalizedReferencePoint = normalizedReference;
audit.exact = true;
end

function value = exactHypervolume3D(points, referencePoint)
points = sortrows(points, [1, 2, 3]);
xValues = unique(points(:, 1), 'sorted');
value = 0;
for i = 1:numel(xValues)
    if i < numel(xValues)
        nextX = xValues(i+1);
    else
        nextX = referencePoint(1);
    end
    width = nextX-xValues(i);
    if width <= 0
        continue;
    end
    active = points(points(:, 1) <= xValues(i), 2:3);
    value = value + width*mdt.computeHypervolume2D( ...
        active, referencePoint(2:3));
end
end
