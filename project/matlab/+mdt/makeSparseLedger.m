function ledger = makeSparseLedger(stateCount)
%MAKESPARSELEDGER Create a serializable sparse visit-count ledger.

arguments
    stateCount (1,1) double
end
if ~isfinite(stateCount) || stateCount < 1 || ...
        stateCount ~= floor(stateCount) || stateCount > flintmax
    error('mdt:SparseLedgerInvalidStateCount', ...
        'stateCount must be a positive integer not exceeding flintmax.');
end

ledger = struct();
ledger.schema = "mdt.sparse-visit-ledger.v1.0";
ledger.backend = "sparse_sorted_arrays";
ledger.stateCount = stateCount;
ledger.ranks = zeros(0, 1);
ledger.counts = zeros(0, 1);
ledger.totalObservations = 0;
ledger.storedStateCount = 0;
end
