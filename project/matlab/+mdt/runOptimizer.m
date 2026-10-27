function result = runOptimizer(algorithm, cfg, op, seed, N, budget, archiveCapacity)
%RUNOPTIMIZER Run one fixed-budget B0 or B1 optimization trial in memory.

arguments
    algorithm (1,1) string
    cfg (1,1) struct
    op (1,1) struct
    seed (1,1) double
    N (1,1) double
    budget (1,1) double
    archiveCapacity (1,1) double
end

algorithm = upper(algorithm);
if ~ismember(algorithm, ["B0", "B1", "B2", "B3", "B4", ...
        "B4F", "B4R", "B5", "B5S", "N2"])
    error('mdt:InvalidAlgorithm', ...
        'algorithm must be B0, B1, B2, B3, B4, B4F, B4R, B5, B5S, or N2.');
end
if ~isfinite(seed) || seed < 0 || seed ~= floor(seed)
    error('mdt:InvalidSeed', 'seed must be a nonnegative integer.');
end
if ~isfinite(N) || N < 4 || N ~= floor(N) || ...
        ~isfinite(budget) || budget < N || budget ~= floor(budget) || ...
        mod(budget, N) ~= 0
    error('mdt:InvalidEvaluationBudget', ...
        'N must be an integer >=4 and budget must be an integer multiple of N.');
end
if ~isfinite(archiveCapacity) || archiveCapacity < 1 || ...
        archiveCapacity ~= floor(archiveCapacity)
    error('mdt:InvalidArchiveCapacity', ...
        'archiveCapacity must be a positive integer.');
end
if ismember(algorithm, ["B4", "B4F", "B4R", "B5", "B5S"])
    requiredNovelty = {'noveltyFractionMin','noveltyFractionMax', ...
        'stagnationHorizon'};
    if ~all(isfield(op, requiredNovelty))
        error('mdt:MissingNoveltyParameters', ...
            'B4 requires noveltyFractionMin/Max and stagnationHorizon.');
    end
    mdt.computeNoveltyFraction(0, op.noveltyFractionMin, ...
        op.noveltyFractionMax, op.stagnationHorizon);
end
if algorithm == "N2"
    requiredNsga2 = {'crossoverProbability','mutationProbability', ...
        'etaC','etaM'};
    if ~all(isfield(op, requiredNsga2))
        error('mdt:MissingNSGA2Parameters', ...
            'N2 requires crossoverProbability, mutationProbability, etaC and etaM.');
    end
end

truth = mdt.enumerateTruth(cfg);
[referenceSet, referenceComponents] = mdt.makeReferenceFront(truth, 101);
generations = budget/N - 1;
D = 2 + cfg.L;
stream = RandStream('mt19937ar', 'Seed', seed);
population = [rand(stream, N, 2), floor(cfg.q*rand(stream, N, cfg.L))];
initialPopulation = population;
[populationObj, populationCon] = mdt.evaluate(population, cfg);
discretePowers = cfg.q.^((cfg.L-1):-1:0);
initialRanks = round(population(:, 3:end))*discretePowers';
initialFeasible = all(populationCon <= 0, 2);
useSparseLedger = algorithm == "B5S";
if useSparseLedger
    visitLedger = mdt.makeSparseLedger(cfg.Q);
    visitLedger = mdt.observeSparseLedger(visitLedger, initialRanks);
    feasibleLedger = mdt.makeSparseLedger(cfg.Q);
    feasibleLedger = mdt.observeSparseLedger( ...
        feasibleLedger, initialRanks(initialFeasible));
    visitCounts = zeros(0, 1);
    seenFeasibleDiscreteStates = false(0, 1);
else
    visitCounts = accumarray(initialRanks+1, 1, [cfg.Q, 1]);
    seenFeasibleDiscreteStates = false(cfg.Q, 1);
    seenFeasibleDiscreteStates(initialRanks(initialFeasible)+1) = true;
    visitLedger = struct();
    feasibleLedger = struct();
end
discoveryStagnation = 0;
archive = mdt.updateArchive([], population, populationObj, populationCon, ...
    archiveCapacity, cfg);
[discoveryX, discoveryObj, discoveryCon] = updateDiscoveryFront( ...
    zeros(0, D), zeros(0, 2), zeros(0, 2), ...
    population, populationObj, populationCon);

