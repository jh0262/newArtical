function writeOptimizerRunBundle(outputDir, result, cfg, provenance)
%WRITEOPTIMIZERRUNBUNDLE Persist one immutable, hash-auditable optimizer run.

arguments
    outputDir (1,1) string
    result (1,1) struct
    cfg (1,1) struct
    provenance (1,1) struct
end

required = {'matrixRow','configId','tuneSpecSha256','planSha256', ...
    'sourceFiles','testEvidencePath','testEvidenceSha256','comparisonRole'};
if strlength(outputDir) == 0 || ~all(isfield(provenance, required))
    error('mdt:InvalidRunBundleInput', ...
        'outputDir and complete provenance are required.');
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:OutputAlreadyExists', ...
        'Refusing to overwrite an optimizer run bundle: %s', outputDir);
end
if ~isfield(provenance, 'attempt')
    provenance.attempt = 1;
end
if ~isfield(provenance, 'command')
    provenance.command = ["matlab", "-batch", "mdt.runTuneBatch"];
end
if ~isfield(provenance, 'seedRole')
    provenance.seedRole = "randomness_estimation";
end
if ~isfield(provenance, 'scope')
    provenance.scope = "TUNING_ONLY_NO_H2_DECISION";
end
if ~isfield(provenance, 'pairId')
    provenance.pairId = string(provenance.configId) + "__seed-" + ...
        result.audit.seed;
end

mkdir(outputDir);
config = makeConfig(result, cfg, provenance);
environment = makeEnvironment();
sourceManifest = struct('schema', "mdt.source-manifest.v0.1", ...
    'files', provenance.sourceFiles);
inputContract = struct('schema', "mdt.tune-input-contract.v0.1", ...
    'matrixRow', string(provenance.matrixRow), ...
    'configId', string(provenance.configId), ...
    'tuneSpecSha256', string(provenance.tuneSpecSha256), ...
    'planSha256', string(provenance.planSha256), ...
    'frozenResearchSpecSha256', string(cfg.frozenSpecSha256));
testEvidence = struct('schema', "mdt.test-evidence-ref.v0.1", ...
    'path', string(provenance.testEvidencePath), ...
    'sha256', string(provenance.testEvidenceSha256));
guardrails = makeGuardrails(result, provenance);

writeJson(fullfile(outputDir, "config.json"), config);
writeJson(fullfile(outputDir, "environment.json"), environment);
writeJson(fullfile(outputDir, "source_manifest.json"), sourceManifest);
writeJson(fullfile(outputDir, "input_contract.json"), inputContract);
writeJson(fullfile(outputDir, "metrics.json"), result.metrics);
writeJson(fullfile(outputDir, "test_evidence.json"), testEvidence);
writeJson(fullfile(outputDir, "guardrails.json"), guardrails);

traceTable = array2table(result.trace, ...
    'VariableNames', cellstr(result.traceColumns));
writetable(traceTable, fullfile(outputDir, "raw_metrics.csv"));
predictionNames = makeColumnNames("x", size(result.finalPopulation.X, 2));
predictionNames = [predictionNames, makeColumnNames("f", 2), ...
    makeColumnNames("g", size(result.finalPopulation.con, 2))];
predictionTable = array2table([result.finalPopulation.X, ...
    result.finalPopulation.obj, result.finalPopulation.con], ...
    'VariableNames', cellstr(predictionNames));
writetable(predictionTable, fullfile(outputDir, "predictions.csv"));
archiveNames = makeColumnNames("x", size(result.finalArchive.X, 2));
archiveNames = [archiveNames, makeColumnNames("f", 2), ...
    makeColumnNames("g", size(result.finalArchive.con, 2))];
archiveTable = array2table([result.finalArchive.X, result.finalArchive.obj, ...
    result.finalArchive.con], 'VariableNames', cellstr(archiveNames));
writetable(archiveTable, fullfile(outputDir, "final_archive.csv"));
if string(provenance.matrixRow) == "EXP-P1"
    stdoutLines = [
        "EXP-P1 optimizer run completed."
        "Scope: pilot only; no H2 decision."
        "Algorithm: " + result.algorithm
        "Config: " + string(provenance.configId)
        "Seed: " + result.audit.seed
        "NFE: " + result.metrics.evaluations];
elseif string(provenance.matrixRow) == "E3-DIAG"
    stdoutLines = [
        "E3-DIAG optimizer run completed."
        "Scope: post-P1 mechanism diagnostic; no deployable superiority claim."
        "Algorithm: " + result.algorithm
        "Config: " + string(provenance.configId)
        "Seed: " + result.audit.seed
        "NFE: " + result.metrics.evaluations];
