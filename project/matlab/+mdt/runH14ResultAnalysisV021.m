function summary = runH14ResultAnalysisV021(resultsFile, outputDir, ...
    bootstrapReplicates, randomSeed)
%RUNH14RESULTANALYSISV021 Run H14 analysis with validator correction DEV-H14-ANALYSIS-001.

arguments
    resultsFile (1,1) string
    outputDir (1,1) string
    bootstrapReplicates (1,1) double {mustBeInteger,mustBePositive} = 20000
    randomSeed (1,1) double {mustBeInteger,mustBeNonnegative} = 2026083102
end
if ~isfile(resultsFile)
    error('mdt:H14ResultsFileMissing', ...
        'H14 results CSV does not exist.');
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:H14AnalysisOutputCollision', ...
        'Refusing to overwrite an existing H14 analysis path.');
end

rows = readtable(resultsFile, 'TextType', 'string');
stats = mdt.computeH14StatisticsV021(rows, bootstrapReplicates, randomSeed);
mkdir(outputDir);
statisticsPath = fullfile(outputDir, 'h14_statistics.json');
primaryPath = fullfile(outputDir, 'h14_primary_contrasts.csv');
boundaryPath = fullfile(outputDir, 'h14_boundary_contrasts.csv');
writeJsonAtomic(statisticsPath, stats);
writetable(primaryTable(stats.primary), primaryPath);
writetable(boundaryTable(stats.boundary.comparisons), boundaryPath);

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
sourcePaths = [
    "matlab/+mdt/computeH14StatisticsV021.m"
    "matlab/+mdt/runH14ResultAnalysisV021.m"
    ".light/h14/PROJECT_PLAN.md"
    ".light/h14/failure-tree.json"
    ".light/h14/preregistration.md"
    ".light/h14/deviations.md"];
sources = repmat(struct('path', "", 'sha256', ""), ...
    numel(sourcePaths), 1);
for i = 1:numel(sourcePaths)
    sources(i).path = sourcePaths(i);
    sources(i).sha256 = sha256File(fullfile(projectRoot, sourcePaths(i)));
end
artifacts = [
    artifactRecord(outputDir, 'h14_statistics.json')
    artifactRecord(outputDir, 'h14_primary_contrasts.csv')
    artifactRecord(outputDir, 'h14_boundary_contrasts.csv')];
manifest = struct('schema', "mdt.h14-analysis-manifest.v0.2.1", ...
    'status', "completed", 'createdAt', localNow(), ...
    'input', struct('path', resultsFile, ...
    'sha256', sha256File(resultsFile), 'rows', height(rows)), ...
    'bootstrapReplicates', bootstrapReplicates, ...
    'deviationId', "DEV-H14-ANALYSIS-001", ...
    'randomSeed', randomSeed, 'sources', sources, ...
    'artifacts', artifacts, ...
    'completion', struct('status', "PASS", ...
    'oracles', ["complete frozen 6720-run coverage", ...
    "truth firewall and formal-run flags pass", ...
    "H1-H4 branch classification completed"]), ...
    'claimBoundary', ...
    "Post-results validator correction disclosed; output does not by itself authorize publication claims.");
writeJsonAtomic(fullfile(outputDir, 'analysis_manifest.json'), manifest);

summary = struct('schema', "mdt.h14-analysis-summary.v0.2.1", ...
    'status', "COMPLETE_SYNTHETIC_OR_FORMAL_INPUT", ...
    'outputDir', outputDir, 'inputRows', height(rows), ...
    'primaryBranches', string({stats.primary.branch}), ...
    'boundaryBranch', stats.boundary.branch);
end

function value = primaryTable(primary)
n = numel(primary);
value = table('Size', [n, 14], 'VariableTypes', ...
    {'string','string','double','double','double','double','double', ...
    'logical','double','double','double','logical','string','double'}, ...
    'VariableNames', {'hypothesisId','contrastId','estimate','ciLower', ...
    'ciUpper','rawExactP','holmAdjustedP','holmSignificant', ...
    'hvEstimate','hvCiLower','hvCiUpper','hvGuardrailPassed', ...
    'branch','nLandscapes'});
for i = 1:n
    value.hypothesisId(i) = primary(i).hypothesisId;
    value.contrastId(i) = primary(i).contrastId;
    value.estimate(i) = primary(i).estimate;
    value.ciLower(i) = primary(i).bootstrapCi95(1);
    value.ciUpper(i) = primary(i).bootstrapCi95(2);
    value.rawExactP(i) = primary(i).rawExactP;
    value.holmAdjustedP(i) = primary(i).holmAdjustedP;
    value.holmSignificant(i) = primary(i).holmSignificant;
    value.hvEstimate(i) = primary(i).hvEstimate;
    value.hvCiLower(i) = primary(i).hvBootstrapCi95(1);
    value.hvCiUpper(i) = primary(i).hvBootstrapCi95(2);
    value.hvGuardrailPassed(i) = primary(i).hvGuardrailPassed;
    value.branch(i) = primary(i).branch;
    value.nLandscapes(i) = primary(i).nLandscapes;
end
end

function value = boundaryTable(comparisons)
n = numel(comparisons);
value = table('Size', [n, 7], 'VariableTypes', ...
    {'string','string','double','double','double','double','double'}, ...
    'VariableNames', {'comparisonId','baseline','estimate','ciLower', ...
    'ciUpper','guardrail','nLandscapes'});
for i = 1:n
    value.comparisonId(i) = comparisons(i).comparisonId;
    value.baseline(i) = comparisons(i).baseline;
    value.estimate(i) = comparisons(i).estimate;
    value.ciLower(i) = comparisons(i).bootstrapCi95(1);
    value.ciUpper(i) = comparisons(i).bootstrapCi95(2);
    value.guardrail(i) = comparisons(i).guardrail;
    value.nLandscapes(i) = comparisons(i).nLandscapes;
end
end

function record = artifactRecord(outputDir, relativePath)
record = struct('path', string(relativePath), ...
    'sha256', sha256File(fullfile(outputDir, relativePath)));
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

