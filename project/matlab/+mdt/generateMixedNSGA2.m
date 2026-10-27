function offspring = generateMixedNSGA2(population, obj, con, cfg, op, seed)
%GENERATEMIXEDNSGA2 Mixed-variable NSGA-II variation for the H6 baseline.

arguments
    population double
    obj double
    con double
    cfg (1,1) struct
    op (1,1) struct
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end
required = {'crossoverProbability','mutationProbability','etaC','etaM'};
if ~all(isfield(op, required))
    error('mdt:MissingNSGA2Parameters', ...
        'N2 requires crossoverProbability, mutationProbability, etaC and etaM.');
end
if op.crossoverProbability < 0 || op.crossoverProbability > 1 || ...
        op.mutationProbability < 0 || op.mutationProbability > 1 || ...
        op.etaC <= 0 || op.etaM <= 0
    error('mdt:InvalidNSGA2Parameters', ...
        'N2 probabilities must be in [0,1] and distribution indices positive.');
end
N = validateEvaluatedCandidates(population, obj, con, cfg);
stream = RandStream('mt19937ar', 'Seed', seed);
[rank, crowding, violation, feasible] = tournamentScores( ...
    population, obj, con, cfg);
mating = zeros(N, 1);
for i = 1:N
    candidates = randperm(stream, N, 2);
    mating(i) = betterCandidate(candidates(1), candidates(2), rank, ...
        crowding, violation, feasible);
end

offspring = zeros(size(population));
for first = 1:2:N
    second = min(first+1, N);
    parentA = population(mating(first), :);
    parentB = population(mating(second), :);
    [childA, childB] = recombinePair(parentA, parentB, cfg, op, stream);
    offspring(first, :) = childA;
    if second ~= first
        offspring(second, :) = childB;
    end
end
offspring(:, 1:2) = min(1, max(0, offspring(:, 1:2)));
offspring(:, 3:end) = min(cfg.q-1, max(0, ...
    round(offspring(:, 3:end))));
if any(~isfinite(offspring), 'all')
    error('mdt:InvalidOffspring', 'N2 generated a nonfinite offspring matrix.');
end
end

function [rank, crowding, violation, feasible] = tournamentScores(X, obj, con, cfg)
N = size(X, 1);
[~, ~, ~, info] = mdt.selectPopulation(X, obj, con, N, cfg);
rank = Inf(N, 1);
crowding = zeros(N, 1);
violation = Inf(N, 1);
rank(info.sourceIndices) = info.frontRank;
crowding(info.sourceIndices) = info.crowdingDistance;
violation(info.sourceIndices) = info.totalViolation;
feasible = all(con <= 0, 2);
end

function winner = betterCandidate(a, b, rank, crowding, violation, feasible)
if feasible(a) ~= feasible(b)
    winner = a;
    if feasible(b)
        winner = b;
    end
elseif ~feasible(a)
    if violation(a) < violation(b)
        winner = a;
    elseif violation(b) < violation(a)
        winner = b;
    else
        winner = min(a, b);
    end
elseif rank(a) < rank(b)
    winner = a;
elseif rank(b) < rank(a)
    winner = b;
elseif crowding(a) > crowding(b)
    winner = a;
elseif crowding(b) > crowding(a)
    winner = b;
else
    winner = min(a, b);
end
end

function [a, b] = recombinePair(parentA, parentB, cfg, op, stream)
a = parentA;
b = parentB;
orderedColumns = 1:4;
for column = orderedColumns
    lower = 0;
    upper = 1;
    if column >= 3
        upper = cfg.q-1;
    end
    if rand(stream) <= op.crossoverProbability
        u = rand(stream);
        if u <= 0.5
            beta = (2*u)^(1/(op.etaC+1));
        else
            beta = (1/(2*(1-u)))^(1/(op.etaC+1));
        end
        a(column) = 0.5*((1+beta)*parentA(column) + ...
            (1-beta)*parentB(column));
        b(column) = 0.5*((1-beta)*parentA(column) + ...
            (1+beta)*parentB(column));
    end
    a(column) = mutatePolynomial(a(column), lower, upper, op, stream);
    b(column) = mutatePolynomial(b(column), lower, upper, op, stream);
end

for column = 5:(2+cfg.L)
    if rand(stream) < 0.5
        a(column) = parentB(column);
    end
    if rand(stream) < 0.5
        b(column) = parentA(column);
    end
    if rand(stream) <= op.mutationProbability
        a(column) = differentLabel(a(column), cfg.q, stream);
    end
    if rand(stream) <= op.mutationProbability
        b(column) = differentLabel(b(column), cfg.q, stream);
    end
end
a(orderedColumns) = min([1, 1, cfg.q-1, cfg.q-1], ...
    max(0, a(orderedColumns)));
b(orderedColumns) = min([1, 1, cfg.q-1, cfg.q-1], ...
    max(0, b(orderedColumns)));
a(3:4) = round(a(3:4));
b(3:4) = round(b(3:4));
end

function value = mutatePolynomial(value, lower, upper, op, stream)
if rand(stream) > op.mutationProbability || upper <= lower
    return;
end
u = rand(stream);
delta1 = (value-lower)/(upper-lower);
delta2 = (upper-value)/(upper-lower);
power = 1/(op.etaM+1);
if u <= 0.5
    term = 2*u + (1-2*u)*(1-delta1)^(op.etaM+1);
    delta = term^power-1;
else
    term = 2*(1-u) + 2*(u-0.5)*(1-delta2)^(op.etaM+1);
    delta = 1-term^power;
end
value = min(upper, max(lower, value+delta*(upper-lower)));
end

function label = differentLabel(current, q, stream)
draw = randi(stream, q-1)-1;
label = draw + (draw >= round(current));
end
