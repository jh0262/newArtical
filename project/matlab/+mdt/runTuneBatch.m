function summary = runTuneBatch(outputDir)
%RUNTUNEBATCH Execute the authorized frozen TUNE-01 matrix once.

arguments
    outputDir (1,1) string
end
if strlength(outputDir) == 0
    error('mdt:InvalidOutputDirectory', 'outputDir must be nonempty.');
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite a TUNE-01 batch: %s', outputDir);
end

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
tuneSpecPath = fullfile(projectRoot, 'docs', 'TUNE_01_SPEC.md');
planPath = fullfile(projectRoot, '.light', 'e2', 'PROJECT_PLAN.md');
authorizationPath = fullfile(projectRoot, '.light', 'e2', ...
    'tune_authorization.json');
testEvidencePath = fullfile(projectRoot, 'evidence', ...
    'tune01_preflight_junit.xml');
tuneSpecSha256 = sha256File(tuneSpecPath);
planSha256 = sha256File(planPath);
authorizationSha256 = sha256File(authorizationPath);
testEvidenceSha256 = sha256File(testEvidencePath);
sourceFiles = mdt.collectTuneSourceHashes(projectRoot);

mkdir(outputDir);
mkdir(fullfile(outputDir, 'runs'));
batchStartedAt = utcNow();
batchTimer = tic;
cfg = mdt.makeInstance("D", 5, 3, 0.25, 1);
truth = mdt.enumerateTruth(cfg);
if truth.nParetoRelevantComponents ~= 25
    error('mdt:TuneTruthMismatch', ...
        'D-5-3-L must have exactly 25 Pareto-relevant components.');
end
N = 100;
budget = 50000;
archiveCapacity = 100;
seeds = 2026083001:2026083005;
grid = mdt.makeTuneGrid();

batchConfig = struct();
batchConfig.schema = "mdt.tune-batch-config.v0.1";
batchConfig.matrixRow = "TUNE-01";
batchConfig.instance = cfg;
batchConfig.populationSize = N;
batchConfig.evaluationBudget = budget;
batchConfig.archiveCapacity = archiveCapacity;
batchConfig.seeds = seeds;
batchConfig.grid = grid;
batchConfig.selectionRule = [
    "max median AUC_PCR"
    "max worst-seed AUC_PCR"
    "max median final PCR"
    "max median final HV"
    "min median duplicate rate"
    "lexicographically smallest config ID"];
batchConfig.scope = "TUNING_ONLY_NO_H2_DECISION";
batchConfig.tuneSpecSha256 = tuneSpecSha256;
batchConfig.planSha256 = planSha256;
batchConfig.authorizationSha256 = authorizationSha256;
writeJson(fullfile(outputDir, 'batch_config.json'), batchConfig);
writeJson(fullfile(outputDir, 'source_manifest.json'), struct( ...
    'schema', "mdt.source-manifest.v0.1", 'files', sourceFiles));
writeJson(fullfile(outputDir, 'batch_manifest.json'), struct( ...
    'schema', "mdt.tune-batch-manifest.v0.1", ...
    'status', "RUNNING", 'startedAt', batchStartedAt, ...
    'scope', "TUNING_ONLY_NO_H2_DECISION", ...
    'expectedSelectionRuns', 240, 'completedSelectionRuns', 0, ...
    'failedSelectionRuns', 0));

rowCount = 2*24*numel(seeds);
rows = table('Size', [rowCount, 14], 'VariableTypes', ...
    {'string','string','double','double','double','double','double', ...
    'double','double','double','double','double','string','string'}, ...
    'VariableNames', {'algorithm','configId','seed','F','CR','FCategory', ...
    'pcrAuc','finalPcr','finalHv','duplicateRate', ...
    'noFeasibleCheckpointRate','runtimeSeconds','runDir','status'});
