function summary = runH10StagnationDiagnostic(outputDir, design)
%RUNH10STAGNATIONDIAGNOSTIC Execute an immutable B5S stagnation screen.

arguments
    outputDir (1,1) string
    design (1,1) struct = mdt.makeH10StagnationDesign()
end
if strlength(outputDir) == 0
    error('mdt:InvalidOutputDirectory', 'outputDir must be nonempty.');
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite an H10 diagnostic: %s', outputDir);
end
validateDesign(design);

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
specPath = fullfile(projectRoot, '.light', 'h10', ...
    'H10_STAGNATION_DIAGNOSTIC_SPEC.md');
authorizationPath = fullfile(projectRoot, '.light', 'h10', ...
    'h10_authorization.json');
if ~isfile(specPath) || ~isfile(authorizationPath)
    error('mdt:H10InputMissing', ...
        'H10 specification and authorization must exist.');
end
authorization = jsondecode(fileread(authorizationPath));
if string(authorization.status) ~= "AUTHORIZED"
    error('mdt:H10NotAuthorized', 'H10 authorization is not active.');
end
specSha256 = sha256File(specPath);
authorizationSha256 = sha256File(authorizationPath);

mkdir(outputDir);
mkdir(fullfile(outputDir, 'runs'));
mkdir(fullfile(outputDir, 'failures'));
writeJson(fullfile(outputDir, 'batch_config.json'), design);
startedAt = utcNow();
timer = tic;
writeJson(fullfile(outputDir, 'batch_manifest.json'), struct( ...
    'schema', "mdt.h10-batch-manifest.v1.0", 'status', "RUNNING", ...
    'startedAt', startedAt, 'expectedRuns', design.expectedRuns, ...
    'completedRuns', 0, 'failedRuns', 0, ...
    'decision', "PENDING", 'claimScope', design.scope));

