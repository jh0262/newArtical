function summary = runH13PublicComparisonBatch(outputDir, mode)
%RUNH13PUBLICCOMPARISONBATCH Execute or resume H13 public comparisons.

arguments
    outputDir (1,1) string
    mode (1,1) string {mustBeMember(mode, ["formal", "preflight"])} = "formal"
end
if strlength(outputDir) == 0
    error('mdt:InvalidOutputDirectory', 'outputDir must be nonempty.');
end

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
design = mdt.makeH13PublicComparisonDesign();
if mode == "preflight"
    design = makePreflightDesign(design);
end
matrix = mdt.makeH13RunMatrix(design);
registry = mdt.makeH12PublicBenchmarkSet();
if mode == "formal"
    validateFormalInputs(projectRoot, matrix);
end

initializeOrValidateBatch(outputDir, mode, design, matrix, projectRoot);
sourceFiles = jsondecode(fileread(fullfile(outputDir, ...
    'source_manifest.json'))).files;
rows = makeResultTable(height(matrix));
completedRuns = 0;
failedRuns = 0;
resumedRuns = 0;
startedAt = localNow();
batchTimer = tic;
writeBatchManifest(outputDir, "RUNNING", design, mode, ...
    startedAt, completedRuns, failedRuns, resumedRuns, 0, strings(0, 1));
failureIds = strings(0, 1);

for rowIndex = 1:height(matrix)
    item = matrix(rowIndex, :);
    benchmark = benchmarkById(registry, item.problemId);
    runBase = fullfile(outputDir, 'runs', item.problemId, ...
        lower(item.algorithm), "seed-"+item.seed);
    [found, stored, storedDir, nextAttempt] = ...
        findCompletedRun(runBase);
    if found
        rows(rowIndex, :) = summaryRow(stored, storedDir);
        completedRuns = completedRuns+1;
        resumedRuns = resumedRuns+1;
        fprintf('H13 RESUME %d/%d %s\n', rowIndex, height(matrix), ...
            item.runId);
        continue;
    end

    attemptDir = fullfile(runBase, "attempt-"+nextAttempt);
    config = makeRunConfig(item, design, mode, nextAttempt);
    runStartedAt = localNow();
    try
        result = executeAlgorithm(item.algorithm, benchmark, config, ...
            mode == "formal");
        runEndedAt = localNow();
        resultSummary = summarizeResult(result, benchmark, item, ...
            nextAttempt, mode == "formal", runStartedAt, runEndedAt);
        writeCompletedBundle(attemptDir, config, result, resultSummary, ...
            benchmark, sourceFiles, projectRoot);
        rows(rowIndex, :) = summaryRow(resultSummary, attemptDir);
        completedRuns = completedRuns+1;
        fprintf('H13 COMPLETE %d/%d %s HV=%.12g feasible=%.4f\n', ...
            rowIndex, height(matrix), item.runId, ...
            resultSummary.normalizedFeasibleHv, ...
            resultSummary.finalFeasibleRate);
    catch errorRecord
        writeFailureBundle(attemptDir, config, errorRecord, sourceFiles, ...
            runStartedAt, localNow());
        rows(rowIndex, :) = failedRow(item, nextAttempt, attemptDir);
        failedRuns = failedRuns+1;
        failureIds(end+1, 1) = item.runId+":"+ ...
            string(errorRecord.identifier); %#ok<AGROW>
        fprintf(2, 'H13 FAILED %d/%d %s %s\n', rowIndex, ...
            height(matrix), item.runId, errorRecord.identifier);
    end
    writeProgress(outputDir, rows(1:rowIndex, :));
    writeBatchManifest(outputDir, "RUNNING", design, mode, ...
        startedAt, completedRuns, failedRuns, resumedRuns, ...
        toc(batchTimer), failureIds);
end

writetable(rows, fullfile(outputDir, 'h13_results.csv'));
status = "COMPLETE";
if failedRuns > 0
    status = "INCOMPLETE";
end
writeBatchManifest(outputDir, status, design, mode, startedAt, ...
    completedRuns, failedRuns, resumedRuns, toc(batchTimer), failureIds);
summary = struct('schema', "mdt.h13-batch-summary.v1.0", ...
    'mode', mode, 'status', status, 'outputDir', outputDir, ...
    'expectedRuns', height(matrix), 'completedRuns', completedRuns, ...
    'failedRuns', failedRuns, 'resumedRuns', resumedRuns, ...
    'walltimeSeconds', toc(batchTimer));
