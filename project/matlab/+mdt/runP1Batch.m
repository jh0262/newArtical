function summary = runP1Batch(outputDir)
%RUNP1BATCH Execute the authorized frozen EXP-P1 paired pilot once.

arguments
    outputDir (1,1) string
end
if strlength(outputDir) == 0
    error('mdt:InvalidOutputDirectory', 'outputDir must be nonempty.');
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite an EXP-P1 batch: %s', outputDir);
end

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
contractPath = fullfile(projectRoot, '.light', 'e2', ...
    'experiment_execution_contract.json');
planPath = fullfile(projectRoot, '.light', 'e2', 'PROJECT_PLAN.md');
seedPath = fullfile(projectRoot, '.light', 'e2', 'p1_seed_matrix.json');
frozenTunePath = fullfile(projectRoot, '.light', 'e2', ...
    'frozen_tune_config.json');
authorizationPath = fullfile(projectRoot, '.light', 'e2', ...
    'p1_authorization.json');
testEvidencePath = fullfile(projectRoot, 'evidence', ...
    'p1_preflight_junit.xml');
requiredPaths = [contractPath, planPath, seedPath, frozenTunePath, ...
    authorizationPath, testEvidencePath];
for path = requiredPaths
    if ~isfile(path)
        error('mdt:P1InputMissing', 'Required P1 input is missing: %s', path);
    end
end

contract = jsondecode(fileread(contractPath));
authorization = jsondecode(fileread(authorizationPath));
if string(contract.decision) ~= "READY" || ...
        string(authorization.status) ~= "AUTHORIZED"
    error('mdt:P1NotAuthorized', ...
        'EXP-P1 requires a READY contract and AUTHORIZED record.');
end

design = mdt.makeP1Design();
contractSha256 = sha256File(contractPath);
planSha256 = sha256File(planPath);
seedSha256 = sha256File(seedPath);
frozenTuneSha256 = sha256File(frozenTunePath);
authorizationSha256 = sha256File(authorizationPath);
testEvidenceSha256 = sha256File(testEvidencePath);
sourceFiles = mdt.collectP1SourceHashes(projectRoot);

mkdir(outputDir);
mkdir(fullfile(outputDir, 'runs'));
mkdir(fullfile(outputDir, 'pairs'));
mkdir(fullfile(outputDir, 'failures'));
batchStartedAt = utcNow();
batchTimer = tic;

batchConfig = design;
batchConfig.contractSha256 = contractSha256;
batchConfig.planSha256 = planSha256;
batchConfig.seedMatrixSha256 = seedSha256;
batchConfig.frozenTuneConfigSha256 = frozenTuneSha256;
batchConfig.authorizationSha256 = authorizationSha256;
writeJson(fullfile(outputDir, 'batch_config.json'), batchConfig);
writeJson(fullfile(outputDir, 'source_manifest.json'), struct( ...
    'schema', "mdt.source-manifest.v0.1", 'files', sourceFiles));
writeJson(fullfile(outputDir, 'batch_manifest.json'), makeBatchManifest( ...
    "RUNNING", batchStartedAt, 0, 0, 0, strings(0, 1), outputDir));

