function result = runB5RandomBlackBox( ...
    evaluator, variableSpec, op, seed, N, budget, archiveCapacity)
%RUNB5RANDOMBLACKBOX Run the equal-frequency B5R targeting control.

arguments
    evaluator (1,1) function_handle
    variableSpec (1,1) struct
    op (1,1) struct
    seed (1,1) double
    N (1,1) double
    budget (1,1) double
    archiveCapacity (1,1) double
end
spec = normalizeBlackBoxSpec(variableSpec);
if ~isfinite(seed) || seed < 0 || seed ~= floor(seed)
    error('mdt:InvalidSeed', 'seed must be a nonnegative integer.');
end
if ~isfinite(N) || N < 4 || N ~= floor(N) || ...
        ~isfinite(budget) || budget < N || budget ~= floor(budget) || ...
        mod(budget, N) ~= 0
    error('mdt:InvalidEvaluationBudget', ...
        'N must be an integer >=4 and budget an integer multiple of N.');
end
if ~isfinite(archiveCapacity) || archiveCapacity < 1 || ...
        archiveCapacity ~= floor(archiveCapacity)
    error('mdt:InvalidArchiveCapacity', ...
        'archiveCapacity must be a positive integer.');
end
requiredNovelty = {'F', 'CR', 'FCategory', 'noveltyFractionMin', ...
    'noveltyFractionMax', 'stagnationHorizon'};
if ~isstruct(op) || ~all(isfield(op, requiredNovelty))
    error('mdt:MissingNoveltyParameters', ...
        'B5R requires the same DE and novelty parameters as B5S.');
end
mdt.computeNoveltyFraction(0, op.noveltyFractionMin, ...
    op.noveltyFractionMax, op.stagnationHorizon);

generations = budget/N-1;
stream = RandStream('mt19937ar', 'Seed', seed);
C = spec.continuousCount;
continuous = spec.continuousLower+rand(stream, N, C).* ...
    (spec.continuousUpper-spec.continuousLower);
discrete = floor(rand(stream, N, spec.discreteCount).* ...
    spec.discreteCardinalities);
population = [continuous, discrete];
initialPopulation = population;
[populationObj, populationCon] = evaluateCandidates(evaluator, population, spec);
evaluatorCalls = N;

initialRanks = mdt.encodeMixedRadixState(discrete, ...
    spec.discreteCardinalities);
initialFeasible = all(populationCon <= 0, 2);
visitLedger = mdt.observeSparseLedger( ...
    mdt.makeSparseLedger(spec.discreteStateCount), initialRanks);
feasibleLedger = mdt.observeSparseLedger( ...
    mdt.makeSparseLedger(spec.discreteStateCount), ...
    initialRanks(initialFeasible));
archive = mdt.updateArchiveBlackBox([], population, populationObj, ...
    populationCon, archiveCapacity, spec);

scheduleSeeds = seed+(1:generations);
noveltyFractionTimeline = zeros(1, generations);
noveltyInjectionCountTimeline = zeros(1, generations);
newFeasibleDiscreteStateTimeline = zeros(1, generations);
trace = zeros(generations+1, 8);
trace(1, :) = makeTraceRow(1, 0, N, population, populationCon, ...
    archive, visitLedger.storedStateCount, feasibleLedger.storedStateCount);
started = tic;