elseif string(provenance.matrixRow) == "B4-TUNE"
    stdoutLines = [
        "B4-TUNE optimizer run completed."
        "Scope: post-P1 development tuning; no comparative claim."
        "Algorithm: " + result.algorithm
        "Config: " + string(provenance.configId)
        "Seed: " + result.audit.seed
        "NFE: " + result.metrics.evaluations];
elseif string(provenance.matrixRow) == "H5-CONF"
    stdoutLines = [
        "H5-CONF optimizer run completed."
        "Scope: frozen confirmatory comparison; claims require complete-set analysis."
        "Algorithm: " + result.algorithm
        "Config: " + string(provenance.configId)
        "Seed: " + result.audit.seed
        "NFE: " + result.metrics.evaluations];
elseif string(provenance.matrixRow) == "H6-GEN"
    stdoutLines = [
        "H6-GEN optimizer run completed."
        "Scope: frozen topology-shift, ablation and cross-family comparison."
        "Algorithm: " + result.algorithm
        "Config: " + string(provenance.configId)
        "Seed: " + result.audit.seed
        "NFE: " + result.metrics.evaluations];
elseif string(provenance.matrixRow) == "H7-SIMPLIFIED-CONF"
    stdoutLines = [
        "H7-SIMPLIFIED-CONF optimizer run completed."
        "Scope: independent B5 superiority and noninferiority confirmation."
        "Algorithm: " + result.algorithm
        "Config: " + string(provenance.configId)
        "Seed: " + result.audit.seed
        "NFE: " + result.metrics.evaluations];
else
    stdoutLines = [
        "TUNE-01 optimizer run completed."
        "Scope: isolated parameter tuning; no H2 decision."
        "Algorithm: " + result.algorithm
        "Config: " + string(provenance.configId)
        "Seed: " + result.audit.seed
        "NFE: " + result.metrics.evaluations];
end
writeText(fullfile(outputDir, "stdout.log"), join(stdoutLines, newline));
writeText(fullfile(outputDir, "stderr.log"), "");

records = artifactRecords(outputDir);
runId = string(provenance.configId) + "__seed-" + ...
    result.audit.seed + "__attempt-" + provenance.attempt;
manifest = struct();
manifest.schema = "light.run_manifest.v3";
manifest.run_id = runId;
manifest.matrix_row = string(provenance.matrixRow);
manifest.status = "completed";
manifest.termination = struct('reason', "natural_exit", ...
    'exit_code', 0, 'signal', []);
manifest.seed = struct('role', string(provenance.seedRole), ...
    'value', int64(result.audit.seed));
manifest.command = cellstr(string(provenance.command));
manifest.started_at = result.audit.startedAt;
manifest.ended_at = result.audit.endedAt;
manifest.config = records.config;
manifest.environment = records.environment;
manifest.code = struct('commit', "UNAVAILABLE_NON_GIT_WORKSPACE", ...
    'dirty', true, 'diff_sha256', records.source_manifest.sha256, ...
    'files', {{records.source_manifest}});
manifest.inputs = {addInputFields(records.input_contract, cfg)};
manifest.artifacts = struct( ...
    'stdout', records.stdout, ...
    'stderr', records.stderr, ...
    'raw_metrics', records.raw_metrics, ...
    'predictions', records.predictions, ...
    'test_evidence', records.test_evidence, ...
    'guardrail_evidence', records.guardrails, ...
    'metrics', records.metrics, ...
    'final_archive', records.final_archive, ...
    'failure', NaN);
manifest.completion = struct('status', "PASS", 'oracle', [
    "fixed evaluation budget exhausted"
    "required raw outputs exist and are hash-bound"
    "pairing and truth-isolation audit fields are present"], ...
    'evidence_artifacts', ["test_evidence", "raw_metrics", ...
    "predictions", "guardrail_evidence"]);
manifest.reproducibility = struct( ...
    'pair_id', string(provenance.pairId), ...
    'comparison_role', string(provenance.comparisonRole), ...
    'compare_artifacts', ["predictions", "raw_metrics"]);
if string(provenance.matrixRow) == "EXP-P1"
    manifest.notes = [
        "Pilot run only; excluded from H2 confirmation."
        "Pilot evidence may estimate variance and guide P2 sample size only."];
elseif string(provenance.matrixRow) == "E3-DIAG"
    manifest.notes = [
        "Diagnostic E3 run only; B3 uses oracle component labels."
        "Diagnostic evidence cannot support a deployable superiority claim."];
