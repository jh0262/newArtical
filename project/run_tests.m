projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'matlab'));
results = runtests(fullfile(projectRoot, 'tests'), 'IncludeSubfolders', true);
disp(results);
assertSuccess(results);

