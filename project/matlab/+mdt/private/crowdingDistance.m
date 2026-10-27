function distance = crowdingDistance(obj, X)
%CROWDINGDISTANCE Compute deterministic NSGA-II objective-space crowding.

count = size(obj, 1);
distance = zeros(count, 1);
if count <= 2
    distance(:) = Inf;
    return;
end

for objective = 1:size(obj, 2)
    otherObjectives = setdiff(1:size(obj, 2), objective, 'stable');
    keys = [obj(:, objective), obj(:, otherObjectives), X];
    [~, order] = sortrows(keys);
    values = obj(order, objective);
    span = values(end)-values(1);
    distance(order(1)) = Inf;
    distance(order(end)) = Inf;
    if span <= 0
        continue;
    end
    for position = 2:(count-1)
        index = order(position);
        if ~isinf(distance(index))
            distance(index) = distance(index) + ...
                (values(position+1)-values(position-1))/span;
        end
    end
end
end