rows = makeResultTable(design.expectedRuns);
row = 0;
failures = strings(0, 1);
for item = design.instances'
    cfg = mdt.makeInstance(item.family, item.q, item.L, ...
        item.rho, item.lambda);
    for seed = design.seeds
        row = row+1;
        runRelative = fullfile('runs', item.instanceId, ...
            "seed-"+seed, 'attempt-1');
        runDir = fullfile(outputDir, runRelative);
        try
            result = mdt.runOptimizer(design.algorithm, cfg, ...
                design.operator, seed, item.N, item.budget, ...
                item.archiveCapacity);
            diagnostic = mdt.detectOptimizationStagnation(result, ...
                design.stagnationHorizon, design.pcrTolerance, ...
                design.hvTolerance, design.actionableBudgetFraction);
            writeRunBundle(runDir, result, diagnostic, cfg, item, ...
                design, specSha256, authorizationSha256);
            rows(row, :) = resultRow(item.instanceId, seed, result, ...
                diagnostic, replace(runRelative, "\", "/"), "completed");
        catch ME
            failureId = item.instanceId+"__seed-"+seed;
            failures(end+1, 1) = failureId+":"+string(ME.identifier); %#ok<AGROW>
            failureDir = fullfile(outputDir, 'failures', failureId);
            mkdir(failureDir);
            writeJson(fullfile(failureDir, 'failure.json'), struct( ...
                'schema', "mdt.h10-run-failure.v1.0", ...
                'instanceId', item.instanceId, 'seed', seed, ...
                'identifier', string(ME.identifier), ...
                'message', string(ME.message), ...
                'report', string(getReport(ME, 'extended', ...
                'hyperlinks', 'off')), 'specSha256', specSha256, ...
                'authorizationSha256', authorizationSha256));
            rows(row, :) = failedRow(item.instanceId, seed, failureId);
        end
    end
end

writetable(rows, fullfile(outputDir, 'h10_stagnation_results.csv'));
completed = rows.status == "completed";
failed = rows.status == "failed";
actionable = completed & rows.actionableStagnation;
triggeredInstances = unique(rows.instanceId(actionable));
if any(failed) || sum(completed) ~= design.expectedRuns
    decision = "INCONCLUSIVE";
elseif sum(actionable) >= design.confirmedRunThreshold && ...
        numel(triggeredInstances) >= design.requiredTriggeredInstances
    decision = "CONFIRMED";
else
    decision = "NOT_CONFIRMED";
end

entries = dir(fullfile(outputDir, '**', '*'));
manifest = struct();
manifest.schema = "mdt.h10-batch-manifest.v1.0";
manifest.status = ternary(any(failed), "INCOMPLETE", "COMPLETE");
manifest.startedAt = startedAt;
manifest.endedAt = utcNow();
manifest.expectedRuns = design.expectedRuns;
manifest.completedRuns = sum(completed);
manifest.failedRuns = sum(failed);
manifest.failures = failures;
manifest.actionableStagnationRuns = sum(actionable);
manifest.triggeredInstances = triggeredInstances;
manifest.decision = decision;
manifest.specSha256 = specSha256;
manifest.authorizationSha256 = authorizationSha256;
manifest.walltimeSeconds = toc(timer);
manifest.storageBytes = sum([entries(~[entries.isdir]).bytes]);
manifest.fixedEvaluationBudget = design.fixedEvaluationBudget;
manifest.claimScope = design.scope;
manifest.repairAuthorized = decision == "CONFIRMED";
writeJson(fullfile(outputDir, 'batch_manifest.json'), manifest);

summary = struct('schema', "mdt.h10-stagnation-summary.v1.0", ...
    'outputDir', outputDir, 'completedRuns', sum(completed), ...
    'failedRuns', sum(failed), ...
    'actionableStagnationRuns', sum(actionable), ...
    'triggeredInstances', triggeredInstances, ...
    'decision', decision, 'repairAuthorized', decision == "CONFIRMED", ...
    'walltimeSeconds', manifest.walltimeSeconds, ...
    'storageBytes', manifest.storageBytes, 'scope', design.scope);
if any(failed)
    error('mdt:H10CoverageIncomplete', ...
        'H10 has %d failed runs; decision is INCONCLUSIVE.', sum(failed));
end
end

function validateDesign(design)
required = {'schema','matrixRow','scope','algorithm','instances','seeds', ...
    'operator','stagnationHorizon','pcrTolerance','hvTolerance', ...
    'actionableBudgetFraction','confirmedRunThreshold', ...
    'requiredTriggeredInstances','expectedRuns','fixedEvaluationBudget'};
if ~all(isfield(design, required)) || ...
        string(design.schema) ~= "mdt.h10-stagnation-design.v1.0" || ...
        string(design.algorithm) ~= "B5S" || ...
        design.expectedRuns ~= numel(design.instances)*numel(design.seeds)
    error('mdt:InvalidH10Design', 'H10 design is incomplete or inconsistent.');
end
end

function writeRunBundle(runDir, result, diagnostic, cfg, item, design, ...
    specSha256, authorizationSha256)
if isfolder(runDir) || isfile(runDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite an H10 run: %s', runDir);
end
mkdir(runDir);
config = struct('schema', "mdt.h10-run-config.v1.0", ...
    'matrixRow', design.matrixRow, 'scope', design.scope, ...
    'algorithm', design.algorithm, 'instance', item, ...
    'operator', design.operator, 'seed', result.audit.seed, ...
    'stagnationHorizon', design.stagnationHorizon, ...
    'pcrTolerance', design.pcrTolerance, ...
    'hvTolerance', design.hvTolerance, ...
    'actionableBudgetFraction', design.actionableBudgetFraction, ...
    'specSha256', specSha256, ...
    'authorizationSha256', authorizationSha256);
environment = struct('schema', "mdt.environment.v0.1", ...
    'matlabVersion', string(version), 'matlabRelease', string(version('-release')), ...
    'computer', string(computer), 'numericType', "double", ...
    'device', "CPU", 'parallelWorkers', 0);
writeJson(fullfile(runDir, 'config.json'), config);
writeJson(fullfile(runDir, 'environment.json'), environment);
writeJson(fullfile(runDir, 'diagnostic.json'), diagnostic);
traceTable = array2table(result.trace, ...
    'VariableNames', cellstr(result.traceColumns));
writetable(traceTable, fullfile(runDir, 'raw_metrics.csv'));
save(fullfile(runDir, 'result.mat'), 'result', '-v7');
writeText(fullfile(runDir, 'stdout.log'), join([
    "H10 stagnation diagnostic completed."
    "Instance: "+item.instanceId
    "Seed: "+result.audit.seed
    "NFE: "+result.metrics.evaluations
    "Actionable stagnation: "+diagnostic.actionableStagnation], newline));
writeText(fullfile(runDir, 'stderr.log'), "");

names = ["config.json", "environment.json", "diagnostic.json", ...
    "raw_metrics.csv", "result.mat", "stdout.log", "stderr.log"];
artifacts = repmat(struct('path', "", 'sha256', "", 'bytes', 0), ...
    numel(names), 1);
for i = 1:numel(names)
    path = fullfile(runDir, names(i));
    info = dir(path);
    artifacts(i) = struct('path', names(i), ...
        'sha256', sha256File(path), 'bytes', info.bytes);
end
manifest = struct();
manifest.schema = "light.run_manifest.v3";
manifest.run_id = item.instanceId+"__seed-"+result.audit.seed+"__attempt-1";
manifest.matrix_row = design.matrixRow;
manifest.status = "completed";
manifest.termination = struct('reason', "natural_exit", 'exit_code', 0);
manifest.seed = struct('role', "stagnation_diagnostic", ...
    'value', result.audit.seed);
manifest.started_at = result.audit.startedAt;
manifest.ended_at = result.audit.endedAt;
manifest.code = struct('commit', "UNAVAILABLE_NON_GIT_WORKSPACE", ...
    'dirty', true);
manifest.inputs = struct('specSha256', specSha256, ...
    'authorizationSha256', authorizationSha256, ...
    'frozenInstanceSha256', cfg.frozenSpecSha256);
manifest.artifacts = artifacts;
manifest.completion = struct('status', "PASS", ...
    'oracle', "fixed budget and stagnation diagnostic completed", ...
    'guardrail_evidence_artifacts', ["diagnostic.json", "raw_metrics.csv"]);
manifest.notes = [
    "Development diagnostic only; no algorithm superiority claim."
    "A repair branch is allowed only by the complete batch decision."];
writeJson(fullfile(runDir, 'manifest.json'), manifest);
end

function rows = makeResultTable(count)
rows = table('Size', [count, 13], 'VariableTypes', ...
    {'string','double','logical','double','double','double','double', ...
    'double','double','double','double','string','string'}, ...
    'VariableNames', {'instanceId','seed','actionableStagnation', ...
    'firstTriggerGeneration','maximumStagnationLength','pcrAuc', ...
    'finalPcr','finalHv','finalArchiveSize','visitedStates', ...
    'runtimeSeconds','status','runDir'});
end

function row = resultRow(instanceId, seed, result, diagnostic, runDir, status)
row = cell2table({instanceId, seed, diagnostic.actionableStagnation, ...
    diagnostic.firstTriggerGeneration, diagnostic.maximumStagnationLength, ...
    result.metrics.pcrAuc, result.metrics.finalPcr, result.metrics.finalHv, ...
    size(result.finalArchive.X, 1), ...
    result.audit.visitLedgerStoredStateCount, result.metrics.runtimeSeconds, ...
    status, runDir}, 'VariableNames', makeResultTable(1).Properties.VariableNames);
end

function row = failedRow(instanceId, seed, failureId)
row = cell2table({instanceId, seed, false, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, "failed", "failures/"+failureId}, ...
    'VariableNames', makeResultTable(1).Properties.VariableNames);
end

function value = ternary(condition, ifTrue, ifFalse)
if condition
    value = ifTrue;
else
    value = ifFalse;
end
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

function writeText(path, value)
fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('mdt:ArtifactWriteFailure', 'Unable to write artifact: %s', path);
end
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, char(join(string(value), newline)), 'char');
end