for generation = 1:generations
    schedule = mdt.makeDESchedule(N, spec.dimension, op.CR, ...
        scheduleSeeds(generation));
    offspring = mdt.generateTypePreservingDEBlackBox( ...
        population, spec, op, schedule);

    noveltyFraction = op.noveltyFractionMin;
    injectionCount = min([N, spec.discreteStateCount, ...
        max(1, ceil(noveltyFraction*N))]);
    injectionSeed = mod(scheduleSeeds(generation)+104729, 2^32-1);
    offspring = mdt.injectRandomDiscreteStatesBlackBox( ...
        offspring, spec, injectionCount, injectionSeed);
    noveltyFractionTimeline(generation) = noveltyFraction;
    noveltyInjectionCountTimeline(generation) = injectionCount;

    [offspringObj, offspringCon] = evaluateCandidates(evaluator, offspring, spec);
    evaluatorCalls = evaluatorCalls+N;
    offspringRanks = mdt.encodeMixedRadixState( ...
        offspring(:, C+1:end), spec.discreteCardinalities);
    visitLedger = mdt.observeSparseLedger(visitLedger, offspringRanks);
    feasibleRanks = unique(offspringRanks(all(offspringCon <= 0, 2)));
    previousFeasibleCounts = mdt.querySparseLedger(feasibleLedger, feasibleRanks);
    newRanks = feasibleRanks(previousFeasibleCounts == 0);
    feasibleLedger = mdt.observeSparseLedger(feasibleLedger, feasibleRanks);
    newFeasibleDiscreteStateTimeline(generation) = numel(newRanks);

    [population, populationObj, populationCon] = ...
        mdt.selectPopulationBlackBox( ...
        [population; offspring], [populationObj; offspringObj], ...
        [populationCon; offspringCon], N, spec);
    archive = mdt.updateArchiveBlackBox(archive, offspring, ...
        offspringObj, offspringCon, archiveCapacity, spec);

    row = generation+1;
    trace(row, :) = makeTraceRow(row, generation, evaluatorCalls, ...
        population, populationCon, archive, visitLedger.storedStateCount, ...
        numel(newRanks));
end
runtimeSeconds = toc(started);

metrics = struct();
metrics.schema = "mdt.blackbox-optimizer-metrics.v1.0";
metrics.algorithm = "B5R-BLACKBOX";
metrics.evaluations = evaluatorCalls;
metrics.nfeTimeline = trace(:, 3)';
metrics.finalFeasibleRate = trace(end, 4);
metrics.meanDuplicateRate = mean(trace(:, 5));
metrics.finalArchiveSize = trace(end, 6);
metrics.runtimeSeconds = runtimeSeconds;

audit = struct();
audit.schema = "mdt.blackbox-optimizer-audit.v1.0";
audit.seed = seed;
audit.initialPopulation = initialPopulation;
audit.scheduleSeeds = scheduleSeeds;
audit.evaluatorCalls = evaluatorCalls;
audit.truthUsed = false;
audit.truthUsedBySelection = false;
audit.truthUsedByGeneration = false;
audit.truthUsedByMetrics = false;
audit.selectionStrategy = "objective_crowding";
audit.noveltyFractionTimeline = noveltyFractionTimeline;
audit.noveltyInjectionCountTimeline = noveltyInjectionCountTimeline;
audit.noveltyTargeting = "uniform_rejection_without_replacement";
audit.newFeasibleDiscreteStateTimeline = newFeasibleDiscreteStateTimeline;
audit.visitLedgerBackend = visitLedger.backend;
audit.visitLedgerStoredStateCount = visitLedger.storedStateCount;
audit.seenFeasibleDiscreteStatesFinal = feasibleLedger.storedStateCount;
audit.discreteStateCount = spec.discreteStateCount;
audit.evaluatedDiscreteStateCoverageFinal = ...
    visitLedger.storedStateCount/spec.discreteStateCount;
audit.numericType = "double";
audit.device = "CPU";

result = struct();
result.schema = "mdt.blackbox-optimizer-result.v1.0";
result.algorithm = "B5R-BLACKBOX";
result.variableSpec = spec;
result.operator = op;
result.metrics = metrics;
result.trace = trace;
result.traceColumns = ["checkpoint", "generation", "nfe", ...
    "feasibleRate", "duplicateRate", "archiveSize", ...
    "visitedDiscreteStates", "newFeasibleDiscreteStates"];
result.finalPopulation = struct('X', population, 'obj', populationObj, ...
    'con', populationCon);
result.finalArchive = archive;
result.audit = audit;
end

function [obj, con] = evaluateCandidates(evaluator, X, spec)
[obj, con] = evaluator(X);
validateBlackBoxCandidates(X, obj, con, spec);
end

function row = makeTraceRow(checkpoint, generation, nfe, X, con, ...
    archive, visitedStateCount, newFeasibleStateCount)
duplicateRate = 1-size(unique(X, 'rows'), 1)/size(X, 1);
row = [checkpoint, generation, nfe, mean(all(con <= 0, 2)), ...
    duplicateRate, size(archive.X, 1), visitedStateCount, ...
    newFeasibleStateCount];
end