checkpointCount = budget/N;
trace = zeros(checkpointCount, 12);
nfeTimeline = 0:N:budget;
pcrTimeline = zeros(1, checkpointCount+1);
firstHitCheckpoint = budget*ones(truth.nParetoRelevantComponents, 1);
eventObserved = false(truth.nParetoRelevantComponents, 1);
scheduleSeeds = seed + (1:generations);
protectedCountTimeline = zeros(1, generations);
noveltyFractionTimeline = zeros(1, generations);
noveltyInjectionCountTimeline = zeros(1, generations);
newFeasibleDiscreteStateTimeline = zeros(1, generations);
startedAt = utcNow();
started = tic;

[trace(1, :), hit] = makeTraceRow(1, 0, N, population, populationObj, ...
    populationCon, archive, discoveryX, discoveryObj, discoveryCon, ...
    cfg, truth, referenceSet, referenceComponents);
pcrTimeline(2) = mean(hit);
newHit = hit & ~eventObserved;
firstHitCheckpoint(newHit) = N;
eventObserved = eventObserved | hit;

for generation = 1:generations
    if algorithm == "N2"
        offspring = mdt.generateMixedNSGA2(population, populationObj, ...
            populationCon, cfg, op, scheduleSeeds(generation));
    else
        schedule = mdt.makeDESchedule(N, D, op.CR, scheduleSeeds(generation));
        if algorithm == "B0"
            offspring = mdt.generateRoundDE(population, cfg, op, schedule);
        else
            offspring = mdt.generateTypePreservingDE(population, cfg, op, schedule);
        end
    end
    if ismember(algorithm, ["B4", "B4F", "B4R", "B5", "B5S"])
        if ismember(algorithm, ["B4F", "B5", "B5S"])
            noveltyFraction = op.noveltyFractionMin;
        else
            noveltyFraction = mdt.computeNoveltyFraction(discoveryStagnation, ...
                op.noveltyFractionMin, op.noveltyFractionMax, ...
                op.stagnationHorizon);
        end
        injectionCount = min([N, cfg.Q, max(1, ceil(noveltyFraction*N))]);
        injectionSeed = mod(scheduleSeeds(generation)+104729, 2^32-1);
        if algorithm == "B4R"
            [offspring, ~] = mdt.injectRandomDiscreteStates( ...
                offspring, cfg, injectionCount, injectionSeed);
        elseif algorithm == "B5S"
            [offspring, ~] = mdt.injectNovelDiscreteStatesSparse( ...
                offspring, cfg, visitLedger, injectionCount, ...
                injectionSeed, "affine");
        else
            [offspring, ~] = mdt.injectNovelDiscreteStates( ...
                offspring, cfg, visitCounts, injectionCount, injectionSeed);
        end
        noveltyFractionTimeline(generation) = noveltyFraction;
        noveltyInjectionCountTimeline(generation) = injectionCount;
    end
    [offspringObj, offspringCon] = mdt.evaluate(offspring, cfg);
    offspringRanks = round(offspring(:, 3:end))*discretePowers';
    if useSparseLedger
        visitLedger = mdt.observeSparseLedger(visitLedger, offspringRanks);
    else
        visitCounts = visitCounts + ...
            accumarray(offspringRanks+1, 1, [cfg.Q, 1]);
    end
    offspringFeasible = all(offspringCon <= 0, 2);
    feasibleRanks = unique(offspringRanks(offspringFeasible));
    if useSparseLedger
        previousFeasibleCounts = ...
            mdt.querySparseLedger(feasibleLedger, feasibleRanks);
        newRanks = feasibleRanks(previousFeasibleCounts == 0);
        feasibleLedger = mdt.observeSparseLedger(feasibleLedger, feasibleRanks);
    else
        newRanks = feasibleRanks(~seenFeasibleDiscreteStates(feasibleRanks+1));
        seenFeasibleDiscreteStates(feasibleRanks+1) = true;
    end
    newFeasibleDiscreteStateTimeline(generation) = numel(newRanks);
    if ismember(algorithm, ["B4", "B4R"])
        if isempty(newRanks)
            discoveryStagnation = discoveryStagnation+1;
        else
            discoveryStagnation = 0;
        end
    end
    combinedX = [population; offspring];
    combinedObj = [populationObj; offspringObj];
    combinedCon = [populationCon; offspringCon];
    switch algorithm
        case {"B0", "B1", "B4", "B4F", "B4R", "B5", "B5S", "N2"}
            [population, populationObj, populationCon] = ...
                mdt.selectPopulation(combinedX, combinedObj, combinedCon, N, cfg);
        case "B2"
            [population, populationObj, populationCon] = ...
                mdt.selectPopulationNiching( ...
                combinedX, combinedObj, combinedCon, N, cfg);
        case "B3"
            minimumQuota = 2;
            if isfield(op, 'minimumComponentQuota')
                minimumQuota = op.minimumComponentQuota;
            end
            [population, populationObj, populationCon, selectionInfo] = ...
                mdt.selectPopulationOracle( ...
                combinedX, combinedObj, combinedCon, N, cfg, minimumQuota);
            protectedCountTimeline(generation) = selectionInfo.protectedCount;
    end
    archive = mdt.updateArchive(archive, offspring, offspringObj, ...
        offspringCon, archiveCapacity, cfg);
    [discoveryX, discoveryObj, discoveryCon] = updateDiscoveryFront( ...
        discoveryX, discoveryObj, discoveryCon, ...
        offspring, offspringObj, offspringCon);

    nfe = (generation+1)*N;
    row = generation+1;
    [trace(row, :), hit] = makeTraceRow(row, generation, nfe, ...
        offspring, offspringObj, offspringCon, archive, ...
        discoveryX, discoveryObj, discoveryCon, cfg, truth, ...
        referenceSet, referenceComponents);
    pcrTimeline(row+1) = mean(eventObserved | hit);
    newHit = hit & ~eventObserved;
    firstHitCheckpoint(newHit) = nfe;
    eventObserved = eventObserved | hit;
