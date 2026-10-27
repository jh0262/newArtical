function result = runB0B1Smoke(outputDir)
%RUNB0B1SMOKE Run one fixed-seed B0/B1 offspring-generation smoke bundle.
%
% This is a software verification smoke only. It performs no environmental
% selection, iterative optimization, or confirmatory performance analysis.

arguments
    outputDir (1,1) string
end

if strlength(outputDir) == 0
    error('mdt:InvalidOutputDirectory', 'outputDir must be nonempty.');
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite an existing smoke bundle: %s', outputDir);
end

mkdir(outputDir);
startedUtc = utcNow();

try
    cfg = mdt.makeInstance("D", 3, 3, 0.15, 1);
    truth = mdt.enumerateTruth(cfg);
    N = 30;
    D = 2 + cfg.L;
    seed = 20260829;
    op = struct('F', 0.5, 'CR', 0.9, 'FCategory', 0.5);

    stream = RandStream('mt19937ar', 'Seed', seed);
    initialPopulation = [rand(stream, N, 2), ...
        floor(cfg.q*rand(stream, N, cfg.L))];
    schedule = mdt.makeDESchedule(N, D, op.CR, seed);

    offspringB0 = mdt.generateRoundDE(initialPopulation, cfg, op, schedule);
    offspringB1 = mdt.generateTypePreservingDE(initialPopulation, cfg, op, schedule);
    if ~isequal(offspringB0(:, 1:2), offspringB1(:, 1:2))
        error('mdt:ContinuousMismatch', ...
            'B0 and B1 continuous offspring differ under the common schedule.');
    end

    [objectivesParent, constraintsParent] = mdt.evaluate(initialPopulation, cfg);
    [objectivesB0, constraintsB0] = mdt.evaluate(offspringB0, cfg);
    [objectivesB1, constraintsB1] = mdt.evaluate(offspringB1, cfg);

    diagnosticsParent = mdt.computeDiagnostics(initialPopulation, ...
        objectivesParent, constraintsParent, cfg, truth);
    diagnosticsB0 = mdt.computeDiagnostics([initialPopulation; offspringB0], ...
        [objectivesParent; objectivesB0], ...
        [constraintsParent; constraintsB0], cfg, truth);
    diagnosticsB1 = mdt.computeDiagnostics([initialPopulation; offspringB1], ...
        [objectivesParent; objectivesB1], ...
        [constraintsParent; constraintsB1], cfg, truth);

    nfeTimeline = [0, N, 2*N];
    pcrTimelineB0 = [0, diagnosticsParent.paretoComponentRecall, ...
        diagnosticsB0.paretoComponentRecall];
    pcrTimelineB1 = [0, diagnosticsParent.paretoComponentRecall, ...
        diagnosticsB1.paretoComponentRecall];

    metrics = struct();
    metrics.schema = "mdt.smoke-metrics.v0.1";
    metrics.nfeTimeline = nfeTimeline;
    metrics.pcrTimelineB0 = pcrTimelineB0;
    metrics.pcrTimelineB1 = pcrTimelineB1;
    metrics.pcrAucB0 = mdt.computePcrAuc(nfeTimeline, pcrTimelineB0, 2*N);
    metrics.pcrAucB1 = mdt.computePcrAuc(nfeTimeline, pcrTimelineB1, 2*N);
    metrics.parent = diagnosticsParent;
    metrics.b0Combined = diagnosticsB0;
    metrics.b1Combined = diagnosticsB1;

    runConfig = struct();
    runConfig.schema = "mdt.b0-b1-smoke-config.v0.1";
    runConfig.scope = "SOFTWARE_SMOKE_NOT_CONFIRMATORY";
    runConfig.instance = cfg;
    runConfig.populationSize = N;
    runConfig.offspringPerBranch = N;
    runConfig.generations = 1;
    runConfig.seed = seed;
    runConfig.operator = op;
    runConfig.sharedInitialPopulation = true;
    runConfig.sharedSchedule = true;
    runConfig.environmentalSelection = false;
    runConfig.iterativeOptimization = false;

    environment = struct();
    environment.schema = "mdt.environment.v0.1";
    environment.matlabVersion = version;
    environment.matlabRelease = version('-release');
    environment.computer = computer;
    environment.platform = string(system_dependent('getos'));

    writeJson(fullfile(outputDir, "config.json"), runConfig);
    writeMatrix(fullfile(outputDir, "initial_population.csv"), initialPopulation);
    writeMatrix(fullfile(outputDir, "donor_indices.csv"), schedule.donorIndices);
    writeMatrix(fullfile(outputDir, "cross_mask.csv"), double(schedule.crossMask));
    writeMatrix(fullfile(outputDir, "round_draw.csv"), schedule.roundDraw);
    writeMatrix(fullfile(outputDir, "category_draw.csv"), schedule.categoryDraw);
    writeMatrix(fullfile(outputDir, "offspring_b0.csv"), offspringB0);
    writeMatrix(fullfile(outputDir, "offspring_b1.csv"), offspringB1);
    writeMatrix(fullfile(outputDir, "objectives_parent.csv"), objectivesParent);
    writeMatrix(fullfile(outputDir, "constraints_parent.csv"), constraintsParent);
    writeMatrix(fullfile(outputDir, "objectives_b0.csv"), objectivesB0);
    writeMatrix(fullfile(outputDir, "constraints_b0.csv"), constraintsB0);
    writeMatrix(fullfile(outputDir, "objectives_b1.csv"), objectivesB1);
    writeMatrix(fullfile(outputDir, "constraints_b1.csv"), constraintsB1);
    writeJson(fullfile(outputDir, "metrics.json"), metrics);
    writeJson(fullfile(outputDir, "environment.json"), environment);

    stdoutLines = [
        "B0/B1 fixed-seed one-generation software smoke completed."
        "Scope: software verification only; no performance inference."
        "Seed: " + seed
        "Population per branch: " + N
        "Evaluations per branch including parents: " + 2*N
        "Continuous offspring equality: true"];
    writeText(fullfile(outputDir, "stdout.log"), join(stdoutLines, newline));
    writeText(fullfile(outputDir, "stderr.log"), "");

    manifest = struct();
    manifest.schema = "mdt.smoke-run-manifest.v0.1";
    manifest.status = "SMOKE_COMPLETE";
    manifest.startedUtc = startedUtc;
    manifest.completedUtc = utcNow();
    manifest.scope = "SOFTWARE_SMOKE_NOT_CONFIRMATORY";
    manifest.frozenSpecSha256 = cfg.frozenSpecSha256;
    manifest.populationSize = N;
    manifest.offspringPerBranch = N;
    manifest.evaluationsPerBranch = 2*N;
    manifest.performanceClaimAuthorized = false;
    manifest.environmentalSelectionImplemented = false;
    manifest.formalOptimizationRun = false;
    manifest.continuousOffspringEqual = true;
    manifest.requiredArtifactCount = 19;
    writeJson(fullfile(outputDir, "manifest.json"), manifest);

    result = struct();
    result.initialPopulation = initialPopulation;
    result.offspringB0 = offspringB0;
    result.offspringB1 = offspringB1;
    result.metrics = metrics;
catch ME
    writeText(fullfile(outputDir, "stderr.log"), ...
        string(getReport(ME, 'extended', 'hyperlinks', 'off')));
    failure = struct();
    failure.schema = "mdt.smoke-run-manifest.v0.1";
    failure.status = "SMOKE_FAILED";
    failure.startedUtc = startedUtc;
    failure.completedUtc = utcNow();
    failure.identifier = string(ME.identifier);
    failure.message = string(ME.message);
    writeJson(fullfile(outputDir, "manifest.json"), failure);
    rethrow(ME);
end
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
