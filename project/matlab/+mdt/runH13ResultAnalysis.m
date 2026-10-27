function summary = runH13ResultAnalysis(resultsCsv, outputDir, ...
    bootstrapReplicates, permutationReplicates, randomSeed)
%RUNH13RESULTANALYSIS Compute and freeze the H13 confirmatory statistics.

arguments
    resultsCsv (1,1) string
    outputDir (1,1) string
    bootstrapReplicates (1,1) double {mustBeInteger,mustBePositive} = 20000
    permutationReplicates (1,1) double {mustBeInteger,mustBePositive} = 50000
    randomSeed (1,1) double {mustBeInteger,mustBeNonnegative} = 2026083101
end
if ~isfile(resultsCsv)
    error('mdt:H13AnalysisInputMissing', ...
        'H13 result table does not exist: %s', resultsCsv);
end
if isfolder(outputDir) || isfile(outputDir)
    error('mdt:H13AnalysisOutputCollision', ...
        'Refusing to overwrite an existing H13 analysis bundle.');
end

rows = readtable(resultsCsv, 'TextType', 'string');
stats = mdt.computeH13Statistics(rows, bootstrapReplicates, ...
    permutationReplicates, randomSeed);
mkdir(outputDir);
statisticsPath = fullfile(outputDir, 'h13_statistics.json');
comparisonsPath = fullfile(outputDir, 'h13_comparisons.csv');
algorithmsPath = fullfile(outputDir, 'h13_algorithm_summaries.csv');
writeJsonAtomic(statisticsPath, stats);
writetable(flattenComparisons(stats), comparisonsPath);
writetable(flattenAlgorithms(stats), algorithmsPath);

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
batchManifest = fullfile(fileparts(resultsCsv), 'batch_manifest.json');
manifest = struct();
manifest.schema = "mdt.h13-analysis-manifest.v1.0";
manifest.status = "COMPLETE";
manifest.scope = stats.scope;
manifest.computedAt = localNow();
manifest.inputResults = replace(string(resultsCsv), "\", "/");
manifest.inputResultsSha256 = sha256File(resultsCsv);
manifest.batchManifest = "UNAVAILABLE";
manifest.batchManifestSha256 = "UNAVAILABLE";
if isfile(batchManifest)
    manifest.batchManifest = replace(string(batchManifest), "\", "/");
    manifest.batchManifestSha256 = sha256File(batchManifest);
end
manifest.analysisCode = "matlab/+mdt/computeH13Statistics.m";
manifest.analysisCodeSha256 = sha256File(fullfile(projectRoot, ...
    'matlab', '+mdt', 'computeH13Statistics.m'));
manifest.writerCode = "matlab/+mdt/runH13ResultAnalysis.m";
manifest.writerCodeSha256 = sha256File(fullfile(projectRoot, ...
    'matlab', '+mdt', 'runH13ResultAnalysis.m'));
manifest.specSha256 = sha256File(fullfile(projectRoot, '.light', ...
    'h13', 'H13_FORMAL_PUBLIC_COMPARISON_SPEC.md'));
manifest.failureTreeSha256 = sha256File(fullfile(projectRoot, '.light', ...
    'h13', 'failure-tree.json'));
manifest.parameters = struct('bootstrapReplicates', bootstrapReplicates, ...
    'permutationReplicates', permutationReplicates, ...
    'randomSeed', randomSeed, 'alpha', 0.05, ...
    'multiplicity', "Holm within problem");
manifest.artifacts = [artifactEntry(statisticsPath), ...
    artifactEntry(comparisonsPath), artifactEntry(algorithmsPath)];
writeJsonAtomic(fullfile(outputDir, 'analysis_manifest.json'), manifest);

summary = struct('schema', "mdt.h13-analysis-summary.v1.0", ...
    'status', "COMPLETE", 'outputDir', outputDir, ...
    'comparisons', height(flattenComparisons(stats)), ...
    'problemBranches', string({stats.problems.branch}));
end

function rows = flattenComparisons(stats)
items = cell(1, 12);
cursor = 0;
for problem = stats.problems
    for comparison = problem.comparisons
        cursor = cursor+1;
        item = struct();
        item.hypothesisId = problem.hypothesisId;
        item.problemId = problem.problemId;
        item.familyId = problem.familyId;
        item.branch = problem.branch;
        item.comparisonId = comparison.comparisonId;
        item.baseline = comparison.baseline;
        item.nPairs = comparison.nPairs;
        item.hodgesLehmann = comparison.hodgesLehmann;
        item.ciLower = comparison.bootstrapCi95(1);
        item.ciUpper = comparison.bootstrapCi95(2);
        item.rawPermutationP = comparison.rawPermutationP;
        item.holmAdjustedP = comparison.holmAdjustedP;
        item.holmSignificant = comparison.holmSignificant;
        item.meanDifference = comparison.meanDifference;
        item.medianDifference = comparison.medianDifference;
        item.iqrDifference = comparison.iqrDifference;
        item.minimumDifference = comparison.minimumDifference;
        item.maximumDifference = comparison.maximumDifference;
        item.positivePairs = comparison.positivePairs;
        item.negativePairs = comparison.negativePairs;
        item.zeroPairs = comparison.zeroPairs;
        item.hlFeasibleRate = ...
            comparison.secondary.hodgesLehmannFeasibleRate;
        item.hlFeasibleNdSize = ...
            comparison.secondary.hodgesLehmannFeasibleNdSize;
        item.hlMeanNormalizedCv = ...
            comparison.secondary.hodgesLehmannMeanNormalizedCv;
        item.hlRuntimeSeconds = ...
            comparison.secondary.hodgesLehmannRuntimeSeconds;
        item.hlFirstFeasibleNfe = ...
            comparison.secondary.hodgesLehmannFirstFeasibleNfe;
        items{cursor} = item;
    end
end
rows = struct2table([items{:}]);
end

function rows = flattenAlgorithms(stats)
items = cell(1, 15);
cursor = 0;
for problem = stats.problems
    for algorithm = problem.algorithmSummaries
        cursor = cursor+1;
        item = algorithm;
        item.problemId = problem.problemId;
        item.branch = problem.branch;
        items{cursor} = item;
    end
end
rows = struct2table([items{:}]);
rows = movevars(rows, {'problemId','algorithm','branch'}, 'Before', 1);
end

function entry = artifactEntry(path)
entry = struct('path', string(extractAfter(path, ...
    strlength(string(fileparts(path)))+1)), ...
    'sha256', sha256File(path));
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