end
runtimeSeconds = toc(started);
endedAt = utcNow();

metrics = struct();
metrics.schema = "mdt.optimizer-metrics.v0.1";
metrics.algorithm = algorithm;
metrics.evaluations = budget;
metrics.nfeTimeline = nfeTimeline;
metrics.pcrTimeline = pcrTimeline;
metrics.pcrAuc = mdt.computePcrAuc(nfeTimeline, pcrTimeline, budget);
metrics.finalPcr = pcrTimeline(end);
metrics.finalHv = trace(end, 10);
metrics.finalIgdPlus = trace(end, 11);
metrics.finalMeanComponentIgdPlus = trace(end, 12);
metrics.meanDuplicateRate = mean(trace(:, 6));
metrics.noFeasibleCheckpointRate = mean(trace(:, 9) == 0);
metrics.firstHitCheckpointNfe = firstHitCheckpoint;
metrics.firstHitEventObserved = eventObserved;
metrics.runtimeSeconds = runtimeSeconds;

audit = struct();
audit.schema = "mdt.optimizer-audit.v0.1";
audit.seed = seed;
audit.initialPopulation = initialPopulation;
audit.scheduleSeeds = scheduleSeeds;
audit.sharedScheduleRule = "seed + generation";
audit.truthUsedBySelection = algorithm == "B3";
audit.truthUsedByGeneration = false;
audit.truthUsedByMetricsOnly = true;
audit.selectionStrategy = selectionStrategy(algorithm);
audit.protectedCountTimeline = protectedCountTimeline;
audit.noveltyFractionTimeline = noveltyFractionTimeline;
audit.noveltyInjectionCountTimeline = noveltyInjectionCountTimeline;
audit.noveltyTargeting = noveltyTargeting(algorithm);
audit.newFeasibleDiscreteStateTimeline = newFeasibleDiscreteStateTimeline;
if useSparseLedger
    audit.visitLedgerBackend = "sparse";
    audit.visitLedgerStoredStateCount = visitLedger.storedStateCount;
    audit.seenFeasibleDiscreteStatesFinal = feasibleLedger.storedStateCount;
    audit.evaluatedDiscreteStateCoverageFinal = ...
        visitLedger.storedStateCount/cfg.Q;
else
    audit.visitLedgerBackend = "dense";
    audit.visitLedgerStoredStateCount = nnz(visitCounts > 0);
    audit.seenFeasibleDiscreteStatesFinal = nnz(seenFeasibleDiscreteStates);
    audit.evaluatedDiscreteStateCoverageFinal = nnz(visitCounts > 0)/cfg.Q;
end
audit.numericType = "double";
audit.device = "CPU";
audit.startedAt = startedAt;
audit.endedAt = endedAt;

result = struct();
result.schema = "mdt.optimizer-result.v0.1";
result.algorithm = algorithm;
result.operator = op;
result.metrics = metrics;
result.trace = trace;
result.traceColumns = ["checkpoint", "generation", "nfe", "pcr", ...
    "feasibleRate", "duplicateRate", "discreteInvalidRate", ...
    "bandInvalidRate", "archiveSize", "hv", "igdPlus", ...
    "meanComponentIgdPlus"];
