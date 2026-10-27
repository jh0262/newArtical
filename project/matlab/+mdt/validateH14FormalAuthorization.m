function decision = validateH14FormalAuthorization(projectRoot, ...
    authorizationPath)
%VALIDATEH14FORMALAUTHORIZATION Verify the hash-bound H14 authorization.

arguments
    projectRoot (1,1) string
    authorizationPath (1,1) string = fullfile(projectRoot, ...
        '.light', 'h14', 'h14_formal_authorization.json')
end
if ~isfolder(projectRoot)
    error('mdt:H14AuthorizationRootMissing', ...
        'The H14 authorization project root does not exist.');
end
if ~isfile(authorizationPath)
    error('mdt:H14FormalAuthorizationMissing', ...
        'The hash-bound H14 formal authorization is missing.');
end
authorization = jsondecode(fileread(authorizationPath));
required = {'schema', 'status', 'budget_approved', ...
    'execution_start_authorized', 'bindings'};
if ~all(isfield(authorization, required)) || ...
        ~logical(authorization.budget_approved)
    error('mdt:H14AuthorizationMalformed', ...
        'The H14 formal authorization is malformed or unapproved.');
end
allowedStatus = ["BUDGET_APPROVED_FORMAL_PREPARED", ...
    "AUTHORIZED_FORMAL_START"];
status = string(authorization.status);
if ~ismember(status, allowedStatus)
    error('mdt:H14AuthorizationMalformed', ...
        'The H14 formal authorization status is not recognized.');
end
bindings = authorization.bindings;
if isempty(bindings) || ~all(isfield(bindings, {'path', 'sha256'}))
    error('mdt:H14AuthorizationMalformed', ...
        'The H14 formal authorization has no valid hash bindings.');
end
paths = strings(numel(bindings), 1);
for i = 1:numel(bindings)
    relative = replace(string(bindings(i).path), "\", "/");
    if startsWith(relative, "/") || contains(relative, "../") || ...
            contains(relative, ":")
        error('mdt:H14AuthorizationUnsafePath', ...
            'Authorization binding paths must be project-relative.');
    end
    absolute = fullfile(projectRoot, relative);
    if ~isfile(absolute) || ...
            sha256File(absolute) ~= lower(string(bindings(i).sha256))
        error('mdt:H14AuthorizationHashMismatch', ...
            'Authorization binding mismatch: %s', relative);
    end
    paths(i) = relative;
end
requiredBindings = [ ...
    ".light/h14/h14_budget_approval.json"
    ".light/h14/h14_formal_resource_budget_v0_1.json"
    ".light/h14/h14_formal_run_matrix.csv"
    "releases/H14-Analysis-v0.2.0-rc1/H14-Analysis-v0.2.0-rc1-source-and-evidence.zip"
    "matlab/+mdt/makeH14Design.m"
    "matlab/+mdt/runH14ControlledBatch.m"
    "matlab/+mdt/computeH14Statistics.m"
    "matlab/+mdt/runH14ResultAnalysis.m"
    "matlab/+mdt/evaluateH14ExecutionGuard.m"
    "matlab/+mdt/validateH14FormalAuthorization.m"];
if ~all(ismember(requiredBindings, paths))
    error('mdt:H14AuthorizationBindingMissing', ...
        'The H14 formal authorization omits required frozen inputs.');
end
budgetPath = fullfile(projectRoot, '.light', 'h14', ...
    'h14_formal_resource_budget_v0_1.json');
budget = jsondecode(fileread(budgetPath));
limits = struct('hardWallSeconds', ...
    double(budget.planning_envelope.hard_wall_hours)*3600, ...
    'hardOutputBytes', ...
    double(budget.planning_envelope.hard_output_gib)*1024^3, ...
    'minimumFreeBytes', 5*1024^3, ...
    'stallMinutes', 30, 'maxConsecutiveFailures', 3, ...
    'maxFailureFraction', 0.005);
startAuthorized = logical(authorization.execution_start_authorized) && ...
    status == "AUTHORIZED_FORMAL_START";
decision = struct('schema', "mdt.h14-authorization-decision.v0.1", ...
    'integrityValid', true, 'budgetApproved', true, ...
    'startAuthorized', startAuthorized, 'status', status, ...
    'verifiedBindings', numel(bindings), ...
    'authorizationPath', authorizationPath, 'limits', limits);
end

function value = sha256File(path)
fileId = fopen(path, 'r');
if fileId < 0
    error('mdt:HashReadFailure', 'Unable to hash file: %s', path);
end
cleanup = onCleanup(@() fclose(fileId));
data = fread(fileId, Inf, '*uint8');
digest = javaMethod('getInstance', ...
    'java.security.MessageDigest', 'SHA-256');
if ~isempty(data)
    digest.update(typecast(data, 'int8'));
end
bytes = typecast(digest.digest(), 'uint8');
value = string(lower(reshape(dec2hex(bytes, 2).', 1, [])));
end
