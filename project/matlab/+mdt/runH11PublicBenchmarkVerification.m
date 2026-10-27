function summary = runH11PublicBenchmarkVerification()
%RUNH11PUBLICBENCHMARKVERIFICATION Verify the first H11 public adapter.

benchmark = mdt.makeRWMOP6Benchmark();
X = [
    3.0, 0.75, 8.0, 8.0, 3.5, 5.25, 3
    2.6, 0.70, 7.3, 7.3, 2.9, 5.00, 0
    3.6, 0.80, 8.3, 8.3, 3.9, 5.50, 11];
[adapterObj, adapterCon] = benchmark.evaluator(X);

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
officialDir = fullfile(projectRoot, 'external', '2021-RW-MOP', ...
    'PlatEMO_snapshot', 'RWMOPs');
officialEvaluator = fullfile(officialDir, 'CEC2021_func.m');
if ~isfile(officialEvaluator)
    error('mdt:H11OfficialSnapshotUnavailable', ...
        'The hash-bound official RWMOP snapshot is required for H11 verification.');
end

pathCleanup = onCleanup(@() rmpath(officialDir));
addpath(officialDir);
externalX = [X(:, 1:2), X(:, 7)+17, X(:, 3:6)];
[officialObj, officialCon, officialEq] = CEC2021_func(externalX, 6);
clear pathCleanup

feasibleSentinel = [3.5, 0.7, 8.3, 8.3, 3.9, 5.5, 11];
[sentinelObj, sentinelCon] = benchmark.evaluator(feasibleSentinel);

equivalence = struct();
equivalence.maxAbsObjectiveError = max(abs(adapterObj-officialObj), [], 'all');
equivalence.maxAbsConstraintError = max(abs(adapterCon-officialCon), [], 'all');
equivalence.officialEqualityColumnCount = size(officialEq, 2);
equivalence.objectivesMatch = equivalence.maxAbsObjectiveError <= 1e-10;
equivalence.constraintsMatch = equivalence.maxAbsConstraintError <= 1e-10;
equivalence.noEqualityConstraints = isempty(officialEq);
equivalence.allPassed = equivalence.objectivesMatch && ...
    equivalence.constraintsMatch && equivalence.noEqualityConstraints;

op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10);
runA = mdt.runB5SparseBlackBox(benchmark.evaluator, ...
    benchmark.variableSpec, op, 11006, 12, 36, 24);
runB = mdt.runB5SparseBlackBox(benchmark.evaluator, ...
    benchmark.variableSpec, op, 11006, 12, 36, 24);

determinism = struct();
determinism.sameFinalPopulation = isequaln( ...
    runA.finalPopulation, runB.finalPopulation);
determinism.sameFinalArchive = isequaln(runA.finalArchive, runB.finalArchive);
determinism.sameTrace = isequaln(runA.trace, runB.trace);
determinism.sameAudit = isequaln(runA.audit, runB.audit);
determinism.allPassed = all(structfun(@(value) logical(value), determinism));

smoke = struct();
smoke.seed = runA.audit.seed;
smoke.populationSize = 12;
smoke.evaluationBudget = 36;
smoke.evaluatorCalls = runA.audit.evaluatorCalls;
smoke.truthUsed = runA.audit.truthUsed;
smoke.discreteStateCount = runA.audit.discreteStateCount;
smoke.visitedDiscreteStates = runA.audit.visitLedgerStoredStateCount;
smoke.finalFeasibleRate = runA.metrics.finalFeasibleRate;
smoke.finalArchiveSize = runA.metrics.finalArchiveSize;
smoke.feasibleSentinelObjectives = sentinelObj;
smoke.feasibleSentinelMaxConstraint = max(sentinelCon, [], 'all');
smoke.feasibleSentinelPassed = all(sentinelCon <= 1e-12, 'all');
smoke.contractPassed = smoke.evaluatorCalls == smoke.evaluationBudget && ...
    ~smoke.truthUsed && smoke.discreteStateCount == 12 && ...
    smoke.feasibleSentinelPassed;

summary = struct();
summary.schema = "mdt.h11-public-benchmark-verification.v1.0";
summary.scope = ...
    "adapter equivalence and truth-free smoke only; no algorithm comparison";
summary.benchmark = rmfield(benchmark, 'evaluator');
summary.matlabVersion = string(version);
summary.computer = string(computer);
summary.equivalence = equivalence;
summary.determinism = determinism;
summary.smoke = smoke;
summary.allPassed = equivalence.allPassed && determinism.allPassed && ...
    smoke.contractPassed;
end
