function design = makeH13PublicComparisonDesign()
%MAKEH13PUBLICCOMPARISONDESIGN Return the authorized formal H13 design.

projectRoot = string(fileparts(fileparts(fileparts(mfilename('fullpath')))));
authorizationPath = fullfile(projectRoot, '.light', 'h13', ...
    'h13_authorization.json');
seedPath = fullfile(projectRoot, '.light', 'h13', ...
    'h13_seed_manifest.json');
amendmentPath = fullfile(projectRoot, '.light', 'h13', ...
    'budget_amendment_v1.md');
specPath = fullfile(projectRoot, '.light', 'h13', ...
    'H13_FORMAL_PUBLIC_COMPARISON_SPEC.md');
requiredPaths = [authorizationPath, seedPath, amendmentPath, specPath];
for path = requiredPaths
    if ~isfile(path)
        error('mdt:H13InputMissing', ...
            'Required H13 input is missing: %s', path);
    end
end

authorization = jsondecode(fileread(authorizationPath));
if string(authorization.status) ~= "AUTHORIZED"
    error('mdt:H13NotAuthorized', ...
        'The H13 formal batch is not authorized.');
end
seedManifest = jsondecode(fileread(seedPath));
seeds = double(seedManifest.seeds(:)');
if seedManifest.count ~= 30 || numel(seeds) ~= 30 || ...
        numel(unique(seeds)) ~= 30 || any(seeds < 0) || ...
        any(seeds ~= floor(seeds))
    error('mdt:H13InvalidSeeds', ...
        'H13 requires 30 unique nonnegative integer seeds.');
end

problems = struct( ...
    'id', {"RCM06", "RCM19", "RCM25"}, ...
    'nominalBudget', {20000, 26250, 20000}, ...
    'executionBudget', {20000, 26300, 20000}, ...
    'budgetPolicy', { ...
        "exact_generation_boundary", ...
        "first_generation_boundary_at_or_above_nominal", ...
        "exact_generation_boundary"});

design = struct();
design.schema = "mdt.h13-public-comparison-design.v1.0";
design.status = "AUTHORIZED_PRE_RESULT";
design.scope = "formal public comparison under frozen H12/H13 contracts";
design.matrixRows = ["FORM-H12-RCM06", "FORM-H12-RCM19", ...
    "FORM-H12-RCM25"];
design.algorithms = ["B1", "B5S", "N2", "NSGAII", "CCMO"];
design.seeds = seeds;
design.populationSize = 100;
design.archiveCapacity = 100;
design.problems = problems;
design.expectedRuns = numel(problems)*numel(design.algorithms)*numel(seeds);
design.expectedPairedSets = numel(problems)*numel(seeds);
design.tuningBudget = 0;
design.primaryMetric = "normalized_feasible_hv_final_population";
design.multiplicity = "Holm within each problem over four B5S comparisons";
design.authorizationPath = relativePath(projectRoot, authorizationPath);
design.authorizationSha256 = sha256File(authorizationPath);
design.seedManifestPath = relativePath(projectRoot, seedPath);
design.seedManifestSha256 = sha256File(seedPath);
design.budgetAmendmentPath = relativePath(projectRoot, amendmentPath);
design.budgetAmendmentSha256 = sha256File(amendmentPath);
design.specPath = relativePath(projectRoot, specPath);
design.specSha256 = sha256File(specPath);
end

function value = relativePath(projectRoot, path)
value = replace(extractAfter(string(path), strlength(projectRoot)+1), ...
    "\", "/");
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
