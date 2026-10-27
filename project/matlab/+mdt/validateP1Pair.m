function audit = validateP1Pair(b0, b1, instanceId)
%VALIDATEP1PAIR Enforce the frozen EXP-P1 paired-comparison guardrails.

arguments
    b0 (1,1) struct
    b1 (1,1) struct
    instanceId (1,1) string
end

sameSeed = b0.audit.seed == b1.audit.seed;
sameInitialPopulation = isequal(b0.audit.initialPopulation, ...
    b1.audit.initialPopulation);
sameScheduleSeeds = isequal(b0.audit.scheduleSeeds, b1.audit.scheduleSeeds);
sameEvaluationBudget = b0.metrics.evaluations == b1.metrics.evaluations;
samePopulationSize = size(b0.audit.initialPopulation, 1) == ...
    size(b1.audit.initialPopulation, 1);
sameArchiveCapacity = b0.finalArchive.capacity == b1.finalArchive.capacity;
truthIsolatedFromSelection = ~b0.audit.truthUsedBySelection && ...
    ~b1.audit.truthUsedBySelection;
algorithmIdentity = b0.algorithm == "B0" && b1.algorithm == "B1";

passed = sameSeed && sameInitialPopulation && sameScheduleSeeds && ...
    sameEvaluationBudget && samePopulationSize && sameArchiveCapacity && ...
    truthIsolatedFromSelection && algorithmIdentity;
if ~passed
    error('mdt:P1PairMismatch', ...
        'EXP-P1 pair %s failed one or more fairness guardrails.', instanceId);
end

audit = struct();
audit.schema = "mdt.p1-pair-audit.v0.1";
audit.status = "PASS";
audit.pairId = instanceId + "__seed-" + b0.audit.seed;
audit.instanceId = instanceId;
audit.seed = b0.audit.seed;
audit.sameSeed = sameSeed;
audit.sameInitialPopulation = sameInitialPopulation;
audit.sameScheduleSeeds = sameScheduleSeeds;
audit.sameEvaluationBudget = sameEvaluationBudget;
audit.samePopulationSize = samePopulationSize;
audit.sameArchiveCapacity = sameArchiveCapacity;
audit.truthIsolatedFromSelection = truthIsolatedFromSelection;
audit.algorithmIdentity = algorithmIdentity;
end