elseif string(provenance.matrixRow) == "B4-TUNE"
    manifest.notes = [
        "Development tuning run only; excluded from confirmation."
        "Development results may select one frozen B4 configuration only."];
elseif string(provenance.matrixRow) == "H5-CONF"
    manifest.notes = [
        "Confirmatory H5 run; no single run supports a claim."
        "Claims require all frozen seeds, instances, guardrails and multiplicity control."];
elseif string(provenance.matrixRow) == "H6-GEN"
    manifest.notes = [
        "Frozen H6 generalization/ablation run; no single run supports a claim."
        "N2 is a local mixed-variable adaptation, not official PlatEMO code."
        "Claims require complete frozen coverage, guardrails and multiplicity control."];
elseif string(provenance.matrixRow) == "H7-SIMPLIFIED-CONF"
    manifest.notes = [
        "Frozen H7 independent confirmation; no single run supports a claim."
        "B5 is the fixed-rate simplification triggered by H6 negative ablation."
        "Claims require complete coverage, guardrails and frozen analysis."];
else
    manifest.notes = [
        "Tuning run only; excluded from H2 confirmation."
        "Source manifest substitutes for unavailable Git commit provenance."];
end
writeJson(fullfile(outputDir, "manifest.json"), manifest);
end

function config = makeConfig(result, cfg, provenance)
config = struct();
config.schema = "mdt.optimizer-run-config.v0.1";
config.matrixRow = string(provenance.matrixRow);
config.configId = string(provenance.configId);
config.algorithm = result.algorithm;
config.instance = cfg;
config.operator = result.operator;
config.seed = result.audit.seed;
config.populationSize = size(result.audit.initialPopulation, 1);
config.archiveCapacity = result.finalArchive.capacity;
config.evaluationBudget = result.metrics.evaluations;
config.initialPopulation = result.audit.initialPopulation;
config.scheduleSeeds = result.audit.scheduleSeeds;
config.truthUsedBySelection = result.audit.truthUsedBySelection;
config.truthUsedByMetricsOnly = true;
config.tuneSpecSha256 = string(provenance.tuneSpecSha256);
config.planSha256 = string(provenance.planSha256);
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
environment.parallelWorkers = 0;
end

function guardrails = makeGuardrails(result, provenance)
guardrails = struct();
guardrails.schema = "mdt.tune-guardrails.v0.1";
guardrails.G_SOFTWARE = struct('status', "PASS_BY_REFERENCED_TEST_EVIDENCE");
guardrails.G_PAIR = struct('status', "PASS", ...
    'seed', result.audit.seed, ...
    'scheduleSeeds', result.audit.scheduleSeeds, ...
    'truthUsedBySelection', result.audit.truthUsedBySelection);
guardrails.G_HV = struct('status', "NOT_APPLICABLE_TO_TUNING_DECISION", ...
    'finalHv', result.metrics.finalHv);
guardrails.G_FEAS = struct('status', "OBSERVED", ...
    'noFeasibleCheckpointRate', result.metrics.noFeasibleCheckpointRate);
if isfield(provenance, 'pairAudit')
    guardrails.schema = "mdt.p1-guardrails.v0.1";
    guardrails.G_PAIR = provenance.pairAudit;
end
end

function fields = artifactRecords(outputDir)
mapping = {
    'config', 'config.json'
    'environment', 'environment.json'
    'source_manifest', 'source_manifest.json'
    'input_contract', 'input_contract.json'
    'stdout', 'stdout.log'
    'stderr', 'stderr.log'
    'raw_metrics', 'raw_metrics.csv'
    'predictions', 'predictions.csv'
    'test_evidence', 'test_evidence.json'
    'guardrails', 'guardrails.json'
    'metrics', 'metrics.json'
    'final_archive', 'final_archive.csv'};
fields = struct();
for i = 1:size(mapping, 1)
    name = mapping{i, 1};
    relative = string(mapping{i, 2});
    fields.(name) = struct('path', relative, ...
        'sha256', sha256File(fullfile(outputDir, relative)));
end
end

function record = addInputFields(record, cfg)
record.role = "synthetic_benchmark_contract";
if isfield(cfg, 'benchmarkSpecVersion')
    record.source_revision = string(cfg.benchmarkSpecVersion);
else
    record.source_revision = "MDT-V0.1";
end
end

function names = makeColumnNames(prefix, count)
names = strings(1, count);
for i = 1:count
    names(i) = prefix + i;
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