end

function design = makePreflightDesign(design)
design.status = "PREFLIGHT_ONLY";
design.scope = "H13 batch writer and resume preflight; no performance claim";
design.seeds = 13025;
design.populationSize = 12;
design.archiveCapacity = 24;
for i = 1:numel(design.problems)
    design.problems(i).nominalBudget = 36;
    design.problems(i).executionBudget = 36;
    design.problems(i).budgetPolicy = "preflight_exact";
end
design.expectedRuns = 15;
design.expectedPairedSets = 3;
end

function validateFormalInputs(projectRoot, matrix)
required = [
    fullfile(projectRoot, '.light', 'h13', 'formal_run_matrix.json')
    fullfile(projectRoot, 'evidence', 'h13_preflight_junit.xml')];
for path = required
    if ~isfile(path)
        error('mdt:H13FormalPreflightMissing', ...
            'Formal H13 input is missing: %s', path);
    end
end
frozen = jsondecode(fileread(required(1)));
if ~isfield(frozen, 'runs') || numel(frozen.runs) ~= height(matrix)
    error('mdt:H13RunMatrixDrift', ...
        'Frozen H13 run matrix has invalid coverage.');
end
frozenIds = string({frozen.runs.runId})';
if ~isequal(frozenIds, matrix.runId)
    error('mdt:H13RunMatrixDrift', ...
        'Frozen H13 run IDs differ from the executable matrix.');
end
end

function initializeOrValidateBatch(outputDir, mode, design, matrix, projectRoot)
configPath = fullfile(outputDir, 'batch_config.json');
if isfolder(outputDir)
    if ~isfile(configPath)
        error('mdt:H13OutputCollision', ...
            'Existing output directory lacks batch_config.json.');
    end
    existing = jsondecode(fileread(configPath));
    validateExistingConfig(existing, mode, design);
    return;
end
if isfile(outputDir)
    error('mdt:H13OutputCollision', ...
        'Output path already exists as a file.');
end
mkdir(outputDir);
mkdir(fullfile(outputDir, 'runs'));
writeJsonAtomic(configPath, struct('schema', ...
    "mdt.h13-batch-config.v1.0", 'mode', mode, 'design', design));
writetable(matrix, fullfile(outputDir, 'run_matrix.csv'));
sourceManifest = struct('schema', "mdt.source-manifest.v1.0", ...
    'files', collectSources(projectRoot));
writeJsonAtomic(fullfile(outputDir, 'source_manifest.json'), sourceManifest);
end

