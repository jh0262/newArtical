function audit = validateE3Pair(b2, b3, instanceId)
%VALIDATEE3PAIR Verify fairness and the explicit oracle-information boundary.

arguments
    b2 (1,1) struct
    b3 (1,1) struct
    instanceId (1,1) string
end

sameSeed = b2.audit.seed == b3.audit.seed;
sameInitialPopulation = isequal(b2.audit.initialPopulation, ...
    b3.audit.initialPopulation);
sameScheduleSeeds = isequal(b2.audit.scheduleSeeds, b3.audit.scheduleSeeds);
sameEvaluationBudget = b2.metrics.evaluations == b3.metrics.evaluations;
samePopulationSize = size(b2.audit.initialPopulation, 1) == ...
    size(b3.audit.initialPopulation, 1);
sameArchiveCapacity = b2.finalArchive.capacity == b3.finalArchive.capacity;
algorithmIdentity = b2.algorithm == "B2" && b3.algorithm == "B3";
oracleBoundaryCorrect = ~b2.audit.truthUsedBySelection && ...
    b3.audit.truthUsedBySelection;
passed = sameSeed && sameInitialPopulation && sameScheduleSeeds && ...
    sameEvaluationBudget && samePopulationSize && sameArchiveCapacity && ...
    algorithmIdentity && oracleBoundaryCorrect;
if ~passed
    error('mdt:E3PairMismatch', ...
        'E3 diagnostic pair %s failed a fairness/oracle boundary.', instanceId);
end

audit = struct();
audit.schema = "mdt.e3-pair-audit.v0.1";
audit.status = "PASS";
audit.pairId = instanceId + "__seed-" + b2.audit.seed;
audit.instanceId = instanceId;
audit.seed = b2.audit.seed;
audit.sameSeed = sameSeed;
audit.sameInitialPopulation = sameInitialPopulation;
audit.sameScheduleSeeds = sameScheduleSeeds;
audit.sameEvaluationBudget = sameEvaluationBudget;
audit.samePopulationSize = samePopulationSize;
audit.sameArchiveCapacity = sameArchiveCapacity;
audit.algorithmIdentity = algorithmIdentity;
audit.oracleBoundaryCorrect = oracleBoundaryCorrect;
audit.b2TruthUsedBySelection = b2.audit.truthUsedBySelection;
audit.b3TruthUsedBySelection = b3.audit.truthUsedBySelection;
end
