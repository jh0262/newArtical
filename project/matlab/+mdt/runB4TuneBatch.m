function summary = runB4TuneBatch(outputDir)
%RUNB4TUNEBATCH Execute the frozen eight-config B4 development grid.

arguments
    outputDir (1,1) string
end
if strlength(outputDir) == 0
    error('mdt:InvalidOutputDirectory', 'outputDir must be nonempty.');
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite a B4 tuning batch: %s', outputDir);
end

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
specPath = fullfile(projectRoot, '.light', 'h5', 'B4_TUNE_SPEC.md');
authorizationPath = fullfile(projectRoot, '.light', 'h5', ...
    'b4_tune_authorization.json');
e3ReportPath = fullfile(projectRoot, 'evidence', 'E3_DIAGNOSTIC_REPORT.md');
testEvidencePath = fullfile(projectRoot, 'evidence', ...
    'b4_tune_preflight_junit.xml');
for path = [specPath, authorizationPath, e3ReportPath, testEvidencePath]
    if ~isfile(path)
        error('mdt:B4TuneInputMissing', ...
            'Required B4 tuning input is missing: %s', path);
    end
end
authorization = jsondecode(fileread(authorizationPath));
if string(authorization.status) ~= "AUTHORIZED"
    error('mdt:B4TuneNotAuthorized', 'B4 tuning authorization is not active.');
end

specSha256 = sha256File(specPath);
e3ReportSha256 = sha256File(e3ReportPath);
authorizationSha256 = sha256File(authorizationPath);
testEvidenceSha256 = sha256File(testEvidencePath);
sourceFiles = collectSources(projectRoot, [
    ".light/h5/B4_TUNE_SPEC.md"
    ".light/h5/b4_tune_authorization.json"
    "evidence/E3_DIAGNOSTIC_REPORT.md"]);
grid = mdt.makeB4TuneGrid();
seeds = 2026090301:2026090305;
cfg = mdt.makeInstance("D", 7, 3, 0.025, 1);
N = 196;
budget = 19600;
archiveCapacity = 196;

mkdir(outputDir);
mkdir(fullfile(outputDir, 'runs'));
mkdir(fullfile(outputDir, 'failures'));
startedAt = utcNow();
timer = tic;
batchConfig = struct('schema', "mdt.b4-tune-config.v0.1", ...
    'matrixRow', "B4-TUNE", 'instanceId', "D-7-3-X", ...
    'instance', cfg, 'populationSize', N, 'evaluationBudget', budget, ...
    'archiveCapacity', archiveCapacity, 'seeds', seeds, 'grid', grid, ...
    'baseOperator', struct('F', 0.30, 'CR', 0.50, 'FCategory', 0.75), ...
    'scope', "DEVELOPMENT_TUNING_ONLY");
writeJson(fullfile(outputDir, 'batch_config.json'), batchConfig);
writeJson(fullfile(outputDir, 'source_manifest.json'), struct( ...
    'schema', "mdt.source-manifest.v0.1", 'files', sourceFiles));

rows = table('Size', [40, 16], 'VariableTypes', ...
    {'string','double','double','double','double','double','double', ...
    'double','double','double','double','double','double','string', ...
    'string','string'}, 'VariableNames', {'configId','seed', ...
    'noveltyFractionMin','noveltyFractionMax','stagnationHorizon', ...
    'pcrAuc','finalPcr','finalHv','duplicateRate', ...
    'noFeasibleCheckpointRate','runtimeSeconds','seenFeasibleStates', ...
    'evaluatedDiscreteCoverage','runDir','status','failureId'});
