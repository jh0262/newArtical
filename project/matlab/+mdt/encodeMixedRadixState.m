function ranks = encodeMixedRadixState(states, cardinalities)
%ENCODEMIXEDRADIXSTATE Encode zero-based mixed discrete states as ranks.

arguments
    states double
    cardinalities double
end

cardinalities = validateCardinalities(cardinalities);
if size(states, 2) ~= numel(cardinalities) || ...
        any(~isfinite(states), 'all') || any(states < 0, 'all') || ...
        any(states ~= floor(states), 'all')
    error('mdt:InvalidMixedRadixState', ...
        'states must contain finite zero-based integers with one column per radix.');
end
for j = 1:numel(cardinalities)
    if any(states(:, j) >= cardinalities(j))
        error('mdt:InvalidMixedRadixState', ...
            'Every state value must be smaller than its cardinality.');
    end
end

ranks = zeros(size(states, 1), 1);
for j = 1:numel(cardinalities)
    ranks = ranks*cardinalities(j) + states(:, j);
end
end

function cardinalities = validateCardinalities(cardinalities)
cardinalities = reshape(cardinalities, 1, []);
if isempty(cardinalities) || any(~isfinite(cardinalities)) || ...
        any(cardinalities < 1) || any(cardinalities ~= floor(cardinalities))
    error('mdt:InvalidMixedRadixCardinality', ...
        'cardinalities must be a nonempty vector of positive integers.');
end
stateCount = 1;
for value = cardinalities
    if stateCount > flintmax/value
        error('mdt:MixedRadixStateCountTooLarge', ...
            'The mixed-radix state count must not exceed flintmax.');
    end
    stateCount = stateCount*value;
end
end
