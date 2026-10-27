function archive = updateArchive(archive, X, obj, con, capacity, cfg)
%UPDATEARCHIVE Update a bounded unique feasible nondominated external archive.

validateEvaluatedCandidates(X, obj, con, cfg);
if ~isscalar(capacity) || ~isfinite(capacity) || capacity < 1 || ...
        capacity ~= floor(capacity)
    error('mdt:InvalidArchiveCapacity', 'capacity must be a positive integer.');
end

if isempty(archive)
    oldX = zeros(0, 2+cfg.L);
    oldObj = zeros(0, 2);
    oldCon = zeros(0, 2);
elseif isstruct(archive) && all(isfield(archive, {'X', 'obj', 'con'}))
    if ~isempty(archive.X)
        validateEvaluatedCandidates(archive.X, archive.obj, archive.con, cfg);
    end
    oldX = archive.X;
    oldObj = archive.obj;
    oldCon = archive.con;
else
    error('mdt:InvalidArchive', 'archive must be empty or contain X, obj, and con.');
end

combinedX = [oldX; X];
combinedObj = [oldObj; obj];
combinedCon = [oldCon; con];
[combinedX, order] = sortrows(combinedX);
combinedObj = combinedObj(order, :);
combinedCon = combinedCon(order, :);

[combinedX, combinedObj, combinedCon] = deduplicateEvaluations( ...
    combinedX, combinedObj, combinedCon);
feasible = all(combinedCon <= 0, 2);
combinedX = combinedX(feasible, :);
combinedObj = combinedObj(feasible, :);
combinedCon = combinedCon(feasible, :);

if isempty(combinedX)
    archive = makeArchive(combinedX, combinedObj, combinedCon, capacity);
    return;
end

[~, rank] = nondominatedFronts(combinedObj);
nondominated = rank == 1;
combinedX = combinedX(nondominated, :);
combinedObj = combinedObj(nondominated, :);
combinedCon = combinedCon(nondominated, :);

if size(combinedX, 1) > capacity
    distance = crowdingDistance(combinedObj, combinedX);
    [~, keepOrder] = sortrows([-distance, combinedObj, combinedX]);
    keep = keepOrder(1:capacity);
else
    [~, keep] = sortrows([combinedObj, combinedX]);
end
archive = makeArchive(combinedX(keep, :), combinedObj(keep, :), ...
    combinedCon(keep, :), capacity);
end

function [X, obj, con] = deduplicateEvaluations(X, obj, con)
keep = true(size(X, 1), 1);
start = 1;
while start <= size(X, 1)
    finish = start;
    while finish < size(X, 1) && isequal(X(finish+1, :), X(start, :))
        finish = finish + 1;
    end
    group = start:finish;
    if any(abs(obj(group, :)-obj(start, :)) > 1e-12, 'all') || ...
            any(abs(con(group, :)-con(start, :)) > 1e-12, 'all')
        error('mdt:ConflictingDuplicateEvaluation', ...
            'The same phenotype has inconsistent objective or constraint values.');
    end
    keep(group(2:end)) = false;
    start = finish + 1;
end
X = X(keep, :);
obj = obj(keep, :);
con = con(keep, :);
end

function archive = makeArchive(X, obj, con, capacity)
archive = struct();
archive.schema = "mdt.external-archive.v0.1";
archive.X = X;
archive.obj = obj;
archive.con = con;
archive.capacity = capacity;
end
