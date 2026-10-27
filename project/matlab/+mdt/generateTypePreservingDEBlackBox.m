function offspring = generateTypePreservingDEBlackBox( ...
    population, variableSpec, op, schedule)
%GENERATETYPEPRESERVINGDEBLACKBOX Type-preserving DE for heterogeneous domains.

spec = normalizeBlackBoxSpec(variableSpec);
[N, D] = size(population);
if ~isnumeric(population) || N < 4 || D ~= spec.dimension || ...
        any(~isfinite(population), 'all')
    error('mdt:InvalidBlackBoxPopulation', ...
        'population must be a finite N-by-D matrix with N >= 4.');
end
dummyObj = zeros(N, 2);
dummyCon = zeros(N, numel(spec.constraintScales));
validateBlackBoxCandidates(population, dummyObj, dummyCon, spec);

requiredOp = {'F', 'CR', 'FCategory'};
if ~isstruct(op) || ~all(isfield(op, requiredOp)) || ...
        ~isscalar(op.F) || ~isfinite(op.F) || op.F < 0 || ...
        ~isscalar(op.CR) || ~isfinite(op.CR) || op.CR < 0 || op.CR > 1 || ...
        ~isscalar(op.FCategory) || ~isfinite(op.FCategory) || ...
        op.FCategory < 0 || op.FCategory > 1
    error('mdt:InvalidOperatorConfiguration', ...
        'op contains invalid F, CR, or FCategory.');
end

requiredSchedule = {'donorIndices', 'crossMask', 'roundDraw', 'categoryDraw'};
if ~isstruct(schedule) || ~all(isfield(schedule, requiredSchedule)) || ...
        ~isequal(size(schedule.donorIndices), [N, 3]) || ...
        ~isequal(size(schedule.crossMask), [N, D]) || ...
        ~isequal(size(schedule.roundDraw), [N, D]) || ...
        ~isequal(size(schedule.categoryDraw), [N, D])
    error('mdt:InvalidSchedule', ...
        'schedule dimensions do not match the black-box population.');
end
if any(schedule.donorIndices < 1, 'all') || ...
        any(schedule.donorIndices > N, 'all') || ...
        any(schedule.donorIndices ~= floor(schedule.donorIndices), 'all') || ...
        any(schedule.roundDraw < 0 | schedule.roundDraw >= 1, 'all') || ...
        any(schedule.categoryDraw < 0 | schedule.categoryDraw >= 1, 'all')
    error('mdt:InvalidSchedule', 'schedule contains invalid indices or draws.');
end
for i = 1:N
    donorsForTarget = schedule.donorIndices(i, :);
    if numel(unique(donorsForTarget)) ~= 3 || any(donorsForTarget == i)
        error('mdt:InvalidSchedule', ...
            'donors must be distinct and exclude the target.');
    end
end

donors = schedule.donorIndices;
offspring = population;
C = spec.continuousCount;

continuousMutant = population(donors(:, 1), 1:C) + ...
    op.F*(population(donors(:, 2), 1:C) - ...
    population(donors(:, 3), 1:C));
continuousMutant = min(spec.continuousUpper, ...
    max(spec.continuousLower, continuousMutant));
continuousMask = schedule.crossMask(:, 1:C);
continuous = offspring(:, 1:C);
continuous(continuousMask) = continuousMutant(continuousMask);
offspring(:, 1:C) = continuous;

orderedColumns = C + (1:spec.orderedDiscreteCount);
for column = orderedColumns
    orderedMutant = population(donors(:, 1), column) + ...
        op.F*(population(donors(:, 2), column) - ...
        population(donors(:, 3), column));
    radixIndex = column-C;
    orderedMutant = min(spec.discreteCardinalities(radixIndex)-1, ...
        max(0, orderedMutant));
    low = floor(orderedMutant);
    fraction = orderedMutant-low;
    orderedTrial = low + (schedule.roundDraw(:, column) < fraction);
    replace = schedule.crossMask(:, column);
    offspring(replace, column) = orderedTrial(replace);
end

categoricalColumns = C + ((spec.orderedDiscreteCount+1):spec.discreteCount);
for column = categoricalColumns
    a = population(donors(:, 1), column);
    b = population(donors(:, 2), column);
    c = population(donors(:, 3), column);
    categoricalTrial = a;
    differs = b ~= c;
    draw = schedule.categoryDraw(:, column);
    chooseB = differs & draw >= (1-op.FCategory) & ...
        draw < (1-op.FCategory + op.FCategory/2);
    chooseC = differs & draw >= (1-op.FCategory + op.FCategory/2);
    categoricalTrial(chooseB) = b(chooseB);
    categoricalTrial(chooseC) = c(chooseC);
    replace = schedule.crossMask(:, column);
    offspring(replace, column) = categoricalTrial(replace);
end

validateBlackBoxCandidates(offspring, dummyObj, dummyCon, spec);
end

