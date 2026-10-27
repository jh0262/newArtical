function stats = computeH14Statistics(rows, bootstrapReplicates, randomSeed)
%COMPUTEH14STATISTICS Frozen landscape-level H14 H1-H4 analysis.

arguments
    rows table
    bootstrapReplicates (1,1) double {mustBeInteger,mustBePositive} = 20000
    randomSeed (1,1) double {mustBeInteger,mustBeNonnegative} = 2026083102
end

validateFormalResults(rows);

h1Effects = pairedLandscapeEffects(rows, 4096, "dispersed", ...
    "B5S", "B5R", 'fscaAuc');
h2Effects = pairedLandscapeEffects(rows, 4096, "dispersed", ...
    "B5S", "B1", 'fscaAuc');
lowQEffects = pairedLandscapeEffects(rows, 16, "dispersed", ...
    "B5S", "B5R", 'fscaAuc');
h3Effects = h1Effects-lowQEffects;
h1Hv = pairedLandscapeEffects(rows, 4096, "dispersed", ...
    "B5S", "B5R", 'normalizedFeasibleHv');
h2Hv = pairedLandscapeEffects(rows, 4096, "dispersed", ...
    "B5S", "B1", 'normalizedFeasibleHv');

effectCells = {h1Effects, h2Effects, h3Effects};
hvCells = {h1Hv, h2Hv, []};
hypotheses = ["H1", "H2", "H3"];
contrasts = ["Q4096-dispersed__B5S-minus-B5R", ...
    "Q4096-dispersed__B5S-minus-B1", ...
    "Q4096-minus-Q16-dispersed__B5S-minus-B5R"];
primaryCells = cell(1, 3);
rawP = zeros(1, 3);
for i = 1:3
    effects = effectCells{i};
    ci = bootstrapMeanCi(effects, bootstrapReplicates, ...
        randomSeed+100*i);
    rawP(i) = exactOneSidedSignFlip(effects-0.01);
    hvApplicable = ~isempty(hvCells{i});
    hvEstimate = NaN;
    hvCi = [NaN, NaN];
    hvPassed = true;
    if hvApplicable
        hvEstimate = mean(hvCells{i});
        hvCi = bootstrapMeanCi(hvCells{i}, bootstrapReplicates, ...
            randomSeed+1000+100*i);
        hvPassed = hvCi(1) >= -0.005;
    end
    item = struct();
    item.hypothesisId = hypotheses(i);
    item.contrastId = contrasts(i);
    item.nLandscapes = numel(effects);
    item.landscapeEffects = effects;
    item.estimate = mean(effects);
    item.bootstrapCi95 = ci;
    item.practicalThreshold = 0.01;
    item.rawExactP = rawP(i);
    item.holmAdjustedP = NaN;
    item.holmSignificant = false;
    item.hvGuardrailApplicable = hvApplicable;
    item.hvEstimate = hvEstimate;
    item.hvBootstrapCi95 = hvCi;
    item.hvGuardrailPassed = hvPassed;
    item.successConditionMet = false;
    item.failureConditionMet = false;
    item.branch = "inconclusive";
    primaryCells{i} = item;
end

adjusted = mdt.holmAdjust(rawP);
primary = [primaryCells{:}];
for i = 1:numel(primary)
    primary(i).holmAdjustedP = adjusted(i);
    primary(i).holmSignificant = adjusted(i) < 0.05;
    primary(i).successConditionMet = ...
        primary(i).bootstrapCi95(1) > 0.01 && ...
        primary(i).holmSignificant && primary(i).hvGuardrailPassed;
    coverageFailure = primary(i).bootstrapCi95(2) <= 0;
    qualityFailure = primary(i).hvGuardrailApplicable && ...
        primary(i).hvBootstrapCi95(1) < -0.005;
    primary(i).failureConditionMet = coverageFailure || qualityFailure;
    if primary(i).successConditionMet
        primary(i).branch = "success";
    elseif primary(i).failureConditionMet
        primary(i).branch = "failure";
    end
end

boundary = computeBoundary(rows, bootstrapReplicates, randomSeed+5000);

stats = struct();
stats.schema = "mdt.h14-statistics.v0.1";
stats.scope = "FROZEN_H14_CONFIRMATORY_ANALYSIS";
stats.independentUnit = "landscape instance";
stats.randomizationUnit = "paired algorithm seed nested within landscape";
stats.nLandscapes = 16;
stats.seedsPerLandscape = 10;
stats.componentsPerStateLevels = [1, 4];
stats.algorithmRuns = height(rows);
stats.primaryFamilySize = 3;
stats.primaryMetric = "feasible-state coverage AUC";
stats.estimator = "mean paired effect within landscape then mean across landscapes";
stats.ci = "two-sided percentile bootstrap resampling landscapes";
stats.test = "exact one-sided landscape sign-flip of effect minus 0.01";
stats.multiplicityCorrection = "Holm FWER 0.05 over H1-H3";
stats.bootstrapReplicates = bootstrapReplicates;
stats.randomSeed = randomSeed;
stats.primary = primary;
stats.boundary = boundary;
end

function validateFormalResults(rows)
required = {'runId','executionRow','Q','stateLayout', ...
    'componentsPerState','landscapeSeed','algorithmSeed','algorithm', ...
    'actualNfe','fscaAuc','finalFeasibleStateCoverage', ...
    'normalizedFeasibleHv','status','truthUsedByAlgorithm', ...
    'formalPerformanceRun'};
if ~all(ismember(required, rows.Properties.VariableNames))
    error('mdt:InvalidH14Results', ...
        'H14 results are missing required analysis columns.');
end
numericColumns = {'Q','componentsPerState','landscapeSeed', ...
    'algorithmSeed','actualNfe','fscaAuc', ...
    'finalFeasibleStateCoverage','normalizedFeasibleHv'};
