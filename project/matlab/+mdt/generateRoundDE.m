function offspring = generateRoundDE(population, cfg, op, schedule)
%GENERATEROUNDDE B0: numeric DE followed by clipping and rounding.

[~, ~, lower, upper] = validateOperatorInputs(population, cfg, op, schedule);
donors = schedule.donorIndices;
mutant = population(donors(:, 1), :) + ...
    op.F*(population(donors(:, 2), :) - population(donors(:, 3), :));
mutant = min(upper, max(lower, mutant));

offspring = population;
offspring(schedule.crossMask) = mutant(schedule.crossMask);
offspring(:, 3:end) = round(offspring(:, 3:end));
end