function validateExistingConfig(existing, mode, design)
if string(existing.mode) ~= mode || ...
        string(existing.design.schema) ~= design.schema || ...
        ~isequal(double(existing.design.seeds(:)'), design.seeds) || ...
        double(existing.design.populationSize) ~= design.populationSize || ...
        ~isequal(string(existing.design.algorithms(:)'), design.algorithms) || ...
        ~isequal([existing.design.problems.executionBudget], ...
        [design.problems.executionBudget]) || ...
        string(existing.design.seedManifestSha256) ~= ...
        design.seedManifestSha256 || ...
        string(existing.design.specSha256) ~= design.specSha256
    error('mdt:H13ResumeIdentityMismatch', ...
        'Existing H13 output does not match the frozen design.');
end
end

function benchmark = benchmarkById(registry, problemId)
ids = string({registry.included.id});
index = find(ids == problemId, 1);
if isempty(index)
    error('mdt:H13UnknownProblem', 'Unknown H13 problem: %s', problemId);
end
benchmark = registry.included(index);
end

function config = makeRunConfig(item, design, mode, attempt)
config = struct();
config.schema = "mdt.h13-run-config.v1.0";
config.runId = item.runId;
config.pairId = item.pairId;
config.matrixRow = item.matrixRow;
config.problemId = item.problemId;
config.algorithm = item.algorithm;
config.seed = item.seed;
config.seedRole = "randomness_estimation";
config.populationSize = item.populationSize;
config.nominalBudget = item.nominalBudget;
config.executionBudget = item.executionBudget;
config.archiveCapacity = design.archiveCapacity;
config.mode = mode;
config.attempt = attempt;
config.tuningBudget = design.tuningBudget;
config.primaryMetric = design.primaryMetric;
config.specSha256 = design.specSha256;
config.seedManifestSha256 = design.seedManifestSha256;
config.authorizationSha256 = design.authorizationSha256;
config.budgetAmendmentSha256 = design.budgetAmendmentSha256;
end

function result = executeAlgorithm(algorithm, benchmark, config, isFormal)
dimension = numel(benchmark.variableSpec.continuousLower) + ...
    numel(benchmark.variableSpec.discreteCardinalities);
op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10, 'crossoverProbability', 0.9, ...
    'mutationProbability', 1/dimension, 'etaC', 20, 'etaM', 20);
if ismember(algorithm, ["B1", "B5S", "N2"])
    result = mdt.runBlackBoxComparator(algorithm, benchmark.evaluator, ...
        benchmark.variableSpec, op, config.seed, config.populationSize, ...
        config.executionBudget, config.archiveCapacity);
else
    result = mdt.runPlatEMOBaseline(algorithm, benchmark, config.seed, ...
        config.populationSize, config.executionBudget, isFormal);
end
end

function item = summarizeResult(result, benchmark, matrixItem, attempt, ...
    isFormal, executionStartedAt, executionEndedAt)
if result.audit.evaluatorCalls ~= matrixItem.executionBudget
    error('mdt:H13NfeViolation', ...
        'Actual evaluator calls differ from the frozen execution budget.');
end
population = result.finalPopulation;
if any(~isfinite(population.X), 'all') || ...
        any(~isfinite(population.obj), 'all') || ...
        any(~isfinite(population.con), 'all')
    error('mdt:H13NonfiniteOutput', 'Final output contains NaN or Inf.');
end
validateFinalDecisionTypes(population.X, benchmark.variableSpec);
[hv, hvAudit] = mdt.computeNormalizedFeasibleHV(population.obj, ...
    population.con, benchmark.idealPoint, benchmark.nadirPoint, ...
    benchmark.hvReferencePoint);
constraintScales = benchmark.variableSpec.constraintScales(:)';
normalizedCv = sum(max(population.con, 0)./constraintScales, 2);
[firstFeasibleNfe, eventObserved] = firstFeasible(result, ...
    matrixItem.executionBudget);

item = struct();
item.schema = "mdt.h13-run-summary.v1.0";
item.runId = matrixItem.runId;
item.pairId = matrixItem.pairId;
item.problemId = matrixItem.problemId;
item.algorithm = matrixItem.algorithm;
item.seed = matrixItem.seed;
item.nominalBudget = matrixItem.nominalBudget;
item.executionBudget = matrixItem.executionBudget;
item.actualNfe = result.audit.evaluatorCalls;
item.normalizedFeasibleHv = hv;
item.finalFeasibleRate = mean(all(population.con <= 0, 2));
item.feasibleNdSize = hvAudit.nondominatedCount;
item.meanNormalizedCv = mean(normalizedCv);
item.runtimeSeconds = result.metrics.runtimeSeconds;
item.firstFeasibleNfe = firstFeasibleNfe;
item.feasibleEventObserved = eventObserved;
item.status = "completed";
item.attempt = attempt;
item.truthUsed = result.audit.truthUsed;
item.formalPerformanceRun = mdt.resolveH13FormalRole( ...
    result.audit, isFormal);
item.executionStartedAt = executionStartedAt;
item.executionEndedAt = executionEndedAt;
end

function [nfe, observed] = firstFeasible(result, executionBudget)
nfeIndex = find(result.traceColumns == "nfe", 1);
rateIndex = find(result.traceColumns == "feasibleRate", 1);
if isempty(nfeIndex) || isempty(rateIndex)
    error('mdt:H13TraceContract', ...
        'Result lacks NFE or feasible-rate trace columns.');
end
hit = find(result.trace(:, rateIndex) > 0, 1);
observed = ~isempty(hit);
if observed
    nfe = result.trace(hit, nfeIndex);
else
    nfe = executionBudget;
end
end

function validateFinalDecisionTypes(X, spec)
continuousCount = numel(spec.continuousLower);
continuous = X(:, 1:continuousCount);
if any(continuous < spec.continuousLower-1e-12, 'all') || ...
        any(continuous > spec.continuousUpper+1e-12, 'all')
    error('mdt:H13DecisionTypeViolation', ...
        'Final continuous decision lies outside bounds.');
end
discrete = X(:, continuousCount+1:end);
if any(discrete ~= round(discrete), 'all') || ...
        any(discrete < 0, 'all') || ...
        any(discrete >= spec.discreteCardinalities, 'all')
    error('mdt:H13DecisionTypeViolation', ...
        'Final discrete decision violates integer code bounds.');
end
end

function writeCompletedBundle(runDir, config, result, summary, benchmark, ...
    sourceFiles, projectRoot)
if isfolder(runDir) || isfile(runDir)
    error('mdt:H13AttemptCollision', ...
        'Refusing to overwrite an existing run attempt: %s', runDir);
end
mkdir(runDir);
writeJsonAtomic(fullfile(runDir, 'config.json'), config);
writeJsonAtomic(fullfile(runDir, 'environment.json'), environmentInfo());
writeJsonAtomic(fullfile(runDir, 'input_contract.json'), struct( ...
    'benchmark', rmfield(benchmark, 'evaluator'), ...
    'sourceFiles', sourceFiles));
writeJsonAtomic(fullfile(runDir, 'result_summary.json'), summary);
writetable(populationTable(result.finalPopulation), ...
    fullfile(runDir, 'final_population.csv'));
writetable(populationTable(result.finalArchive), ...
    fullfile(runDir, 'final_archive.csv'));
traceTable = array2table(result.trace, ...
    'VariableNames', cellstr(result.traceColumns));
writetable(traceTable, fullfile(runDir, 'trace.csv'));
writetable(struct2table(summary, 'AsArray', true), ...
    fullfile(runDir, 'raw_metrics.csv'));
guardrails = struct('schema', "mdt.h13-guardrails.v1.0", ...
    'nfeExact', summary.actualNfe == summary.executionBudget, ...
    'finiteOutputs', true, 'decisionTypesValid', true, ...
    'truthUsed', summary.truthUsed, 'formalRoleRecorded', ...
    summary.formalPerformanceRun || config.mode == "preflight");
writeJsonAtomic(fullfile(runDir, 'guardrails.json'), guardrails);
testPath = fullfile(projectRoot, 'evidence', 'h13_preflight_junit.xml');
testEvidence = struct('status', "UNAVAILABLE_PREFLIGHT");
if isfile(testPath)
    testEvidence = struct('status', "AVAILABLE", ...
        'path', "evidence/h13_preflight_junit.xml", ...
        'sha256', sha256File(testPath));
end
writeJsonAtomic(fullfile(runDir, 'test_evidence.json'), testEvidence);
writeText(fullfile(runDir, 'stdout.log'), ...
    "Completed "+summary.runId+" with "+summary.actualNfe+" evaluations.");
writeText(fullfile(runDir, 'stderr.log'), "");
artifacts = hashArtifacts(runDir);
manifest = struct('schema', "light.run_manifest.v3", ...
    'run_id', summary.runId+"__attempt-"+summary.attempt, ...
    'matrix_row_id', config.matrixRow, 'pair_id', config.pairId, ...
    'status', "completed", 'termination', "evaluation_budget_reached", ...
    'completion', struct('oracle_passed', true, ...
    'guardrail_evidence_artifacts', "guardrails.json"), ...
    'seed', struct('role', config.seedRole, 'value', config.seed), ...
    'started_at', summary.executionStartedAt, ...
    'ended_at', summary.executionEndedAt, ...
    'attempt', config.attempt, 'artifacts', artifacts, ...
    'resultSummarySha256', sha256File(fullfile(runDir, ...
    'result_summary.json')));
writeJsonAtomic(fullfile(runDir, 'manifest.json'), manifest);
end

function writeFailureBundle(runDir, config, errorRecord, sourceFiles, ...
    executionStartedAt, executionEndedAt)
if isfolder(runDir) || isfile(runDir)
    error('mdt:H13AttemptCollision', ...
        'Refusing to overwrite an existing failure attempt: %s', runDir);
end
mkdir(runDir);
writeJsonAtomic(fullfile(runDir, 'config.json'), config);
writeJsonAtomic(fullfile(runDir, 'environment.json'), environmentInfo());
failure = struct('schema', "mdt.h13-run-failure.v1.0", ...
    'runId', config.runId, 'identifier', string(errorRecord.identifier), ...
    'message', string(errorRecord.message), ...
    'report', string(getReport(errorRecord, 'extended', ...
    'hyperlinks', 'off')), 'sourceFiles', sourceFiles);
writeJsonAtomic(fullfile(runDir, 'failure.json'), failure);
writeJsonAtomic(fullfile(runDir, 'guardrails.json'), struct( ...
    'schema', "mdt.h13-guardrails.v1.0", 'oraclePassed', false));
writeText(fullfile(runDir, 'stdout.log'), "");
writeText(fullfile(runDir, 'stderr.log'), failure.report);
artifacts = hashArtifacts(runDir);
manifest = struct('schema', "light.run_manifest.v3", ...
    'run_id', config.runId+"__attempt-"+config.attempt, ...
    'matrix_row_id', config.matrixRow, 'pair_id', config.pairId, ...
    'status', "failed", 'termination', "exception", ...
    'completion', struct('oracle_passed', false, ...
    'guardrail_evidence_artifacts', "guardrails.json"), ...
    'seed', struct('role', config.seedRole, 'value', config.seed), ...
    'started_at', executionStartedAt, 'ended_at', executionEndedAt, ...
    'attempt', config.attempt, 'artifacts', artifacts);
writeJsonAtomic(fullfile(runDir, 'manifest.json'), manifest);
end

function tableValue = populationTable(population)
values = [population.X, population.obj, population.con];
names = ["x"+(1:size(population.X, 2)), ...
    "f"+(1:size(population.obj, 2)), ...
    "g"+(1:size(population.con, 2))];
tableValue = array2table(values, 'VariableNames', cellstr(names));
end

function [found, summary, runDir, nextAttempt] = findCompletedRun(runBase)
found = false;
summary = struct();
runDir = "";
attempts = dir(fullfile(runBase, 'attempt-*'));
attempts = attempts([attempts.isdir]);
numbers = zeros(1, numel(attempts));
for i = 1:numel(attempts)
    numbers(i) = sscanf(attempts(i).name, 'attempt-%d');
end
[numbers, order] = sort(numbers, 'descend');
attempts = attempts(order);
for i = 1:numel(attempts)
    candidate = fullfile(attempts(i).folder, attempts(i).name);
    manifestPath = fullfile(candidate, 'manifest.json');
    resultPath = fullfile(candidate, 'result_summary.json');
    if ~isfile(manifestPath) || ~isfile(resultPath)
        continue;
    end
    manifest = jsondecode(fileread(manifestPath));
    if string(manifest.status) ~= "completed"
        continue;
    end
    if string(manifest.resultSummarySha256) ~= sha256File(resultPath)
        error('mdt:H13ResumeArtifactMismatch', ...
            'Completed run summary hash mismatch: %s', candidate);
    end
    found = true;
    summary = jsondecode(fileread(resultPath));
    runDir = string(candidate);
    break;
end
if isempty(numbers)
    nextAttempt = 1;
else
    nextAttempt = max(numbers)+1;
end
end

function row = summaryRow(item, runDir)
row = cell2table({string(item.problemId), string(item.algorithm), ...
    double(item.seed), double(item.nominalBudget), ...
    double(item.executionBudget), double(item.actualNfe), ...
    double(item.normalizedFeasibleHv), double(item.finalFeasibleRate), ...
    double(item.feasibleNdSize), double(item.meanNormalizedCv), ...
    double(item.runtimeSeconds), double(item.firstFeasibleNfe), ...
    logical(item.feasibleEventObserved), "completed", ...
    string(item.runId), replace(string(runDir), "\", "/"), ...
    double(item.attempt)}, ...
    'VariableNames', makeResultTable(1).Properties.VariableNames);
end

function row = failedRow(item, attempt, runDir)
row = cell2table({item.problemId, item.algorithm, item.seed, ...
    item.nominalBudget, item.executionBudget, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, false, "failed", item.runId, ...
    replace(string(runDir), "\", "/"), attempt}, ...
    'VariableNames', makeResultTable(1).Properties.VariableNames);
end

function rows = makeResultTable(count)
rows = table('Size', [count, 17], 'VariableTypes', ...
    {'string','string','double','double','double','double','double', ...
    'double','double','double','double','double','logical','string', ...
    'string','string','double'}, 'VariableNames', ...
    {'problemId','algorithm','seed','nominalBudget','executionBudget', ...
    'actualNfe','normalizedFeasibleHv','finalFeasibleRate', ...
    'feasibleNdSize','meanNormalizedCv','runtimeSeconds', ...
    'firstFeasibleNfe','feasibleEventObserved','status','runId', ...
    'runDir','attempt'});
end

function writeProgress(outputDir, rows)
writetable(rows, fullfile(outputDir, 'h13_progress.csv'));
end

function writeBatchManifest(outputDir, status, design, mode, startedAt, ...
    completed, failed, resumed, walltime, failures)
entries = dir(fullfile(outputDir, '**', '*'));
manifest = struct('schema', "mdt.h13-batch-manifest.v1.0", ...
    'status', status, 'mode', mode, 'startedAt', startedAt, ...
    'updatedAt', localNow(), 'expectedRuns', design.expectedRuns, ...
    'completedRuns', completed, 'failedRuns', failed, ...
    'resumedRuns', resumed, 'failures', failures, ...
    'walltimeSeconds', walltime, ...
    'storageBytes', sum([entries(~[entries.isdir]).bytes]), ...
    'claimRequiresResultAnalysis', true);
writeJsonAtomic(fullfile(outputDir, 'batch_manifest.json'), manifest);
end

function artifacts = hashArtifacts(runDir)
files = dir(fullfile(runDir, '*'));
files = files(~[files.isdir]);
files = files(~strcmp({files.name}, 'manifest.json'));
artifacts = repmat(struct('path', "", 'sha256', ""), numel(files), 1);
for i = 1:numel(files)
    artifacts(i).path = string(files(i).name);
    artifacts(i).sha256 = sha256File(fullfile(runDir, files(i).name));
end
end

function files = collectSources(projectRoot)
source = [dir(fullfile(projectRoot, 'matlab', '+mdt', '**', '*.m')); ...
    dir(fullfile(projectRoot, 'matlab', 'MDT*.m')); ...
    dir(fullfile(projectRoot, 'tests', '*.m'))];
fixed = [
    ".light/h12/PROJECT_PLAN.md"
    ".light/h12/preregistration.md"
    ".light/h12/experiment_matrix.md"
    ".light/h12/failure_tree_report.json"
    ".light/h13/H13_FORMAL_PUBLIC_COMPARISON_SPEC.md"
    ".light/h13/h13_authorization.json"
    ".light/h13/h13_seed_manifest.json"
    ".light/h13/budget_amendment_v1.md"
    ".light/h13/failure-tree.json"
    ".light/h13/failure_tree_report.json"
    ".light/h13/formal_run_matrix.json"];
relative = fixed;
for item = source'
    absolute = string(fullfile(item.folder, item.name));
    relative(end+1, 1) = replace(extractAfter(absolute, ...
        strlength(projectRoot)+1), "\", "/"); %#ok<AGROW>
end
relative = sort(unique(relative));
files = repmat(struct('path', "", 'sha256', ""), numel(relative), 1);
for i = 1:numel(relative)
    files(i).path = relative(i);
    files(i).sha256 = sha256File(fullfile(projectRoot, relative(i)));
end
end

function info = environmentInfo()
info = struct('schema', "mdt.environment.v1.0", ...
    'matlabVersion', string(version), 'computer', string(computer), ...
    'operatingSystem', string(system_dependent('getos')), ...
    'numericType', "double", 'device', "CPU", ...
    'parallelExecution', false);
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

function value = localNow()
value = string(datetime('now', 'TimeZone', 'local', ...
    'Format', "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"));
end

function writeJsonAtomic(path, value)
temporary = string(path)+".tmp";
fileId = fopen(temporary, 'w', 'n', 'UTF-8');
if fileId < 0
    error('mdt:ArtifactWriteFailure', ...
        'Unable to write artifact: %s', temporary);
end
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, char(string(jsonencode(value, PrettyPrint=true))), 'char');
clear cleanup
[ok, message] = movefile(temporary, path, 'f');
if ~ok
    error('mdt:ArtifactMoveFailure', '%s', message);
end
end

function writeText(path, value)
fileId = fopen(path, 'w', 'n', 'UTF-8');
if fileId < 0
    error('mdt:ArtifactWriteFailure', ...
        'Unable to write artifact: %s', path);
end
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId, char(string(value)), 'char');
end
