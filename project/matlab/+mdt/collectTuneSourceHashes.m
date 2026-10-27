function files = collectTuneSourceHashes(projectRoot)
%COLLECTTUNESOURCEHASHES Hash all code, tests and frozen TUNE-01 inputs.

arguments
    projectRoot (1,1) string
end
if ~isfolder(projectRoot)
    error('mdt:InvalidProjectRoot', 'projectRoot must exist.');
end

matlabFiles = dir(fullfile(projectRoot, 'matlab', '**', '*.m'));
testFiles = dir(fullfile(projectRoot, 'tests', '**', '*.m'));
absolute = strings(numel(matlabFiles)+numel(testFiles), 1);
index = 0;
for i = 1:numel(matlabFiles)
    index = index + 1;
    absolute(index) = fullfile(matlabFiles(i).folder, matlabFiles(i).name);
end
for i = 1:numel(testFiles)
    index = index + 1;
    absolute(index) = fullfile(testFiles(i).folder, testFiles(i).name);
end
contracts = [
    fullfile(projectRoot, 'docs', 'TUNE_01_SPEC.md')
    fullfile(projectRoot, 'docs', 'E2_METRIC_CONTRACT.md')
    fullfile(projectRoot, '.light', 'e2', 'PROJECT_PLAN.md')
    fullfile(projectRoot, '.light', 'e2', 'experiment_matrix.md')
    fullfile(projectRoot, '.light', 'e2', 'failure-tree.json')
    fullfile(projectRoot, '.light', 'e2', 'failure_tree_report.json')
    fullfile(projectRoot, '.light', 'e2', 'tune_authorization.json')];
absolute = [absolute; contracts];
if any(~arrayfun(@isfile, absolute))
    error('mdt:TuneSourceMissing', ...
        'A required TUNE-01 source or contract file is missing.');
end

relative = replace(extractAfter(absolute, strlength(projectRoot)+1), "\", "/");
[relative, order] = sort(relative);
absolute = absolute(order);
files = repmat(struct('path', "", 'sha256', ""), numel(relative), 1);
for i = 1:numel(relative)
    files(i).path = relative(i);
    files(i).sha256 = sha256File(absolute(i));
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
value = string(upper(reshape(dec2hex(bytes, 2).', 1, [])));
end