result.finalPopulation = struct('X', population, 'obj', populationObj, ...
    'con', populationCon);
result.finalArchive = archive;
result.audit = audit;
end

function value = selectionStrategy(algorithm)
switch algorithm
    case {"B0", "B1", "B4", "B4F", "B4R", "B5", "B5S"}
        value = "objective_crowding";
    case "B2"
        value = "ordinary_decision_niching";
    case "B3"
        value = "oracle_component_protection";
    case "N2"
        value = "nsga2_rank_crowding";
end
end

function value = noveltyTargeting(algorithm)
if ismember(algorithm, ["B4", "B4F", "B5"])
    value = "least_visited";
elseif algorithm == "B5S"
    value = "least_visited_sparse_affine";
elseif algorithm == "B4R"
    value = "uniform_random";
else
    value = "none";
end
end

function value = utcNow()
value = string(datetime('now', 'TimeZone', 'local', ...
    'Format', "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"));
end

function [row, hit] = makeTraceRow(checkpoint, generation, nfe, X, obj, con, ...
    archive, discoveryX, discoveryObj, discoveryCon, cfg, truth, ...
    referenceSet, referenceComponents)
diag = mdt.computeDiagnostics(X, obj, con, cfg, truth);
hit = hitRelevantComponents(discoveryX, discoveryObj, discoveryCon, cfg, truth);
if isempty(archive.X)
    hv = 0;
    igdPlus = Inf;
    meanComponentIgdPlus = Inf;
else
    hv = mdt.computeHypervolume2D(archive.obj, [1.1, 1.1]);
    igdPlus = mdt.computeIgdPlus(archive.obj, referenceSet);
    meanComponentIgdPlus = mdt.computeMeanComponentIgdPlus( ...
        archive.obj, referenceSet, referenceComponents);
end
row = [checkpoint, generation, nfe, mean(hit), mean(all(con <= 0, 2)), ...
    diag.duplicateRate, diag.discreteConstraintInvalidRate, ...
    diag.bandConstraintInvalidRate, size(archive.X, 1), hv, igdPlus, ...
    meanComponentIgdPlus];
end

function hit = hitRelevantComponents(X, obj, con, cfg, truth)
hit = false(truth.nParetoRelevantComponents, 1);
if isempty(X)
    return;
end
if any(~all(con <= 0, 2))
    error('mdt:DiscoveryFrontInvalid', ...
        'Discovery front must contain feasible points only.');
end
discrete = round(X(:, 3:end));
powers = cfg.q.^((cfg.L-1):-1:0);
externalRank = discrete*powers';
candidateComponent = truth.componentIdByState(externalRank+1);
relevantComponents = find(truth.paretoRelevantByComponent);
for i = 1:numel(relevantComponents)
    hit(i) = any(candidateComponent == relevantComponents(i));
end
if any(~isfinite(obj), 'all')
    error('mdt:DiscoveryFrontInvalid', ...
        'Discovery objectives must be finite.');
end
end

function [frontX, frontObj, frontCon] = updateDiscoveryFront( ...
    oldX, oldObj, oldCon, X, obj, con)
feasible = all(con <= 0, 2);
combinedX = [oldX; X(feasible, :)];
combinedObj = [oldObj; obj(feasible, :)];
combinedCon = [oldCon; con(feasible, :)];
if isempty(combinedX)
    frontX = combinedX;
    frontObj = combinedObj;
    frontCon = combinedCon;
    return;
end

[sortedObj, order] = sortrows(combinedObj, [1, 2]);
sortedX = combinedX(order, :);
sortedCon = combinedCon(order, :);
keep = false(size(sortedObj, 1), 1);
bestPriorSecond = Inf;
start = 1;
while start <= size(sortedObj, 1)
    finish = start;
    while finish < size(sortedObj, 1) && ...
            sortedObj(finish+1, 1) == sortedObj(start, 1)
        finish = finish + 1;
    end
    group = start:finish;
    minimumSecond = min(sortedObj(group, 2));
    if minimumSecond < bestPriorSecond
        keep(group(sortedObj(group, 2) == minimumSecond)) = true;
        bestPriorSecond = minimumSecond;
    end
    start = finish + 1;
end
frontX = sortedX(keep, :);
frontObj = sortedObj(keep, :);
frontCon = sortedCon(keep, :);
end