rows = makeResultTable(design.expectedAlgorithmRuns);
row = 0;
failures = strings(0, 1);
for instanceIndex = 1:numel(design.instances)
    item = design.instances(instanceIndex);
    cfg = mdt.makeInstance(item.family, item.q, item.L, item.rho, item.lambda);
    for seed = design.seeds
        pairId = item.instanceId + "__seed-" + seed;
        pairTimer = tic;
        try
            b0op = operatorFromDesign(design.B0);
            b1op = operatorFromDesign(design.B1);
            b0 = mdt.runOptimizer("B0", cfg, b0op, seed, item.N, ...
                item.budget, item.archiveCapacity);
            b1 = mdt.runOptimizer("B1", cfg, b1op, seed, item.N, ...
                item.budget, item.archiveCapacity);
            pairAudit = mdt.validateP1Pair(b0, b1, item.instanceId);
            pairAudit.walltimeSeconds = toc(pairTimer);
            pairAudit.b0PcrAuc = b0.metrics.pcrAuc;
            pairAudit.b1PcrAuc = b1.metrics.pcrAuc;
            pairAudit.deltaPcrAuc = b1.metrics.pcrAuc - b0.metrics.pcrAuc;
            writeJson(fullfile(outputDir, 'pairs', pairId + ".json"), pairAudit);

            results = {b0, b1};
            for algorithmIndex = 1:2
                algorithm = design.algorithms(algorithmIndex);
                frozenConfig = design.(char(algorithm));
                result = results{algorithmIndex};
                relativeRunDir = fullfile('runs', lower(algorithm), ...
                    item.instanceId, "seed-" + seed, 'attempt-1');
                runDir = fullfile(outputDir, relativeRunDir);
                provenance = makeProvenance(frozenConfig.configId, ...
                    contractSha256, planSha256, sourceFiles, ...
                    testEvidenceSha256, pairId, pairAudit, algorithm);
                mdt.writeOptimizerRunBundle(runDir, result, cfg, provenance);
                row = row + 1;
                rows(row, :) = makeResultRow(item.instanceId, algorithm, ...
                    frozenConfig, seed, result, pairId, relativeRunDir, ...
                    "completed");
            end
        catch ME
            failures(end+1, 1) = pairId + ":" + string(ME.identifier); %#ok<AGROW>
            writePairFailure(fullfile(outputDir, 'failures', pairId), ...
                item, seed, ME, contractSha256, sourceFiles);
            for algorithm = design.algorithms
                frozenConfig = design.(char(algorithm));
                row = row + 1;
                rows(row, :) = makeFailedRow(item.instanceId, algorithm, ...
                    frozenConfig, seed, pairId);
            end
        end
    end
end

writetable(rows, fullfile(outputDir, 'p1_results.csv'));
completed = rows.status == "completed";
failed = rows.status == "failed";
if any(failed)
    manifest = makeBatchManifest("INCOMPLETE", batchStartedAt, ...
        toc(batchTimer), sum(completed), sum(failed), failures, outputDir);
    addFrozenHashesAndWrite(manifest, outputDir, contractSha256, ...
        planSha256, seedSha256, frozenTuneSha256, authorizationSha256, ...
        testEvidenceSha256);
    error('mdt:P1CoverageIncomplete', ...
        'EXP-P1 has %d failed algorithm runs; paired coverage is incomplete.', ...
        sum(failed));
end

manifest = makeBatchManifest("COMPLETE", batchStartedAt, toc(batchTimer), ...
    sum(completed), 0, failures, outputDir);
addFrozenHashesAndWrite(manifest, outputDir, contractSha256, planSha256, ...
    seedSha256, frozenTuneSha256, authorizationSha256, testEvidenceSha256);

summary = struct();
summary.schema = "mdt.p1-batch-summary.v0.1";
summary.outputDir = outputDir;
summary.completedRuns = sum(completed);
summary.failedRuns = 0;
summary.completedPairs = design.expectedPairs;
summary.walltimeSeconds = manifest.walltimeSeconds;
summary.storageBytes = manifest.storageBytes;
summary.scope = design.scope;
end

function rows = makeResultTable(count)
rows = table('Size', [count, 19], 'VariableTypes', ...
    {'string','string','string','double','double','double','double', ...
    'double','double','double','double','double','double','double', ...
    'double','double','string','string','string'}, ...
    'VariableNames', {'instanceId','algorithm','configId','seed','F','CR', ...
    'FCategory','pcrAuc','finalPcr','finalHv','finalIgdPlus', ...
    'finalMeanComponentIgdPlus','duplicateRate', ...
    'noFeasibleCheckpointRate','runtimeSeconds','evaluationBudget', ...
    'pairId','runDir','status'});
end

function row = makeResultRow(instanceId, algorithm, frozenConfig, seed, ...
    result, pairId, relativeRunDir, status)
