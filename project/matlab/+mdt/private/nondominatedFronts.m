function [fronts, rank] = nondominatedFronts(obj)
%NONDOMINATEDFRONTS Deterministic exact nondominated sorting for minimization.

count = size(obj, 1);
rank = zeros(count, 1);
fronts = cell(0, 1);
remaining = true(count, 1);
frontNumber = 0;

while any(remaining)
    candidates = find(remaining);
    dominated = false(numel(candidates), 1);
    for localI = 1:numel(candidates)
        i = candidates(localI);
        for localJ = 1:numel(candidates)
            j = candidates(localJ);
            if i ~= j && all(obj(j, :) <= obj(i, :)) && any(obj(j, :) < obj(i, :))
                dominated(localI) = true;
                break;
            end
        end
    end
    front = candidates(~dominated);
    if isempty(front)
        error('mdt:NondominatedSortFailure', 'Unable to identify a nondominated front.');
    end
    frontNumber = frontNumber + 1;
    fronts{frontNumber, 1} = front;
    rank(front) = frontNumber;
    remaining(front) = false;
end
end