for i = 1:numel(numericColumns)
    if any(~isfinite(rows.(numericColumns{i})))
        error('mdt:InvalidH14Results', ...
            'H14 numeric analysis columns must be finite.');
    end
end
if any(rows.fscaAuc < 0 | rows.fscaAuc > 1) || ...
        any(rows.finalFeasibleStateCoverage < 0 | ...
        rows.finalFeasibleStateCoverage > 1) || ...
        any(rows.normalizedFeasibleHv < 0 | rows.normalizedFeasibleHv > 1)
    error('mdt:InvalidH14Results', ...
        'H14 normalized metrics must lie in [0,1].');
end
if any(string(rows.status) ~= "completed") || ...
        any(rows.actualNfe ~= 10000) || ...
        any(logical(rows.truthUsedByAlgorithm)) || ...
        any(~logical(rows.formalPerformanceRun))
    error('mdt:H14ProtocolViolation', ...
        'H14 analysis requires completed, truth-safe formal 10000-NFE runs.');
end
expected = mdt.makeH14RunMatrix(mdt.makeH14Design());
actualIds = sort(string(rows.runId));
expectedIds = sort(string(expected.runId));
if height(rows) ~= height(expected) || ...
        numel(unique(actualIds)) ~= height(expected) || ...
        ~isequal(actualIds, expectedIds)
    error('mdt:InvalidH14ResultCoverage', ...
        'H14 analysis requires the complete frozen 6720-run matrix.');
end
end

function effects = pairedLandscapeEffects(rows, q, layout, ...
    candidateAlgorithm, baselineAlgorithm, metric)
subset = rows(rows.Q == q & string(rows.stateLayout) == layout, :);
landscapes = sort(unique(subset.landscapeSeed));
if numel(landscapes) ~= 16
    error('mdt:InvalidH14ResultCoverage', ...
        'Each H14 contrast requires 16 landscapes.');
end
effects = zeros(numel(landscapes), 1);
for i = 1:numel(landscapes)
    landscape = subset(subset.landscapeSeed == landscapes(i), :);
    candidate = landscape(string(landscape.algorithm) == ...
        candidateAlgorithm, :);
    baseline = landscape(string(landscape.algorithm) == ...
        baselineAlgorithm, :);
    candidate = sortrows(candidate, ...
        {'componentsPerState','algorithmSeed'});
    baseline = sortrows(baseline, ...
        {'componentsPerState','algorithmSeed'});
    if height(candidate) ~= 20 || height(baseline) ~= 20 || ...
            ~isequal(candidate.componentsPerState, ...
            baseline.componentsPerState) || ...
            ~isequal(candidate.algorithmSeed, baseline.algorithmSeed)
        error('mdt:InvalidH14ResultCoverage', ...
            'H14 landscape pairing is incomplete or misaligned.');
    end
    effects(i) = mean(candidate.(metric)-baseline.(metric));
end
end

function boundary = computeBoundary(rows, bootstrapReplicates, seed)
baselines = ["B5R", "B1"];
cells = cell(1, numel(baselines));
for i = 1:numel(baselines)
    effects = pairedLandscapeEffects(rows, 2, "boundary", ...
        "B5S", baselines(i), 'normalizedFeasibleHv');
    item = struct();
    item.comparisonId = "Q2-boundary__B5S-minus-"+baselines(i);
    item.baseline = baselines(i);
    item.nLandscapes = numel(effects);
    item.landscapeEffects = effects;
    item.estimate = mean(effects);
    item.bootstrapCi95 = bootstrapMeanCi(effects, ...
        bootstrapReplicates, seed+100*i);
    item.guardrail = -0.005;
    cells{i} = item;
end
comparisons = [cells{:}];
lower = arrayfun(@(x) x.bootstrapCi95(1), comparisons);
upper = arrayfun(@(x) x.bootstrapCi95(2), comparisons);
success = all(lower >= -0.005);
failure = any(upper < -0.005);
branch = "inconclusive";
if success
    branch = "success";
elseif failure
    branch = "failure";
end
boundary = struct();
boundary.hypothesisId = "H4";
boundary.role = "secondary harm-detection boundary";
boundary.comparisons = comparisons;
boundary.successConditionMet = success;
boundary.failureConditionMet = failure;
boundary.branch = branch;
boundary.equivalenceClaimAllowed = false;
end

function ci = bootstrapMeanCi(effects, count, seed)
stream = RandStream('mt19937ar', 'Seed', seed);
n = numel(effects);
values = zeros(count, 1);
for replicate = 1:count
    sample = effects(randi(stream, n, n, 1));
    values(replicate) = mean(sample);
end
ci = [empiricalQuantile(values, 0.025), ...
    empiricalQuantile(values, 0.975)];
end

function p = exactOneSidedSignFlip(centeredEffects)
n = numel(centeredEffects);
if n > 20
    error('mdt:H14ExactTestTooLarge', ...
        'Exact sign-flip enumeration is limited to 20 landscapes.');
end
observed = mean(centeredEffects);
tolerance = 32*eps(max(1, abs(observed)));
exceed = 0;
total = 2^n;
for pattern = 0:(total-1)
    signs = 2*double(bitget(uint32(pattern), 1:n))'-1;
    statistic = mean(centeredEffects.*signs);
    exceed = exceed+(statistic >= observed-tolerance);
end
p = exceed/total;
end

function value = empiricalQuantile(values, probability)
values = sort(values(:));
position = 1+(numel(values)-1)*probability;
lower = floor(position);
upper = ceil(position);
if lower == upper
    value = values(lower);
else
    weight = position-lower;
    value = (1-weight)*values(lower)+weight*values(upper);
end
end
