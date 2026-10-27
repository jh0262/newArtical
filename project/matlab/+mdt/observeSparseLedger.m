function ledger = observeSparseLedger(ledger, ranks)
%OBSERVESPARSELEDGER Add evaluated zero-based state ranks to a ledger.

arguments
    ledger (1,1) struct
    ranks double
end
validateSparseLedger(ledger);
ranks = ranks(:);
validateRanks(ranks, ledger.stateCount);
if isempty(ranks)
    return;
end

[newRanks, ~, groups] = unique(ranks, 'sorted');
newCounts = accumarray(groups, 1);
combinedRanks = [ledger.ranks; newRanks];
combinedCounts = [ledger.counts; newCounts];
[ledger.ranks, ~, groups] = unique(combinedRanks, 'sorted');
ledger.counts = accumarray(groups, combinedCounts);
ledger.totalObservations = ledger.totalObservations + numel(ranks);
ledger.storedStateCount = numel(ledger.ranks);
end

function validateRanks(ranks, stateCount)
if any(~isfinite(ranks)) || any(ranks < 0) || ...
        any(ranks ~= floor(ranks)) || any(ranks >= stateCount)
    error('mdt:SparseLedgerInvalidRank', ...
        'ranks must be zero-based integers smaller than stateCount.');
end
end
