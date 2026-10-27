function adjusted = holmAdjust(pValues)
%HOLMADJUST Holm family-wise multiplicity adjustment.

arguments
    pValues double
end
originalSize = size(pValues);
p = pValues(:);
if isempty(p) || any(~isfinite(p)) || any(p < 0 | p > 1)
    error('mdt:InvalidPValues', 'pValues must be finite values in [0,1].');
end
[sorted, order] = sort(p);
m = numel(p);
scaled = (m-(1:m)'+1).*sorted;
monotone = cummax(scaled);
monotone = min(monotone, 1);
adjustedColumn = zeros(m, 1);
adjustedColumn(order) = monotone;
adjusted = reshape(adjustedColumn, originalSize);
end
