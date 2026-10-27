function schedule = makeDESchedule(N, D, CR, seed)
%MAKEDESCHEDULE Create a local-stream DE schedule without changing global RNG.

if ~isscalar(N) || ~isfinite(N) || N < 4 || N ~= floor(N)
    error('mdt:InvalidPopulationSize', 'N must be an integer greater than or equal to 4.');
end
if ~isscalar(D) || ~isfinite(D) || D < 1 || D ~= floor(D)
    error('mdt:InvalidDecisionDimension', 'D must be a positive integer.');
end
if ~isscalar(CR) || ~isfinite(CR) || CR < 0 || CR > 1
    error('mdt:InvalidCrossoverRate', 'CR must lie in [0,1].');
end
if ~isscalar(seed) || ~isfinite(seed) || seed < 0 || seed ~= floor(seed)
    error('mdt:InvalidSeed', 'seed must be a nonnegative integer.');
end

stream = RandStream('mt19937ar', 'Seed', seed);
donorIndices = zeros(N, 3);
allIndices = 1:N;
for i = 1:N
    pool = allIndices(allIndices ~= i);
    selected = randperm(stream, N-1, 3);
    donorIndices(i, :) = pool(selected);
end

crossMask = rand(stream, N, D) < CR;
jrand = randi(stream, D, N, 1);
for i = 1:N
    crossMask(i, jrand(i)) = true;
end

schedule = struct();
schedule.schema = "mdt.de-schedule.v0.1";
schedule.donorIndices = donorIndices;
schedule.crossMask = crossMask;
schedule.roundDraw = rand(stream, N, D);
schedule.categoryDraw = rand(stream, N, D);
schedule.seed = seed;
schedule.CR = CR;
end

