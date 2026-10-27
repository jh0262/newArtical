function summary = runH6Batch(outputDir)
%RUNH6BATCH Execute the frozen 300-run H6 evidence-extension matrix.

arguments
    outputDir (1,1) string
end
if strlength(outputDir) == 0
    error('mdt:InvalidOutputDirectory', 'outputDir must be nonempty.');
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite an H6 batch: %s', outputDir);
end

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
specPath = fullfile(projectRoot, '.light', 'h6', ...
    'H6_GENERALIZATION_SPEC.md');
authorizationPath = fullfile(projectRoot, '.light', 'h6', ...
    'h6_authorization.json');
referencePath = fullfile(projectRoot, 'evidence', 'H6_REFERENCE_BASIS.md');
testEvidencePath = fullfile(projectRoot, 'evidence', ...
    'h6_preflight_junit.xml');
for path = [specPath, authorizationPath, referencePath, testEvidencePath]
    if ~isfile(path)
        error('mdt:H6InputMissing', 'Required H6 input is missing: %s', path);
    end
end
authorization = jsondecode(fileread(authorizationPath));
if string(authorization.status) ~= "AUTHORIZED"
    error('mdt:H6NotAuthorized', 'H6 authorization is not active.');
end

design = mdt.makeH6Design();
specSha256 = sha256File(specPath);
authorizationSha256 = sha256File(authorizationPath);
referenceSha256 = sha256File(referencePath);
testEvidenceSha256 = sha256File(testEvidencePath);
sourceFiles = collectSources(projectRoot, [
    ".light/h6/H6_GENERALIZATION_SPEC.md"
    ".light/h6/h6_authorization.json"
    "evidence/H6_REFERENCE_BASIS.md"]);

mkdir(outputDir);
mkdir(fullfile(outputDir, 'runs'));
mkdir(fullfile(outputDir, 'sets'));
mkdir(fullfile(outputDir, 'failures'));
startedAt = utcNow();
timer = tic;
writeJson(fullfile(outputDir, 'batch_config.json'), design);
writeJson(fullfile(outputDir, 'source_manifest.json'), struct( ...
    'schema', "mdt.source-manifest.v0.1", 'files', sourceFiles));
writeJson(fullfile(outputDir, 'batch_manifest.json'), makeManifest( ...
    "RUNNING", startedAt, 0, 0, 0, strings(0,1), outputDir, design));

rows = makeResultTable(design.expectedAlgorithmRuns);
row = 0;
failures = strings(0, 1);
for item = design.instances'
    cfg = mdt.makeInstance(item.family, item.q, item.L, item.rho, item.lambda);
    for seed = design.seeds
        setId = item.instanceId + "__seed-" + seed;
        setTimer = tic;
        try
            runSet = struct();
            for algorithm = design.algorithms
                if algorithm == "N2"
                    op = struct('crossoverProbability', 0.9, ...
                        'mutationProbability', 1/(2+cfg.L), ...
                        'etaC', 20, 'etaM', 20);
                else
                    op = design.operators.(char(algorithm));
                end
                runSet.(char(algorithm)) = mdt.runOptimizer(algorithm, ...
                    cfg, op, seed, item.N, item.budget, item.archiveCapacity);
            end
            setAudit = mdt.validateH6ComparisonSet(runSet, item.instanceId);
            setAudit.walltimeSeconds = toc(setTimer);
            for baseline = ["N2", "B1", "B4F", "B4R"]
                prefix = "B4minus" + baseline;
                setAudit.(char(prefix + "Auc")) = ...
                    runSet.B4.metrics.pcrAuc - ...
                    runSet.(char(baseline)).metrics.pcrAuc;
                setAudit.(char(prefix + "FinalPcr")) = ...
                    runSet.B4.metrics.finalPcr - ...
                    runSet.(char(baseline)).metrics.finalPcr;
                setAudit.(char(prefix + "FinalHv")) = ...
                    runSet.B4.metrics.finalHv - ...
                    runSet.(char(baseline)).metrics.finalHv;
            end
            writeJson(fullfile(outputDir, 'sets', setId + ".json"), setAudit);

            for algorithm = design.algorithms
                result = runSet.(char(algorithm));
                configId = design.configIds.(char(algorithm));
                relativeRunDir = fullfile('runs', lower(algorithm), ...
                    item.instanceId, "seed-" + seed, 'attempt-1');
                provenance = struct('matrixRow', "H6-GEN", ...
                    'configId', configId, 'tuneSpecSha256', specSha256, ...
                    'planSha256', referenceSha256, ...
                    'sourceFiles', sourceFiles, ...
                    'testEvidencePath', "evidence/h6_preflight_junit.xml", ...
                    'testEvidenceSha256', testEvidenceSha256, ...
                    'comparisonRole', "h6_" + lower(algorithm), ...
                    'attempt', 1, 'seedRole', "randomness_estimation", ...
                    'command', ["matlab", "-batch", "mdt.runH6Batch"], ...
                    'pairId', setId, 'pairAudit', setAudit, ...
                    'scope', design.scope);
                mdt.writeOptimizerRunBundle(fullfile(outputDir, relativeRunDir), ...
                    result, cfg, provenance);
                row = row+1;
                rows(row, :) = resultRow(item.instanceId, algorithm, ...
                    configId, seed, result, setId, relativeRunDir, "completed");
            end
        catch ME
            failures(end+1, 1) = setId + ":" + string(ME.identifier); %#ok<AGROW>
            failureDir = fullfile(outputDir, 'failures', setId);
            mkdir(failureDir);
            writeJson(fullfile(failureDir, 'failure.json'), struct( ...
                'schema', "mdt.h6-set-failure.v0.1", 'instance', item, ...
                'seed', seed, 'identifier', string(ME.identifier), ...
                'message', string(ME.message), ...
                'report', string(getReport(ME, 'extended', ...
                'hyperlinks', 'off')), 'specSha256', specSha256));
            for algorithm = design.algorithms
                row = row+1;
                rows(row, :) = failedRow(item.instanceId, algorithm, ...
                    design.configIds.(char(algorithm)), seed, setId);
            end
        end
    end
