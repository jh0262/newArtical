function offspring = generateMixedNSGA2BlackBox( ...
    population, obj, con, variableSpec, op, seed)
%GENERATEMIXEDNSGA2BLACKBOX Heterogeneous mixed-variable N2 variation.

spec = normalizeBlackBoxSpec(variableSpec);
N = validateBlackBoxCandidates(population, obj, con, spec);
required = {'crossoverProbability', 'mutationProbability', 'etaC', 'etaM'};
if ~isstruct(op) || ~all(isfield(op, required)) || ...
        ~isscalar(op.crossoverProbability) || ...
        op.crossoverProbability < 0 || op.crossoverProbability > 1 || ...
        ~isscalar(op.mutationProbability) || ...
        op.mutationProbability < 0 || op.mutationProbability > 1 || ...
        ~isscalar(op.etaC) || op.etaC <= 0 || ...
        ~isscalar(op.etaM) || op.etaM <= 0
    error('mdt:InvalidNSGA2Parameters', ...
        'N2 probabilities must be in [0,1] and distribution indices positive.');
end
if ~isscalar(seed) || ~isfinite(seed) || seed < 0 || seed ~= floor(seed)
    error('mdt:InvalidSeed', 'seed must be a nonnegative integer.');
end

stream = RandStream('mt19937ar', 'Seed', seed);
[rank, crowding, violation, feasible] = tournamentScores( ...
    population, obj, con, spec);
mating = zeros(N, 1);
for i = 1:N
    candidates = randperm(stream, N, 2);
    mating(i) = betterCandidate(candidates(1), candidates(2), ...
        rank, crowding, violation, feasible);
end

offspring = zeros(size(population));
for first = 1:2:N
    second = min(first+1, N);
    parentA = population(mating(first), :);
    parentB = population(mating(second), :);
    [childA, childB] = recombinePair(parentA, parentB, spec, op, stream);
    offspring(first, :) = childA;
    if second ~= first
        offspring(second, :) = childB;
    end
end

dummyObj = zeros(N, size(obj, 2));
dummyCon = zeros(N, size(con, 2));
validateBlackBoxCandidates(offspring, dummyObj, dummyCon, spec);
end

function [rank, crowding, violation, feasible] = tournamentScores(X, obj, con, spec)
N = size(X, 1);
[~, ~, ~, info] = mdt.selectPopulationBlackBox(X, obj, con, N, spec);
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

function [a, b] = recombinePair(parentA, parentB, spec, op, stream)
a = parentA;
b = parentB;
orderedColumns = 1:(spec.continuousCount+spec.orderedDiscreteCount);
for column = orderedColumns
    if column <= spec.continuousCount
        lower = spec.continuousLower(column);
        upper = spec.continuousUpper(column);
        isDiscrete = false;
    else
        radix = column-spec.continuousCount;
        lower = 0;
        upper = spec.discreteCardinalities(radix)-1;
        isDiscrete = true;
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
    a(column) = min(upper, max(lower, a(column)));
    b(column) = min(upper, max(lower, b(column)));
    if isDiscrete
        a(column) = round(a(column));
        b(column) = round(b(column));
    end
end

firstCategorical = spec.continuousCount+spec.orderedDiscreteCount+1;
for column = firstCategorical:spec.dimension
    radix = column-spec.continuousCount;
    cardinality = spec.discreteCardinalities(radix);
    if rand(stream) < 0.5
        a(column) = parentB(column);
    end
    if rand(stream) < 0.5
        b(column) = parentA(column);
    end
    if rand(stream) <= op.mutationProbability && cardinality > 1
        a(column) = differentLabel(a(column), cardinality, stream);
    end
    if rand(stream) <= op.mutationProbability && cardinality > 1
        b(column) = differentLabel(b(column), cardinality, stream);
    end
end
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

function label = differentLabel(current, cardinality, stream)
draw = randi(stream, cardinality-1)-1;
label = draw + (draw >= round(current));
end

