function cfg = makeInstance(family, q, L, rho, lambda, labelPermutation)
%MAKEINSTANCE Create a validated MDT benchmark configuration.

arguments
    family (1,1) string
    q (1,1) double
    L (1,1) double
    rho (1,1) double
    lambda (1,1) double
    labelPermutation double = []
end

family = upper(family);
if ~ismember(family, ["C", "D", "IR", "WM", "DM2"])
    error('mdt:InvalidFamily', ...
        'family must be C, D, IR, WM, or DM2.');
end
if ~isfinite(q) || q < 2 || q ~= floor(q)
    error('mdt:InvalidLevelCount', 'q must be an integer greater than or equal to 2.');
end
if ~isfinite(L) || L < 3 || L ~= floor(L)
    error('mdt:InvalidDiscreteDimension', 'L must be an integer greater than or equal to 3.');
end
if ~isfinite(rho) || rho <= 0 || rho > 0.5
    error('mdt:InvalidRho', 'rho must satisfy 0 < rho <= 0.5.');
end
if ~isfinite(lambda) || lambda <= 0
    error('mdt:InvalidLambda', 'lambda must be finite and positive.');
end
if ismember(family, ["WM", "DM2"]) && ~isprime(q)
    error('mdt:StressFamilyRequiresPrimeQ', ...
        'WM and DM2 require a prime q in the frozen H6 design.');
end

if isempty(labelPermutation)
    labelPermutation = 0:(q-1);
else
    labelPermutation = reshape(labelPermutation, 1, []);
    if numel(labelPermutation) ~= q || ~isequal(sort(labelPermutation), 0:(q-1))
        error('mdt:InvalidLabelPermutation', ...
            'labelPermutation must contain every integer from 0 to q-1 exactly once.');
    end
end

types = strings(1, L);
types(1) = "integer";
types(2) = "ordinal";
types(3:end) = "categorical";

cfg = struct();
cfg.schema = "mdt.instance.v0.1";
cfg.family = family;
cfg.q = q;
cfg.L = L;
cfg.rho = rho;
cfg.lambda = lambda;
cfg.Q = q^L;
cfg.types = types;
cfg.labelPermutation = labelPermutation;
cfg.categoryAdjacency = ones(q) - eye(q);
cfg.delta = 0.25;
if ismember(family, ["WM", "DM2"])
    cfg.benchmarkSpecVersion = "MDT-H6-STRESS-V0.2";
    cfg.frozenSpecSha256 = ...
        "FAF5C3A99541FF0034975C43FD09FD7ACC4132D11C942DCB75C1DF11DFC7DCB7";
else
    cfg.benchmarkSpecVersion = "MDT-V0.1";
    cfg.frozenSpecSha256 = ...
        "DF59733AD68E2D8EF0E6037D5400CD2B1D906779D9B5F5EF62C603FF5BBBABAF";
end
end
