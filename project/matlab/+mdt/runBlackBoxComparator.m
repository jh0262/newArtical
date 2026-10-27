function result = runBlackBoxComparator( ...
    algorithm, evaluator, variableSpec, op, seed, N, budget, archiveCapacity)
%RUNBLACKBOXCOMPARATOR Run B1, B5R, B5S, or local N2 on a black-box problem.

algorithm = upper(string(algorithm));
if ~ismember(algorithm, ["B1", "B5R", "B5S", "N2"])
    error('mdt:InvalidBlackBoxComparator', ...
        'algorithm must be B1, B5R, B5S, or N2.');
end
if algorithm == "B5S"
    result = mdt.runB5SparseBlackBox(evaluator, variableSpec, op, ...
        seed, N, budget, archiveCapacity);
    result.algorithm = "B5S";
    result.metrics.algorithm = "B5S";
    return;
end
if algorithm == "B5R"
    result = mdt.runB5RandomBlackBox(evaluator, variableSpec, op, ...
        seed, N, budget, archiveCapacity);
    result.algorithm = "B5R";
    result.metrics.algorithm = "B5R";
    return;
end

spec = normalizeBlackBoxSpec(variableSpec);
if ~isfinite(seed) || seed < 0 || seed ~= floor(seed)
    error('mdt:InvalidSeed', 'seed must be a nonnegative integer.');
end
if ~isfinite(N) || N < 4 || N ~= floor(N) || ...
        ~isfinite(budget) || budget < N || budget ~= floor(budget) || ...
        mod(budget, N) ~= 0
    error('mdt:InvalidEvaluationBudget', ...
        'N must be >=4 and budget must be an integer multiple of N.');
end
if ~isfinite(archiveCapacity) || archiveCapacity < 1 || ...
        archiveCapacity ~= floor(archiveCapacity)
    error('mdt:InvalidArchiveCapacity', ...
        'archiveCapacity must be a positive integer.');
end

generations = budget/N-1;
stream = RandStream('mt19937ar', 'Seed', seed);
C = spec.continuousCount;
continuous = spec.continuousLower + rand(stream, N, C).* ...
    (spec.continuousUpper-spec.continuousLower);
discrete = floor(rand(stream, N, spec.discreteCount).* ...
    spec.discreteCardinalities);
population = [continuous, discrete];
initialPopulation = population;
[populationObj, populationCon] = evaluateCandidates(evaluator, population, spec);
evaluatorCalls = N;

initialRanks = mdt.encodeMixedRadixState(discrete, spec.discreteCardinalities);
visitLedger = mdt.observeSparseLedger( ...
    mdt.makeSparseLedger(spec.discreteStateCount), initialRanks);
feasibleLedger = mdt.observeSparseLedger( ...
    mdt.makeSparseLedger(spec.discreteStateCount), ...
    initialRanks(all(populationCon <= 0, 2)));
archive = mdt.updateArchiveBlackBox([], population, populationObj, ...
    populationCon, archiveCapacity, spec);

scheduleSeeds = seed+(1:generations);
trace = zeros(generations+1, 8);
trace(1, :) = makeTraceRow(1, 0, evaluatorCalls, population, ...
    populationCon, archive, visitLedger.storedStateCount, ...
    feasibleLedger.storedStateCount);
newFeasibleDiscreteStateTimeline = zeros(1, generations);
started = tic;

for generation = 1:generations
    if algorithm == "B1"
        schedule = mdt.makeDESchedule(N, spec.dimension, op.CR, ...
            scheduleSeeds(generation));
        offspring = mdt.generateTypePreservingDEBlackBox( ...
            population, spec, op, schedule);
    else
        offspring = mdt.generateMixedNSGA2BlackBox(population, ...
            populationObj, populationCon, spec, op, ...
            scheduleSeeds(generation));
    end
    [offspringObj, offspringCon] = evaluateCandidates( ...
        evaluator, offspring, spec);
    evaluatorCalls = evaluatorCalls+N;

    offspringRanks = mdt.encodeMixedRadixState( ...
        offspring(:, C+1:end), spec.discreteCardinalities);
    visitLedger = mdt.observeSparseLedger(visitLedger, offspringRanks);
    feasibleRanks = unique(offspringRanks(all(offspringCon <= 0, 2)));
    previousCounts = mdt.querySparseLedger(feasibleLedger, feasibleRanks);
    newRanks = feasibleRanks(previousCounts == 0);
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
metrics.schema = "mdt.blackbox-comparator-metrics.v1.0";
metrics.algorithm = algorithm;
metrics.evaluations = evaluatorCalls;
metrics.nfeTimeline = trace(:, 3)';
metrics.finalFeasibleRate = trace(end, 4);
metrics.meanDuplicateRate = mean(trace(:, 5));
metrics.finalArchiveSize = trace(end, 6);
metrics.runtimeSeconds = runtimeSeconds;

audit = struct();
audit.schema = "mdt.blackbox-comparator-audit.v1.0";
audit.seed = seed;
audit.initialPopulation = initialPopulation;
audit.scheduleSeeds = scheduleSeeds;
audit.evaluatorCalls = evaluatorCalls;
audit.truthUsed = false;
audit.truthUsedBySelection = false;
audit.truthUsedByGeneration = false;
audit.truthUsedByMetrics = false;
audit.selectionStrategy = "feasibility_first_objective_crowding";
audit.noveltyFractionTimeline = zeros(1, generations);
audit.noveltyInjectionCountTimeline = zeros(1, generations);
audit.noveltyTargeting = "none";
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
result.schema = "mdt.blackbox-comparator-result.v1.0";
result.algorithm = algorithm;
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