row = 0;
failures = strings(0, 1);
for config = grid
    op = struct('F', 0.30, 'CR', 0.50, 'FCategory', 0.75, ...
        'noveltyFractionMin', config.noveltyFractionMin, ...
        'noveltyFractionMax', config.noveltyFractionMax, ...
        'stagnationHorizon', config.stagnationHorizon);
    for seed = seeds
        row = row+1;
        relativeRunDir = fullfile('runs', config.configId, ...
            "seed-" + seed, 'attempt-1');
        rows.configId(row) = config.configId;
        rows.seed(row) = seed;
        rows.noveltyFractionMin(row) = config.noveltyFractionMin;
        rows.noveltyFractionMax(row) = config.noveltyFractionMax;
        rows.stagnationHorizon(row) = config.stagnationHorizon;
        rows.runDir(row) = replace(relativeRunDir, "\", "/");
        try
            result = mdt.runOptimizer("B4", cfg, op, seed, N, ...
                budget, archiveCapacity);
            provenance = struct('matrixRow', "B4-TUNE", ...
                'configId', config.configId, ...
                'tuneSpecSha256', specSha256, ...
                'planSha256', e3ReportSha256, 'sourceFiles', sourceFiles, ...
                'testEvidencePath', "evidence/b4_tune_preflight_junit.xml", ...
                'testEvidenceSha256', testEvidenceSha256, ...
                'comparisonRole', "development_tuning", 'attempt', 1, ...
                'seedRole', "randomness_estimation", ...
                'command', ["matlab", "-batch", "mdt.runB4TuneBatch"], ...
                'scope', "DEVELOPMENT_TUNING_ONLY");
            mdt.writeOptimizerRunBundle(fullfile(outputDir, relativeRunDir), ...
                result, cfg, provenance);
            rows.pcrAuc(row) = result.metrics.pcrAuc;
            rows.finalPcr(row) = result.metrics.finalPcr;
            rows.finalHv(row) = result.metrics.finalHv;
            rows.duplicateRate(row) = result.metrics.meanDuplicateRate;
            rows.noFeasibleCheckpointRate(row) = ...
                result.metrics.noFeasibleCheckpointRate;
            rows.runtimeSeconds(row) = result.metrics.runtimeSeconds;
            rows.seenFeasibleStates(row) = ...
                result.audit.seenFeasibleDiscreteStatesFinal;
            rows.evaluatedDiscreteCoverage(row) = ...
                result.audit.evaluatedDiscreteStateCoverageFinal;
            rows.status(row) = "completed";
        catch ME
            rows{row, 6:13} = NaN;
            rows.status(row) = "failed";
            rows.failureId(row) = string(ME.identifier);
            failures(end+1, 1) = config.configId + "__seed-" + seed + ...
                ":" + string(ME.identifier); %#ok<AGROW>
            failureDir = fullfile(outputDir, 'failures', config.configId, ...
                "seed-" + seed);
            mkdir(failureDir);
            writeJson(fullfile(failureDir, 'failure.json'), struct( ...
                'identifier', string(ME.identifier), ...
                'message', string(ME.message), ...
                'report', string(getReport(ME, 'extended', ...
                'hyperlinks', 'off'))));
        end
    end
end

writetable(rows, fullfile(outputDir, 'b4_tune_results.csv'));
completed = rows.status == "completed";
failed = rows.status == "failed";
status = "COMPLETE";
if any(failed)
    status = "INCOMPLETE";
end
manifest = makeManifest(status, startedAt, toc(timer), sum(completed), ...
    sum(failed), failures, outputDir);
manifest.specSha256 = specSha256;
manifest.e3ReportSha256 = e3ReportSha256;
manifest.authorizationSha256 = authorizationSha256;
manifest.testEvidenceSha256 = testEvidenceSha256;
manifest.sourceManifestSha256 = sha256File(fullfile(outputDir, ...
    'source_manifest.json'));
if any(failed)
    writeJson(fullfile(outputDir, 'batch_manifest.json'), manifest);
    error('mdt:B4TuneCoverageIncomplete', ...
        'B4 tuning has %d failed runs.', sum(failed));
end

selectionRows = rows(:, {'configId','seed','pcrAuc','finalPcr', ...
    'finalHv','duplicateRate'});
winner = mdt.selectTuneWinner(selectionRows);
winnerConfig = grid(string({grid.configId}) == winner.configId);
winner.operator = struct('F', 0.30, 'CR', 0.50, 'FCategory', 0.75, ...
    'noveltyFractionMin', winnerConfig.noveltyFractionMin, ...
    'noveltyFractionMax', winnerConfig.noveltyFractionMax, ...
    'stagnationHorizon', winnerConfig.stagnationHorizon);
winner.scope = "DEVELOPMENT_TUNING_NOT_COMPARATIVE_EVIDENCE";
writeJson(fullfile(outputDir, 'winner_b4.json'), winner);
manifest.winnerB4 = winner.configId;
manifest.winnerSha256 = sha256File(fullfile(outputDir, 'winner_b4.json'));
writeJson(fullfile(outputDir, 'batch_manifest.json'), manifest);

summary = struct('schema', "mdt.b4-tune-summary.v0.1", ...
    'outputDir', outputDir, 'completedRuns', 40, 'failedRuns', 0, ...
    'winnerB4', winner, 'walltimeSeconds', manifest.walltimeSeconds, ...
    'storageBytes', manifest.storageBytes);
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
    failed, failures, outputDir)
entries = dir(fullfile(outputDir, '**', '*'));
manifest = struct('schema', "mdt.b4-tune-manifest.v0.1", ...
    'status', status, 'startedAt', startedAt, 'endedAt', utcNow(), ...
    'scope', "DEVELOPMENT_TUNING_ONLY", 'expectedRuns', 40, ...
    'completedRuns', completed, 'failedRuns', failed, ...
    'failures', failures, 'walltimeSeconds', walltime, ...
    'storageBytes', sum([entries(~[entries.isdir]).bytes]), ...
    'comparativeClaimAuthorized', false);
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
    error('mdt:ArtifactWriteFailure', 'Unable to write artifact: %s', path);
end
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, char(string(jsonencode(value, PrettyPrint=true))), 'char');
end
