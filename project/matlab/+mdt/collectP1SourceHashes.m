function files = collectP1SourceHashes(projectRoot)
%COLLECTP1SOURCEHASHES Hash every frozen input and MATLAB source used by P1.

arguments
    projectRoot (1,1) string
end

relativeFiles = [
    ".light/e2/PROJECT_PLAN.md"
    ".light/e2/experiment_execution_contract.json"
    ".light/e2/p1_seed_matrix.json"
    ".light/e2/frozen_tune_config.json"
    ".light/e2/failure-tree.json"
    ".light/e2/failure_tree_report.json"
    ".light/e2/p1_authorization.json"
    "docs/E2_METRIC_CONTRACT.md"];
matlabFiles = dir(fullfile(projectRoot, 'matlab', '+mdt', '**', '*.m'));
testFiles = dir(fullfile(projectRoot, 'tests', '*.m'));
for item = [matlabFiles; testFiles]'
    absolute = string(fullfile(item.folder, item.name));
    relativeFiles(end+1, 1) = replace(extractAfter(absolute, ...
        strlength(projectRoot)+1), "\", "/"); %#ok<AGROW>
end
relativeFiles = sort(unique(relativeFiles));
files = repmat(struct('path', "", 'sha256', ""), numel(relativeFiles), 1);
for i = 1:numel(relativeFiles)
    absolute = fullfile(projectRoot, relativeFiles(i));
    if ~isfile(absolute)
        error('mdt:P1SourceMissing', ...
            'Frozen P1 source is missing: %s', relativeFiles(i));
    end
    files(i).path = relativeFiles(i);
    files(i).sha256 = sha256File(absolute);
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