end

writetable(rows, fullfile(outputDir, 'h6_results.csv'));
completed = rows.status == "completed";
failed = rows.status == "failed";
status = "COMPLETE";
if any(failed)
    status = "INCOMPLETE";
end
manifest = makeManifest(status, startedAt, toc(timer), sum(completed), ...
    sum(failed), failures, outputDir, design);
manifest.specSha256 = specSha256;
manifest.authorizationSha256 = authorizationSha256;
manifest.referenceBasisSha256 = referenceSha256;
manifest.testEvidenceSha256 = testEvidenceSha256;
manifest.sourceManifestSha256 = sha256File(fullfile(outputDir, ...
    'source_manifest.json'));
writeJson(fullfile(outputDir, 'batch_manifest.json'), manifest);
if any(failed)
    error('mdt:H6CoverageIncomplete', ...
        'H6 has %d failed algorithm runs.', sum(failed));
end

summary = struct('schema', "mdt.h6-summary.v0.1", ...
    'outputDir', outputDir, 'completedRuns', sum(completed), ...
    'failedRuns', 0, 'completedSets', design.expectedSets, ...
    'walltimeSeconds', manifest.walltimeSeconds, ...
    'storageBytes', manifest.storageBytes, 'scope', design.scope);
end

function rows = makeResultTable(count)
rows = table('Size', [count, 18], 'VariableTypes', ...
    {'string','string','string','double','double','double','double', ...
    'double','double','double','double','double','double','double', ...
    'string','string','string','double'}, 'VariableNames', ...
    {'instanceId','algorithm','configId','seed','pcrAuc','finalPcr', ...
    'finalHv','finalIgdPlus','finalMeanComponentIgdPlus','duplicateRate', ...
    'noFeasibleCheckpointRate','runtimeSeconds','evaluationBudget', ...
    'evaluatedDiscreteCoverage','setId','runDir','status', ...
    'seenFeasibleStates'});
end

function row = resultRow(instanceId, algorithm, configId, seed, result, ...
    setId, relativeRunDir, status)
row = cell2table({instanceId, algorithm, configId, seed, ...
    result.metrics.pcrAuc, result.metrics.finalPcr, result.metrics.finalHv, ...
    result.metrics.finalIgdPlus, result.metrics.finalMeanComponentIgdPlus, ...
    result.metrics.meanDuplicateRate, ...
    result.metrics.noFeasibleCheckpointRate, result.metrics.runtimeSeconds, ...
    result.metrics.evaluations, ...
    result.audit.evaluatedDiscreteStateCoverageFinal, setId, ...
    replace(relativeRunDir, "\", "/"), status, ...
    result.audit.seenFeasibleDiscreteStatesFinal}, ...
    'VariableNames', makeResultTable(1).Properties.VariableNames);
end

function row = failedRow(instanceId, algorithm, configId, seed, setId)
row = cell2table({instanceId, algorithm, configId, seed, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, setId, "", "failed", NaN}, ...
    'VariableNames', makeResultTable(1).Properties.VariableNames);
end

function files = collectSources(projectRoot, fixedFiles)
source = dir(fullfile(projectRoot, 'matlab', '+mdt', '**', '*.m'));
tests = dir(fullfile(projectRoot, 'tests', '*.m'));
relative = fixedFiles(:);
for item = [source; tests]'
    absolute = string(fullfile(item.folder, item.name));
    relative(end+1,1) = replace(extractAfter(absolute, ...
        strlength(projectRoot)+1), "\", "/"); %#ok<AGROW>
end
relative = sort(unique(relative));
files = repmat(struct('path', "", 'sha256', ""), numel(relative), 1);
for i = 1:numel(relative)
    files(i).path = relative(i);
    files(i).sha256 = sha256File(fullfile(projectRoot, relative(i)));
end
end

function manifest = makeManifest(status, startedAt, walltime, completed, ...
    failed, failures, outputDir, design)
entries = dir(fullfile(outputDir, '**', '*'));
manifest = struct('schema', "mdt.h6-manifest.v0.1", ...
    'status', status, 'startedAt', startedAt, 'endedAt', utcNow(), ...
    'scope', design.scope, ...
    'expectedAlgorithmRuns', design.expectedAlgorithmRuns, ...
    'completedAlgorithmRuns', completed, ...
    'failedAlgorithmRuns', failed, 'failures', failures, ...
    'walltimeSeconds', walltime, ...
    'storageBytes', sum([entries(~[entries.isdir]).bytes]), ...
    'claimRequiresAnalysisGate', true);
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
fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('mdt:ArtifactWriteFailure', ...
        'Unable to write artifact: %s', path);
end
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, char(string(jsonencode(value, PrettyPrint=true))), 'char');
end
