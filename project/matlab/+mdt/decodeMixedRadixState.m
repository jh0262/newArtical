function states = decodeMixedRadixState(ranks, cardinalities)
%DECODEMIXEDRADIXSTATE Decode zero-based ranks into mixed discrete states.

arguments
    ranks double
    cardinalities double
end

cardinalities = validateCardinalities(cardinalities);
stateCount = prod(cardinalities);
ranks = ranks(:);
if any(~isfinite(ranks)) || any(ranks < 0) || ...
        any(ranks ~= floor(ranks)) || any(ranks >= stateCount)
    error('mdt:InvalidMixedRadixRank', ...
        'ranks must be zero-based integers below the mixed-radix state count.');
end

states = zeros(numel(ranks), numel(cardinalities));
working = ranks;
for j = numel(cardinalities):-1:1
    states(:, j) = mod(working, cardinalities(j));
    working = floor(working/cardinalities(j));
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
