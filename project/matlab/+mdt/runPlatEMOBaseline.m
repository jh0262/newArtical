function result = runPlatEMOBaseline(algorithm, benchmark, seed, N, budget, ...
    formalPerformanceRun)
%RUNPLATEMOBASELINE Run a hash-bound PlatEMO v4.15 comparator.

if nargin < 6
    formalPerformanceRun = false;
end
if ~islogical(formalPerformanceRun) || ~isscalar(formalPerformanceRun)
    error('mdt:InvalidRunRole', ...
        'formalPerformanceRun must be a scalar logical.');
end

algorithm = upper(string(algorithm));
if ~ismember(algorithm, ["NSGAII", "CCMO"])
    error('mdt:InvalidPlatEMOBaseline', ...
        'algorithm must be NSGAII or CCMO.');
end
required = {'evaluator', 'variableSpec', 'platemoEncoding', ...
    'objectiveCount', 'idealPoint', 'nadirPoint', 'id'};
if ~isstruct(benchmark) || ~isscalar(benchmark) || ...
        ~all(isfield(benchmark, required))
    error('mdt:InvalidPublicBenchmark', ...
        'benchmark lacks the fields required by the PlatEMO bridge.');
end
if ~isfinite(seed) || seed < 0 || seed ~= floor(seed)
    error('mdt:InvalidSeed', 'seed must be a nonnegative integer.');
end
if ~isfinite(N) || N < 4 || N ~= floor(N) || ...
        ~isfinite(budget) || budget < N || budget ~= floor(budget) || ...
        mod(budget, N) ~= 0
    error('mdt:InvalidEvaluationBudget', ...
        'N must be >=4 and budget must be an integer multiple of N.');
end
if algorithm == "CCMO" && budget < 2*N
    error('mdt:InvalidEvaluationBudget', ...
        'CCMO requires at least 2*N evaluations for its two populations.');
end

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
platemoRoot = fullfile(projectRoot, 'external', 'PlatEMO-v4.15', 'PlatEMO');
if ~isfolder(platemoRoot)
    error('mdt:PlatEMOSnapshotUnavailable', ...
        'The frozen PlatEMO v4.15 snapshot is required.');
end
if algorithm == "NSGAII"
    algorithmFolder = 'NSGA-II';
    algorithmFilename = 'NSGAII.m';
else
    algorithmFolder = 'CCMO';
    algorithmFilename = 'CCMO.m';
end
algorithmFile = fullfile(platemoRoot, 'Algorithms', ...
    'Multi-objective optimization', algorithmFolder, algorithmFilename);
if ~isfile(algorithmFile)
    error('mdt:PlatEMOSnapshotUnavailable', ...
        'The requested frozen PlatEMO algorithm file is unavailable.');
end

originalPath = path;
originalRng = rng;
cleanup = onCleanup(@() restorePlatEMOState(originalPath, originalRng));
addpath(genpath(platemoRoot));
rng(seed, 'twister');

Problem = MDTPlatEMOPublicProblem( ...
    'N', N, 'maxFE', budget, 'parameter', ...
    {benchmark.evaluator, benchmark.variableSpec, ...
    benchmark.platemoEncoding, benchmark.objectiveCount, ...
    benchmark.idealPoint, benchmark.nadirPoint});
traceRecorder = MDTPlatEMOTraceRecorder();
if algorithm == "NSGAII"
    Algorithm = NSGAII('save', 0, 'outputFcn', ...
        @(algorithmState, problemState) traceRecorder.capture( ...
        algorithmState, problemState));
else
    Algorithm = CCMO('parameter', {1}, 'save', 0, ...
        'outputFcn', @(algorithmState, problemState) ...
        traceRecorder.capture(algorithmState, problemState));
end
Algorithm.Solve(Problem);

actualCalls = Problem.FE;
initialPopulation = Algorithm.result{1, 2}.decs;
Population = Algorithm.result{end, 2};
finalX = Population.decs;
finalObj = Population.objs;
finalCon = Population.cons;
runtimeSeconds = Algorithm.metric.runtime;
trace = traceRecorder.rows;
clear Population Algorithm Problem
restorePlatEMOState(originalPath, originalRng);

spec = benchmark.variableSpec;
finalArchive = mdt.updateArchiveBlackBox([], finalX, finalObj, ...
    finalCon, max(N, 1), spec);
audit = struct();
audit.schema = "mdt.platemo-baseline-audit.v1.0";
audit.seed = seed;
audit.initialPopulation = initialPopulation;
audit.evaluatorCalls = actualCalls;
audit.hiddenEvaluatorCalls = actualCalls-budget;
audit.truthUsed = false;
audit.pathRestored = strcmp(path, originalPath);
audit.rngRestored = isequaln(rng, originalRng);
audit.sourceRelease = "PlatEMO-v4.15";
audit.sourceCommit = "d4daccc10fb2e2af12b844bbdeba1265392bc48e";
if algorithm == "NSGAII"
    audit.sourceAlgorithmSha256 = ...
        "7C11905B6A79E5F6E3CC7E906B3A61897DC9FFA6950E16A44514C48773CD00F0";
else
    audit.sourceAlgorithmSha256 = ...
        "B281515DE465EE82CAE34184CA531C733E309EB202D8991544ECD751ECBD77A1";
end
audit.typedEncoding = benchmark.platemoEncoding;
audit.formalPerformanceRun = formalPerformanceRun;

result = struct();
result.schema = "mdt.platemo-baseline-result.v1.0";
result.algorithm = algorithm;
result.benchmarkId = benchmark.id;
result.metrics = struct( ...
    'evaluations', actualCalls, ...
    'finalFeasibleRate', mean(all(finalCon <= 0, 2)), ...
    'finalArchiveSize', size(finalArchive.X, 1), ...
    'runtimeSeconds', runtimeSeconds);
result.trace = trace;
result.traceColumns = ["nfe", "feasibleRate"];
result.finalPopulation = struct('X', finalX, 'obj', finalObj, 'con', finalCon);
result.finalArchive = finalArchive;
result.audit = audit;
clear cleanup
end

function restorePlatEMOState(originalPath, originalRng)
path(originalPath);
rng(originalRng);
end
