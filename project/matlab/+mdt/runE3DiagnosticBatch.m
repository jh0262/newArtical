function summary = runE3DiagnosticBatch(outputDir)
%RUNE3DIAGNOSTICBATCH Execute the frozen post-P1 B2/B3 mechanism study.

arguments
    outputDir (1,1) string
end
if strlength(outputDir) == 0
    error('mdt:InvalidOutputDirectory', 'outputDir must be nonempty.');
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite an E3 diagnostic batch: %s', outputDir);
end

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
specPath = fullfile(projectRoot, '.light', 'e3', 'E3_DIAGNOSTIC_SPEC.md');
authorizationPath = fullfile(projectRoot, '.light', 'e3', ...
    'e3_authorization.json');
p1AnalysisPath = fullfile(projectRoot, 'evidence', 'P1_PILOT_ANALYSIS.md');
testEvidencePath = fullfile(projectRoot, 'evidence', ...
    'e3_preflight_junit.xml');
for path = [specPath, authorizationPath, p1AnalysisPath, testEvidencePath]
    if ~isfile(path)
        error('mdt:E3InputMissing', 'Required E3 input is missing: %s', path);
    end
end
authorization = jsondecode(fileread(authorizationPath));
if string(authorization.status) ~= "AUTHORIZED"
    error('mdt:E3NotAuthorized', 'E3 diagnostic authorization is not active.');
end

design = mdt.makeE3Design();
specSha256 = sha256File(specPath);
p1AnalysisSha256 = sha256File(p1AnalysisPath);
authorizationSha256 = sha256File(authorizationPath);
testEvidenceSha256 = sha256File(testEvidencePath);
sourceFiles = collectSources(projectRoot, ...
    [".light/e3/E3_DIAGNOSTIC_SPEC.md"; ...
    ".light/e3/e3_authorization.json"; ...
    "evidence/P1_PILOT_ANALYSIS.md"; ...
    "evidence/p1_pilot_statistics.json"]);

mkdir(outputDir);
mkdir(fullfile(outputDir, 'runs'));
mkdir(fullfile(outputDir, 'pairs'));
mkdir(fullfile(outputDir, 'failures'));
startedAt = utcNow();
timer = tic;
writeJson(fullfile(outputDir, 'batch_config.json'), design);
writeJson(fullfile(outputDir, 'source_manifest.json'), struct( ...
    'schema', "mdt.source-manifest.v0.1", 'files', sourceFiles));
writeJson(fullfile(outputDir, 'batch_manifest.json'), batchManifest( ...
    "RUNNING", startedAt, 0, 0, 0, strings(0,1), outputDir));