row = cell2table({instanceId, algorithm, frozenConfig.configId, seed, ...
    frozenConfig.F, frozenConfig.CR, frozenConfig.FCategory, ...
    result.metrics.pcrAuc, result.metrics.finalPcr, result.metrics.finalHv, ...
    result.metrics.finalIgdPlus, result.metrics.finalMeanComponentIgdPlus, ...
    result.metrics.meanDuplicateRate, ...
    result.metrics.noFeasibleCheckpointRate, result.metrics.runtimeSeconds, ...
    result.metrics.evaluations, pairId, replace(relativeRunDir, "\", "/"), ...
    status}, 'VariableNames', makeResultTable(1).Properties.VariableNames);
end

function row = makeFailedRow(instanceId, algorithm, frozenConfig, seed, pairId)
row = cell2table({instanceId, algorithm, frozenConfig.configId, seed, ...
    frozenConfig.F, frozenConfig.CR, frozenConfig.FCategory, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, pairId, "", "failed"}, ...
    'VariableNames', makeResultTable(1).Properties.VariableNames);
end

function op = operatorFromDesign(config)
op = struct('F', config.F, 'CR', config.CR, ...
    'FCategory', config.FCategory);
end

function provenance = makeProvenance(configId, contractSha256, planSha256, ...
    sourceFiles, testEvidenceSha256, pairId, pairAudit, algorithm)
provenance = struct();
provenance.matrixRow = "EXP-P1";
provenance.configId = configId;
provenance.tuneSpecSha256 = contractSha256;
provenance.planSha256 = planSha256;
provenance.sourceFiles = sourceFiles;
provenance.testEvidencePath = "evidence/p1_preflight_junit.xml";
provenance.testEvidenceSha256 = testEvidenceSha256;
provenance.comparisonRole = "pilot_" + lower(algorithm);
provenance.attempt = 1;
provenance.seedRole = "randomness_estimation";
provenance.command = ["matlab", "-batch", "mdt.runP1Batch"];
provenance.pairId = pairId;
provenance.pairAudit = pairAudit;
provenance.scope = "PILOT_ONLY_NO_H2_DECISION";
end

function writePairFailure(path, item, seed, ME, contractSha256, sourceFiles)
if isfolder(path) || isfile(path)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite failed pair evidence: %s', path);
end
mkdir(path);
writeJson(fullfile(path, 'failure.json'), struct( ...
    'schema', "mdt.p1-pair-failure.v0.1", 'instance', item, ...
    'seed', seed, 'identifier', string(ME.identifier), ...
    'message', string(ME.message), ...
    'report', string(getReport(ME, 'extended', 'hyperlinks', 'off')), ...
    'contractSha256', contractSha256));
writeJson(fullfile(path, 'source_manifest.json'), struct( ...
    'schema', "mdt.source-manifest.v0.1", 'files', sourceFiles));
end

function manifest = makeBatchManifest(status, startedAt, walltimeSeconds, ...
    completed, failed, failures, outputDir)
manifest = struct();
manifest.schema = "mdt.p1-batch-manifest.v0.1";
manifest.status = status;
manifest.startedAt = startedAt;
manifest.endedAt = utcNow();
manifest.scope = "PILOT_ONLY_NO_H2_DECISION";
manifest.expectedAlgorithmRuns = 100;
manifest.completedAlgorithmRuns = completed;
manifest.failedAlgorithmRuns = failed;
manifest.failures = failures;
manifest.walltimeSeconds = walltimeSeconds;
entries = dir(fullfile(outputDir, '**', '*'));
manifest.storageBytes = sum([entries(~[entries.isdir]).bytes]);
manifest.h2DecisionAuthorized = false;
end

function addFrozenHashesAndWrite(manifest, outputDir, contractSha256, ...
    planSha256, seedSha256, frozenTuneSha256, authorizationSha256, ...
    testEvidenceSha256)
manifest.contractSha256 = contractSha256;
manifest.planSha256 = planSha256;
manifest.seedMatrixSha256 = seedSha256;
manifest.frozenTuneConfigSha256 = frozenTuneSha256;
manifest.authorizationSha256 = authorizationSha256;
manifest.testEvidenceSha256 = testEvidenceSha256;
manifest.sourceManifestSha256 = sha256File(fullfile(outputDir, ...
    'source_manifest.json'));
writeJson(fullfile(outputDir, 'batch_manifest.json'), manifest);
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
value = string(lower(reshape(dec2hex(bytes, 2).', 1, [])));
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
