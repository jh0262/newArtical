function result = runB0B1SelectionSmoke(outputDir)
%RUNB0B1SELECTIONSMOKE Run the fixed-seed five-generation selection smoke.
%
% This is bounded software verification. It is not a multi-seed performance
% experiment and does not authorize comparative scientific claims.

arguments
    outputDir (1,1) string
end

if strlength(outputDir) == 0
    error('mdt:InvalidOutputDirectory', 'outputDir must be nonempty.');
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite an existing selection smoke bundle: %s', outputDir);
end

mkdir(outputDir);
startedUtc = utcNow();

try
    cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
    truth = mdt.enumerateTruth(cfg);
    N = 30;
    D = 2 + cfg.L;
    generations = 5;
    archiveCapacity = 30;
    seed = 20260829;
    op = struct('F', 0.5, 'CR', 0.9, 'FCategory', 0.5);

    stream = RandStream('mt19937ar', 'Seed', seed);
    initialPopulation = [rand(stream, N, 2), ...
        floor(cfg.q*rand(stream, N, cfg.L))];
    [initialObj, initialCon] = mdt.evaluate(initialPopulation, cfg);

    populationB0 = initialPopulation;
    populationB1 = initialPopulation;
    populationObjB0 = initialObj;
    populationObjB1 = initialObj;
    populationConB0 = initialCon;
    populationConB1 = initialCon;
    archiveB0 = mdt.updateArchive([], initialPopulation, initialObj, ...
        initialCon, archiveCapacity, cfg);
    archiveB1 = archiveB0;

    historyXB0 = initialPopulation;
    historyXB1 = initialPopulation;
    historyObjB0 = initialObj;
    historyObjB1 = initialObj;
    historyConB0 = initialCon;
    historyConB1 = initialCon;

    evaluatedB0 = [(1:N)', zeros(N, 1), initialPopulation, initialObj, initialCon];
    evaluatedB1 = evaluatedB0;
    populationTraceB0 = [zeros(N, 1), (1:N)', initialPopulation, initialObj, initialCon];
    populationTraceB1 = populationTraceB0;
    scheduleDonors = zeros(generations*N, 5);
    scheduleCrossMask = zeros(generations*N, 2+D);
    scheduleRoundDraw = zeros(generations*N, 2+D);
    scheduleCategoryDraw = zeros(generations*N, 2+D);

    checkpointCount = generations + 2;
    nfeTimeline = 0:N:((generations+1)*N);
    pcrTimelineB0 = zeros(1, checkpointCount);
    pcrTimelineB1 = zeros(1, checkpointCount);
    duplicateRateB0 = zeros(1, checkpointCount);
    duplicateRateB1 = zeros(1, checkpointCount);
    discreteInvalidRateB0 = zeros(1, checkpointCount);
    discreteInvalidRateB1 = zeros(1, checkpointCount);
    bandInvalidRateB0 = zeros(1, checkpointCount);
    bandInvalidRateB1 = zeros(1, checkpointCount);
    archiveSizeB0 = zeros(1, checkpointCount);
    archiveSizeB1 = zeros(1, checkpointCount);
    populationFeasibleRateB0 = zeros(1, checkpointCount);
    populationFeasibleRateB1 = zeros(1, checkpointCount);

    initialDiagnostics = mdt.computeDiagnostics(initialPopulation, initialObj, ...
        initialCon, cfg, truth);
    everHitB0 = initialDiagnostics.hitParetoComponents;
    everHitB1 = everHitB0;
    initialIndex = 2;
    pcrTimelineB0(initialIndex) = mean(everHitB0);
    pcrTimelineB1(initialIndex) = mean(everHitB1);
    duplicateRateB0(initialIndex) = initialDiagnostics.duplicateRate;
    duplicateRateB1(initialIndex) = initialDiagnostics.duplicateRate;
    discreteInvalidRateB0(initialIndex) = ...
        initialDiagnostics.discreteConstraintInvalidRate;
    discreteInvalidRateB1(initialIndex) = ...
        initialDiagnostics.discreteConstraintInvalidRate;
    bandInvalidRateB0(initialIndex) = initialDiagnostics.bandConstraintInvalidRate;
    bandInvalidRateB1(initialIndex) = initialDiagnostics.bandConstraintInvalidRate;
    archiveSizeB0(initialIndex) = size(archiveB0.X, 1);
    archiveSizeB1(initialIndex) = size(archiveB1.X, 1);
    populationFeasibleRateB0(initialIndex) = mean(all(initialCon <= 0, 2));
    populationFeasibleRateB1(initialIndex) = populationFeasibleRateB0(initialIndex);

    for generation = 1:generations
        schedule = mdt.makeDESchedule(N, D, op.CR, seed+generation);
        traceRows = (generation-1)*N + (1:N);
        targets = (1:N)';
        scheduleDonors(traceRows, :) = [generation*ones(N, 1), targets, ...
            schedule.donorIndices];
        scheduleCrossMask(traceRows, :) = [generation*ones(N, 1), targets, ...
            double(schedule.crossMask)];
        scheduleRoundDraw(traceRows, :) = [generation*ones(N, 1), targets, ...
            schedule.roundDraw];
        scheduleCategoryDraw(traceRows, :) = [generation*ones(N, 1), targets, ...
            schedule.categoryDraw];

        offspringB0 = mdt.generateRoundDE(populationB0, cfg, op, schedule);
        offspringB1 = mdt.generateTypePreservingDE(populationB1, cfg, op, schedule);
        [offspringObjB0, offspringConB0] = mdt.evaluate(offspringB0, cfg);
        [offspringObjB1, offspringConB1] = mdt.evaluate(offspringB1, cfg);

        [populationB0, populationObjB0, populationConB0] = ...
            mdt.selectPopulation([populationB0; offspringB0], ...
            [populationObjB0; offspringObjB0], ...
            [populationConB0; offspringConB0], N, cfg);
        [populationB1, populationObjB1, populationConB1] = ...
            mdt.selectPopulation([populationB1; offspringB1], ...
            [populationObjB1; offspringObjB1], ...
            [populationConB1; offspringConB1], N, cfg);
        archiveB0 = mdt.updateArchive(archiveB0, offspringB0, ...
            offspringObjB0, offspringConB0, archiveCapacity, cfg);
        archiveB1 = mdt.updateArchive(archiveB1, offspringB1, ...
            offspringObjB1, offspringConB1, archiveCapacity, cfg);

        historyXB0 = [historyXB0; offspringB0]; %#ok<AGROW>
        historyXB1 = [historyXB1; offspringB1]; %#ok<AGROW>
        historyObjB0 = [historyObjB0; offspringObjB0]; %#ok<AGROW>
        historyObjB1 = [historyObjB1; offspringObjB1]; %#ok<AGROW>
        historyConB0 = [historyConB0; offspringConB0]; %#ok<AGROW>
        historyConB1 = [historyConB1; offspringConB1]; %#ok<AGROW>

        evaluationIndices = (generation*N + (1:N))';
        evaluatedB0 = [evaluatedB0; evaluationIndices, ...
            generation*ones(N, 1), offspringB0, offspringObjB0, offspringConB0]; %#ok<AGROW>
        evaluatedB1 = [evaluatedB1; evaluationIndices, ...
            generation*ones(N, 1), offspringB1, offspringObjB1, offspringConB1]; %#ok<AGROW>
        populationTraceB0 = [populationTraceB0; generation*ones(N, 1), ...
            targets, populationB0, populationObjB0, populationConB0]; %#ok<AGROW>
        populationTraceB1 = [populationTraceB1; generation*ones(N, 1), ...
            targets, populationB1, populationObjB1, populationConB1]; %#ok<AGROW>

        diagnosticsB0 = mdt.computeDiagnostics(historyXB0, historyObjB0, ...
            historyConB0, cfg, truth);
        diagnosticsB1 = mdt.computeDiagnostics(historyXB1, historyObjB1, ...
            historyConB1, cfg, truth);
        everHitB0 = everHitB0 | diagnosticsB0.hitParetoComponents;
        everHitB1 = everHitB1 | diagnosticsB1.hitParetoComponents;
        checkpoint = generation + 2;
        pcrTimelineB0(checkpoint) = mean(everHitB0);
        pcrTimelineB1(checkpoint) = mean(everHitB1);
        duplicateRateB0(checkpoint) = diagnosticsB0.duplicateRate;
        duplicateRateB1(checkpoint) = diagnosticsB1.duplicateRate;
        discreteInvalidRateB0(checkpoint) = ...
            diagnosticsB0.discreteConstraintInvalidRate;
        discreteInvalidRateB1(checkpoint) = ...
            diagnosticsB1.discreteConstraintInvalidRate;
        bandInvalidRateB0(checkpoint) = diagnosticsB0.bandConstraintInvalidRate;
        bandInvalidRateB1(checkpoint) = diagnosticsB1.bandConstraintInvalidRate;
        archiveSizeB0(checkpoint) = size(archiveB0.X, 1);
        archiveSizeB1(checkpoint) = size(archiveB1.X, 1);
        populationFeasibleRateB0(checkpoint) = mean(all(populationConB0 <= 0, 2));
        populationFeasibleRateB1(checkpoint) = mean(all(populationConB1 <= 0, 2));
    end

    metrics = struct();
    metrics.schema = "mdt.selection-smoke-metrics.v0.1";
    metrics.nfeTimeline = nfeTimeline;
    metrics.pcrTimelineB0 = pcrTimelineB0;
    metrics.pcrTimelineB1 = pcrTimelineB1;
    metrics.pcrAucB0 = mdt.computePcrAuc(nfeTimeline, pcrTimelineB0, nfeTimeline(end));
    metrics.pcrAucB1 = mdt.computePcrAuc(nfeTimeline, pcrTimelineB1, nfeTimeline(end));
    metrics.duplicateRateB0 = duplicateRateB0;
    metrics.duplicateRateB1 = duplicateRateB1;
    metrics.discreteInvalidRateB0 = discreteInvalidRateB0;
    metrics.discreteInvalidRateB1 = discreteInvalidRateB1;
    metrics.bandInvalidRateB0 = bandInvalidRateB0;
    metrics.bandInvalidRateB1 = bandInvalidRateB1;
    metrics.archiveSizeB0 = archiveSizeB0;
    metrics.archiveSizeB1 = archiveSizeB1;
    metrics.populationFeasibleRateB0 = populationFeasibleRateB0;
    metrics.populationFeasibleRateB1 = populationFeasibleRateB1;
    metrics.finalHitParetoComponentsB0 = everHitB0;
    metrics.finalHitParetoComponentsB1 = everHitB1;

    runConfig = makeRunConfig(cfg, N, generations, archiveCapacity, seed, op);
    environment = makeEnvironment();
    writeJson(fullfile(outputDir, "config.json"), runConfig);
    writeMatrix(fullfile(outputDir, "initial_population.csv"), initialPopulation);
    writeMatrix(fullfile(outputDir, "schedule_donors.csv"), scheduleDonors);
    writeMatrix(fullfile(outputDir, "schedule_cross_mask.csv"), scheduleCrossMask);
    writeMatrix(fullfile(outputDir, "schedule_round_draw.csv"), scheduleRoundDraw);
    writeMatrix(fullfile(outputDir, "schedule_category_draw.csv"), scheduleCategoryDraw);
    writeMatrix(fullfile(outputDir, "evaluated_b0.csv"), evaluatedB0);
    writeMatrix(fullfile(outputDir, "evaluated_b1.csv"), evaluatedB1);
    writeMatrix(fullfile(outputDir, "population_trace_b0.csv"), populationTraceB0);
    writeMatrix(fullfile(outputDir, "population_trace_b1.csv"), populationTraceB1);
    writeMatrix(fullfile(outputDir, "archive_b0.csv"), ...
        [archiveB0.X, archiveB0.obj, archiveB0.con]);
    writeMatrix(fullfile(outputDir, "archive_b1.csv"), ...
        [archiveB1.X, archiveB1.obj, archiveB1.con]);
    writeJson(fullfile(outputDir, "metrics.json"), metrics);
    writeJson(fullfile(outputDir, "environment.json"), environment);
    writeText(fullfile(outputDir, "stdout.log"), join([
        "B0/B1 five-generation environmental-selection software smoke completed."
        "Scope: deterministic software verification; no performance inference."
        "Seed: " + seed
        "Population and archive capacity: " + N
        "Generations: " + generations
        "Evaluations per branch: " + nfeTimeline(end)], newline));
    writeText(fullfile(outputDir, "stderr.log"), "");

    manifest = struct();
    manifest.schema = "mdt.selection-smoke-run-manifest.v0.1";
    manifest.status = "SELECTION_SMOKE_COMPLETE";
    manifest.startedUtc = startedUtc;
    manifest.completedUtc = utcNow();
    manifest.scope = "SOFTWARE_SMOKE_NOT_CONFIRMATORY";
    manifest.frozenResearchSpecSha256 = cfg.frozenSpecSha256;
    manifest.selectionSmokeSpecSha256 = ...
        "2B8470CC094E92951DEB6E3BD28584C8072E461761CCDC6CF2BEA1862632FBDE";
    manifest.populationSize = N;
    manifest.archiveCapacity = archiveCapacity;
    manifest.generations = generations;
    manifest.evaluationsPerBranch = nfeTimeline(end);
    manifest.performanceClaimAuthorized = false;
    manifest.randomnessEstimationRun = false;
    manifest.formalOptimizationRun = false;
    manifest.usesTruthInSelection = false;
    manifest.requiredArtifactCount = 17;
    manifest.sourceHashes = sourceHashes();
    writeJson(fullfile(outputDir, "manifest.json"), manifest);

    result = struct();
    result.finalPopulationB0 = populationB0;
    result.finalPopulationB1 = populationB1;
    result.archiveB0 = archiveB0;
    result.archiveB1 = archiveB1;
    result.metrics = metrics;
catch ME
    writeText(fullfile(outputDir, "stderr.log"), ...
        string(getReport(ME, 'extended', 'hyperlinks', 'off')));
    failure = struct();
    failure.schema = "mdt.selection-smoke-run-manifest.v0.1";
    failure.status = "SELECTION_SMOKE_FAILED";
    failure.startedUtc = startedUtc;
    failure.completedUtc = utcNow();
    failure.identifier = string(ME.identifier);
    failure.message = string(ME.message);
    writeJson(fullfile(outputDir, "manifest.json"), failure);
    rethrow(ME);
end
end

function config = makeRunConfig(cfg, N, generations, archiveCapacity, seed, op)
config = struct();
config.schema = "mdt.selection-smoke-config.v0.1";
config.scope = "SOFTWARE_SMOKE_NOT_CONFIRMATORY";
config.instance = cfg;
config.populationSize = N;
config.archiveCapacity = archiveCapacity;
config.generations = generations;
config.evaluationsPerBranch = (generations+1)*N;
config.seed = seed;
config.generationScheduleSeedRule = "seed + generation";
config.operator = op;
config.constraintHandling = "feasibility-first normalized-CV";
config.feasibleSelection = "nondominated-front plus objective crowding";
config.archive = "unique feasible nondominated objective-crowding bounded";
config.archiveFeedsDonorSelection = false;
config.truthLabelsUsedBySelection = false;
config.sharedInitialPopulation = true;
config.sharedGenerationSchedules = true;
config.randomnessEstimation = false;
config.columnSchemas = struct( ...
    'schedule', "generation,target,values", ...
    'evaluated', "evaluation_index,generation,X(1:D),objective(1:2),constraint(1:2)", ...
    'populationTrace', "generation,row,X(1:D),objective(1:2),constraint(1:2)", ...
    'archive', "X(1:D),objective(1:2),constraint(1:2)");
end

function environment = makeEnvironment()
environment = struct();
environment.schema = "mdt.environment.v0.1";
environment.matlabVersion = version;
environment.matlabRelease = version('-release');
environment.computer = computer;
environment.platform = string(system_dependent('getos'));
environment.numericType = "double";
environment.device = "CPU";
end

function hashes = sourceHashes()
functionPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(fileparts(functionPath)));
matlabFiles = dir(fullfile(projectRoot, 'matlab', '**', '*.m'));
absolutePaths = strings(numel(matlabFiles)+1, 1);
absolutePaths(1) = fullfile(projectRoot, 'docs', ...
    'SELECTION_ARCHIVE_SMOKE_SPEC.md');
for i = 1:numel(matlabFiles)
    absolutePaths(i+1) = fullfile(matlabFiles(i).folder, matlabFiles(i).name);
end
relativePaths = extractAfter(absolutePaths, strlength(string(projectRoot))+1);
relativePaths = replace(relativePaths, "\", "/");
[relativePaths, order] = sort(relativePaths);
absolutePaths = absolutePaths(order);
hashes = repmat(struct('path', "", 'sha256', ""), numel(relativePaths), 1);
for i = 1:numel(relativePaths)
    hashes(i).path = relativePaths(i);
    hashes(i).sha256 = sha256File(absolutePaths(i));
end
end

function value = sha256File(path)
fileId = fopen(path, 'r');
if fileId < 0
    error('mdt:HashReadFailure', 'Unable to open source for hashing: %s', path);
end
cleanup = onCleanup(@() fclose(fileId));
data = fread(fileId, Inf, '*uint8');
digest = javaMethod('getInstance', 'java.security.MessageDigest', 'SHA-256');
digest.update(typecast(data, 'int8'));
bytes = typecast(digest.digest(), 'uint8');
value = string(upper(reshape(dec2hex(bytes, 2).', 1, [])));
end

function value = utcNow()
value = string(datetime('now', 'TimeZone', 'UTC', ...
    'Format', "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"));
end

function writeJson(path, value)
writeText(path, string(jsonencode(value, PrettyPrint=true)));
end

function writeMatrix(path, value)
writematrix(value, path, 'Delimiter', ',');
end

function writeText(path, value)
fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('mdt:ArtifactWriteFailure', 'Unable to open artifact for writing: %s', path);
end
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, char(value), 'char');
end