rows = resultTable(design.expectedAlgorithmRuns);
row = 0;
failures = strings(0, 1);
for item = design.instances
    cfg = mdt.makeInstance(item.family, item.q, item.L, item.rho, item.lambda);
    for seed = design.seeds
        pairId = item.instanceId + "__seed-" + seed;
        pairTimer = tic;
        try
            b2 = mdt.runOptimizer("B2", cfg, design.operator, seed, ...
                item.N, item.budget, item.archiveCapacity);
            b3 = mdt.runOptimizer("B3", cfg, design.operator, seed, ...
                item.N, item.budget, item.archiveCapacity);
            pairAudit = mdt.validateE3Pair(b2, b3, item.instanceId);
            pairAudit.walltimeSeconds = toc(pairTimer);
            pairAudit.b2PcrAuc = b2.metrics.pcrAuc;
            pairAudit.b3PcrAuc = b3.metrics.pcrAuc;
            pairAudit.deltaPcrAuc = b3.metrics.pcrAuc-b2.metrics.pcrAuc;
            pairAudit.deltaFinalPcr = b3.metrics.finalPcr-b2.metrics.finalPcr;
            pairAudit.deltaFinalHv = b3.metrics.finalHv-b2.metrics.finalHv;
            pairAudit.deltaMeanComponentIgdPlus = ...
                b3.metrics.finalMeanComponentIgdPlus - ...
                b2.metrics.finalMeanComponentIgdPlus;
            writeJson(fullfile(outputDir, 'pairs', pairId + ".json"), pairAudit);

            results = {b2, b3};
            for algorithmIndex = 1:2
                algorithm = design.algorithms(algorithmIndex);
                result = results{algorithmIndex};
                configId = design.configIds.(char(algorithm));
                relativeRunDir = fullfile('runs', lower(algorithm), ...
                    item.instanceId, "seed-" + seed, 'attempt-1');
                provenance = makeProvenance(configId, specSha256, ...
                    p1AnalysisSha256, sourceFiles, testEvidenceSha256, ...
                    pairId, pairAudit, algorithm);
                mdt.writeOptimizerRunBundle(fullfile(outputDir, relativeRunDir), ...
                    result, cfg, provenance);
                row = row+1;
                rows(row, :) = resultRow(item.instanceId, algorithm, ...
                    configId, seed, result, pairId, relativeRunDir, "completed");
            end
        catch ME
            failures(end+1, 1) = pairId + ":" + string(ME.identifier); %#ok<AGROW>
            writeFailure(fullfile(outputDir, 'failures', pairId), ...
                item, seed, ME, specSha256, sourceFiles);
            for algorithm = design.algorithms
                row = row+1;
                rows(row, :) = failedRow(item.instanceId, algorithm, ...
                    design.configIds.(char(algorithm)), seed, pairId);
            end
        end
    end
end

writetable(rows, fullfile(outputDir, 'e3_results.csv'));
failed = rows.status == "failed";
completed = rows.status == "completed";
status = "COMPLETE";
if any(failed)
    status = "INCOMPLETE";
end
manifest = batchManifest(status, startedAt, toc(timer), sum(completed), ...
    sum(failed), failures, outputDir);
manifest.specSha256 = specSha256;
manifest.p1AnalysisSha256 = p1AnalysisSha256;
manifest.authorizationSha256 = authorizationSha256;
manifest.testEvidenceSha256 = testEvidenceSha256;
manifest.sourceManifestSha256 = sha256File(fullfile(outputDir, ...
    'source_manifest.json'));
writeJson(fullfile(outputDir, 'batch_manifest.json'), manifest);
if any(failed)
    error('mdt:E3CoverageIncomplete', ...
        'E3 has %d failed runs; diagnostic coverage is incomplete.', sum(failed));
end

summary = struct('schema', "mdt.e3-batch-summary.v0.1", ...
    'outputDir', outputDir, 'completedRuns', sum(completed), ...
    'failedRuns', 0, 'completedPairs', design.expectedPairs, ...
    'walltimeSeconds', manifest.walltimeSeconds, ...
    'storageBytes', manifest.storageBytes, 'scope', design.scope);
end

function rows = resultTable(count)
rows = table('Size', [count, 18], 'VariableTypes', ...
    {'string','string','string','double','double','double','double', ...
    'double','double','double','double','double','double','double', ...
    'double','string','string','string'}, ...
    'VariableNames', {'instanceId','algorithm','configId','seed','pcrAuc', ...
    'finalPcr','finalHv','finalIgdPlus','finalMeanComponentIgdPlus', ...
    'duplicateRate','noFeasibleCheckpointRate','runtimeSeconds', ...
    'evaluationBudget','protectedCountFinal','truthUsedBySelection', ...
    'pairId','runDir','status'});
end

function row = resultRow(instanceId, algorithm, configId, seed, result, ...
    pairId, relativeRunDir, status)
protected = 0;
if ~isempty(result.audit.protectedCountTimeline)
    protected = result.audit.protectedCountTimeline(end);
