function offspring = generateTypePreservingDE(population, cfg, op, schedule)
%GENERATETYPEPRESERVINGDE B1: type-preserving mixed-variable DE kernel.

[N, ~, lower, upper] = validateOperatorInputs(population, cfg, op, schedule);
donors = schedule.donorIndices;
offspring = population;

% Continuous variables use exactly the same numeric DE and crossover as B0.
continuousMutant = population(donors(:, 1), 1:2) + ...
    op.F*(population(donors(:, 2), 1:2) - population(donors(:, 3), 1:2));
continuousMutant = min(upper(1:2), max(lower(1:2), continuousMutant));
continuousMask = schedule.crossMask(:, 1:2);
continuous = offspring(:, 1:2);
continuous(continuousMask) = continuousMutant(continuousMask);
offspring(:, 1:2) = continuous;

% Integer and ordinal variables use ordered-space DE with stochastic rounding.
for column = 3:4
    orderedMutant = population(donors(:, 1), column) + ...
        op.F*(population(donors(:, 2), column) - population(donors(:, 3), column));
    orderedMutant = min(upper(column), max(lower(column), orderedMutant));
    low = floor(orderedMutant);
    fraction = orderedMutant - low;
    orderedTrial = low + (schedule.roundDraw(:, column) < fraction);
    replace = schedule.crossMask(:, column);
    offspring(replace, column) = orderedTrial(replace);
end

% Categorical variables sample donor roles without arithmetic on label codes.
for column = 5:(2+cfg.L)
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

if size(offspring, 1) ~= N || any(~isfinite(offspring), 'all')
    error('mdt:InvalidOffspring', 'offspring generation produced an invalid matrix.');
end
end