row = 0;
failures = strings(0, 1);
algorithms = ["B0", "B1"];
for algorithm = algorithms
    configs = grid.(char(algorithm));
    for configIndex = 1:numel(configs)
        tuneConfig = configs(configIndex);
        op = struct('F', tuneConfig.F, 'CR', tuneConfig.CR, ...
            'FCategory', tuneConfig.FCategory);
        for seed = seeds
            row = row + 1;
            relativeRunDir = fullfile('runs', lower(algorithm), ...
                tuneConfig.configId, "seed-" + seed, 'attempt-1');
            runDir = fullfile(outputDir, relativeRunDir);
            rows.algorithm(row) = algorithm;
            rows.configId(row) = tuneConfig.configId;
            rows.seed(row) = seed;
            rows.F(row) = tuneConfig.F;
            rows.CR(row) = tuneConfig.CR;
            rows.FCategory(row) = tuneConfig.FCategory;
            rows.runDir(row) = replace(relativeRunDir, "\", "/");
            try
                result = mdt.runOptimizer(algorithm, cfg, op, seed, ...
                    N, budget, archiveCapacity);
                provenance = makeProvenance(tuneConfig.configId, ...
                    tuneSpecSha256, planSha256, sourceFiles, ...
                    testEvidenceSha256);
                mdt.writeOptimizerRunBundle(runDir, result, cfg, provenance);
                rows.pcrAuc(row) = result.metrics.pcrAuc;
                rows.finalPcr(row) = result.metrics.finalPcr;
                rows.finalHv(row) = result.metrics.finalHv;
                rows.duplicateRate(row) = result.metrics.meanDuplicateRate;
                rows.noFeasibleCheckpointRate(row) = ...
                    result.metrics.noFeasibleCheckpointRate;
                rows.runtimeSeconds(row) = result.metrics.runtimeSeconds;
                rows.status(row) = "completed";
            catch ME
                rows.pcrAuc(row) = NaN;
                rows.finalPcr(row) = NaN;
                rows.finalHv(row) = NaN;
                rows.duplicateRate(row) = NaN;
                rows.noFeasibleCheckpointRate(row) = NaN;
                rows.runtimeSeconds(row) = NaN;
                rows.status(row) = "failed";
                failures(end+1, 1) = tuneConfig.configId + ...
                    "__seed-" + seed + ":" + string(ME.identifier); %#ok<AGROW>
                writeFailureBundle(runDir, algorithm, tuneConfig, seed, ...
                    ME, tuneSpecSha256, planSha256, sourceFiles, ...
                    testEvidenceSha256);
            end
        end
    end
end

writetable(rows, fullfile(outputDir, 'tune_results.csv'));
completed = rows.status == "completed";
failed = rows.status == "failed";
if any(failed)
    finalManifest = makeBatchManifest("INCOMPLETE", batchStartedAt, ...
        toc(batchTimer), sum(completed), sum(failed), failures, outputDir);
    writeJson(fullfile(outputDir, 'batch_manifest.json'), finalManifest);
    error('mdt:TuneCoverageIncomplete', ...
        'TUNE-01 has %d failed runs; no winner was frozen.', sum(failed));
end

b0Winner = mdt.selectTuneWinner(rows(rows.algorithm == "B0", :));
b1Winner = mdt.selectTuneWinner(rows(rows.algorithm == "B1", :));
b0Winner.operator = operatorFor(grid.B0, b0Winner.configId);
b1Winner.operator = operatorFor(grid.B1, b1Winner.configId);
b0Winner.scope = "TUNING_SELECTION_NOT_H2_EVIDENCE";
b1Winner.scope = "TUNING_SELECTION_NOT_H2_EVIDENCE";
writeJson(fullfile(outputDir, 'winner_b0.json'), b0Winner);
writeJson(fullfile(outputDir, 'winner_b1.json'), b1Winner);

finalManifest = makeBatchManifest("COMPLETE", batchStartedAt, ...
    toc(batchTimer), sum(completed), 0, failures, outputDir);
finalManifest.winnerB0 = b0Winner.configId;
finalManifest.winnerB1 = b1Winner.configId;
finalManifest.tuneSpecSha256 = tuneSpecSha256;
finalManifest.planSha256 = planSha256;
finalManifest.authorizationSha256 = authorizationSha256;
finalManifest.testEvidenceSha256 = testEvidenceSha256;
finalManifest.sourceManifestSha256 = ...
    sha256File(fullfile(outputDir, 'source_manifest.json'));
finalManifest.performanceClaimAuthorized = false;
finalManifest.p1Authorized = false;
finalManifest.p2Authorized = false;
writeJson(fullfile(outputDir, 'batch_manifest.json'), finalManifest);

summary = struct();
summary.schema = "mdt.tune-batch-summary.v0.1";
summary.outputDir = outputDir;
summary.completedRuns = sum(completed);
summary.failedRuns = 0;
summary.winnerB0 = b0Winner;
summary.winnerB1 = b1Winner;
summary.walltimeSeconds = finalManifest.walltimeSeconds;
summary.storageBytes = finalManifest.storageBytes;
end

function provenance = makeProvenance(configId, tuneSpecSha256, ...
    planSha256, sourceFiles, testEvidenceSha256)
provenance = struct();
provenance.matrixRow = "TUNE-01";
provenance.configId = configId;
provenance.tuneSpecSha256 = tuneSpecSha256;
provenance.planSha256 = planSha256;
provenance.sourceFiles = sourceFiles;
provenance.testEvidencePath = "evidence/tune01_preflight_junit.xml";
provenance.testEvidenceSha256 = testEvidenceSha256;
provenance.comparisonRole = "tuning";
provenance.attempt = 1;
provenance.seedRole = "randomness_estimation";
provenance.command = ["matlab", "-batch", "mdt.runTuneBatch"];
end

function op = operatorFor(configs, configId)
index = find(string({configs.configId}) == configId, 1);
if isempty(index)
    error('mdt:TuneWinnerMissing', 'Winner config ID is not in the frozen grid.');
end
op = struct('F', configs(index).F, 'CR', configs(index).CR, ...
    'FCategory', configs(index).FCategory);
end

function manifest = makeBatchManifest(status, startedAt, walltimeSeconds, ...
    completed, failed, failures, outputDir)
manifest = struct();
manifest.schema = "mdt.tune-batch-manifest.v0.1";
manifest.status = status;
manifest.startedAt = startedAt;
manifest.endedAt = utcNow();
manifest.scope = "TUNING_ONLY_NO_H2_DECISION";
manifest.expectedSelectionRuns = 240;
manifest.completedSelectionRuns = completed;
manifest.failedSelectionRuns = failed;
manifest.failures = failures;
manifest.walltimeSeconds = walltimeSeconds;
entries = dir(fullfile(outputDir, '**', '*'));
manifest.storageBytes = sum([entries(~[entries.isdir]).bytes]);
end

function writeFailureBundle(runDir, algorithm, tuneConfig, seed, ME, ...
    tuneSpecSha256, planSha256, sourceFiles, testEvidenceSha256)
if isfolder(runDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite a failed run bundle: %s', runDir);
end
mkdir(runDir);
writeJson(fullfile(runDir, 'config.json'), struct( ...
    'schema', "mdt.failed-run-config.v0.1", 'matrixRow', "TUNE-01", ...
    'algorithm', algorithm, 'config', tuneConfig, 'seed', seed, ...
    'tuneSpecSha256', tuneSpecSha256, 'planSha256', planSha256));
writeJson(fullfile(runDir, 'environment.json'), struct( ...
    'schema', "mdt.environment.v0.1", 'matlabVersion', version, ...
    'matlabRelease', version('-release'), 'computer', computer, ...
    'numericType', "double", 'device', "CPU"));
writeJson(fullfile(runDir, 'source_manifest.json'), struct( ...
    'schema', "mdt.source-manifest.v0.1", 'files', sourceFiles));
writeJson(fullfile(runDir, 'input_contract.json'), struct( ...
    'schema', "mdt.tune-input-contract.v0.1", ...
    'tuneSpecSha256', tuneSpecSha256, 'planSha256', planSha256));
writeJson(fullfile(runDir, 'test_evidence.json'), struct( ...
    'schema', "mdt.test-evidence-ref.v0.1", ...
    'path', "evidence/tune01_preflight_junit.xml", ...
    'sha256', testEvidenceSha256));
writeJson(fullfile(runDir, 'failure.json'), struct( ...
    'schema', "mdt.run-failure.v0.1", ...
    'identifier', string(ME.identifier), 'message', string(ME.message), ...
    'report', string(getReport(ME, 'extended', 'hyperlinks', 'off'))));
writeText(fullfile(runDir, 'stdout.log'), ...
    "TUNE-01 run failed; see failure.json and stderr.log.");
writeText(fullfile(runDir, 'stderr.log'), ...
    string(getReport(ME, 'extended', 'hyperlinks', 'off')));
end

function value = sha256File(path)
fileId = fopen(path, 'r');
if fileId < 0
    error('mdt:HashReadFailure', 'Unable to hash file: %s', path);
end
cleanup = onCleanup(@() fclose(fileId));
data = fread(fileId, Inf, '*uint8');
digest = javaMethod('getInstance', 'java.security.MessageDigest', 'SHA-256');
if ~isempty(data)
    digest.update(typecast(data, 'int8'));
end
bytes = typecast(digest.digest(), 'uint8');
value = string(upper(reshape(dec2hex(bytes, 2).', 1, [])));
end

function value = utcNow()
value = string(datetime('now', 'TimeZone', 'local', ...
    'Format', "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"));
end

function writeJson(path, value)
writeText(path, string(jsonencode(value, PrettyPrint=true)));
end

function writeText(path, value)
fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('mdt:ArtifactWriteFailure', 'Unable to write artifact: %s', path);
end
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, char(value), 'char');
end