end
row = cell2table({instanceId, algorithm, configId, seed, ...
    result.metrics.pcrAuc, result.metrics.finalPcr, result.metrics.finalHv, ...
    result.metrics.finalIgdPlus, result.metrics.finalMeanComponentIgdPlus, ...
    result.metrics.meanDuplicateRate, ...
    result.metrics.noFeasibleCheckpointRate, result.metrics.runtimeSeconds, ...
    result.metrics.evaluations, protected, ...
    double(result.audit.truthUsedBySelection), pairId, ...
    replace(relativeRunDir, "\", "/"), status}, ...
    'VariableNames', resultTable(1).Properties.VariableNames);
end

function row = failedRow(instanceId, algorithm, configId, seed, pairId)
row = cell2table({instanceId, algorithm, configId, seed, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, pairId, "", "failed"}, ...
    'VariableNames', resultTable(1).Properties.VariableNames);
end

function provenance = makeProvenance(configId, specSha256, p1AnalysisSha256, ...
    sourceFiles, testEvidenceSha256, pairId, pairAudit, algorithm)
provenance = struct('matrixRow', "E3-DIAG", 'configId', configId, ...
    'tuneSpecSha256', specSha256, 'planSha256', p1AnalysisSha256, ...
    'sourceFiles', sourceFiles, ...
    'testEvidencePath', "evidence/e3_preflight_junit.xml", ...
    'testEvidenceSha256', testEvidenceSha256, ...
    'comparisonRole', "diagnostic_" + lower(algorithm), ...
    'attempt', 1, 'seedRole', "randomness_estimation", ...
    'command', ["matlab", "-batch", "mdt.runE3DiagnosticBatch"], ...
    'pairId', pairId, 'pairAudit', pairAudit, ...
    'scope', "POST_P1_DIAGNOSTIC_NO_DEPLOYABLE_CLAIM");
end

function files = collectSources(projectRoot, fixedFiles)
matlabFiles = dir(fullfile(projectRoot, 'matlab', '+mdt', '**', '*.m'));
testFiles = dir(fullfile(projectRoot, 'tests', '*.m'));
relative = fixedFiles(:);
for item = [matlabFiles; testFiles]'
    absolute = string(fullfile(item.folder, item.name));
    relative(end+1, 1) = replace(extractAfter(absolute, ...
        strlength(projectRoot)+1), "\", "/"); %#ok<AGROW>
end
relative = sort(unique(relative));
files = repmat(struct('path', "", 'sha256', ""), numel(relative), 1);
for i = 1:numel(relative)
    absolute = fullfile(projectRoot, relative(i));
    if ~isfile(absolute)
        error('mdt:E3SourceMissing', 'E3 source is missing: %s', relative(i));
    end
    files(i).path = relative(i);
    files(i).sha256 = sha256File(absolute);
end
end

function writeFailure(path, item, seed, ME, specSha256, sourceFiles)
mkdir(path);
writeJson(fullfile(path, 'failure.json'), struct( ...
    'schema', "mdt.e3-pair-failure.v0.1", 'instance', item, ...
    'seed', seed, 'identifier', string(ME.identifier), ...
    'message', string(ME.message), ...
    'report', string(getReport(ME, 'extended', 'hyperlinks', 'off')), ...
    'specSha256', specSha256));
writeJson(fullfile(path, 'source_manifest.json'), struct( ...
    'schema', "mdt.source-manifest.v0.1", 'files', sourceFiles));
end

function manifest = batchManifest(status, startedAt, walltime, completed, ...
    failed, failures, outputDir)
entries = dir(fullfile(outputDir, '**', '*'));
manifest = struct('schema', "mdt.e3-batch-manifest.v0.1", ...
    'status', status, 'startedAt', startedAt, 'endedAt', utcNow(), ...
    'scope', "POST_P1_DIAGNOSTIC_NO_DEPLOYABLE_CLAIM", ...
    'expectedAlgorithmRuns', 40, 'completedAlgorithmRuns', completed, ...
    'failedAlgorithmRuns', failed, 'failures', failures, ...
    'walltimeSeconds', walltime, ...
    'storageBytes', sum([entries(~[entries.isdir]).bytes]), ...
    'deployableClaimAuthorized', false);
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
