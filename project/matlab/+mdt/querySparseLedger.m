function counts = querySparseLedger(ledger, ranks)
%QUERYSPARSELEDGER Return visit counts, including zero for unseen ranks.

arguments
    ledger (1,1) struct
    ranks double
end
validateSparseLedger(ledger);
originalSize = size(ranks);
flatRanks = ranks(:);
if any(~isfinite(flatRanks)) || any(flatRanks < 0) || ...
        any(flatRanks ~= floor(flatRanks)) || ...
        any(flatRanks >= ledger.stateCount)
    error('mdt:SparseLedgerInvalidRank', ...
        'ranks must be zero-based integers smaller than stateCount.');
end

counts = zeros(size(flatRanks));
for i = 1:numel(flatRanks)
    location = binarySearch(ledger.ranks, flatRanks(i));
    if location > 0
        counts(i) = ledger.counts(location);
    end
end
counts = reshape(counts, originalSize);
end

function location = binarySearch(sortedRanks, target)
lower = 1;
upper = numel(sortedRanks);
location = 0;
while lower <= upper
    middle = floor((lower+upper)/2);
    value = sortedRanks(middle);
    if value == target
        location = middle;
        return;
    elseif value < target
        lower = middle+1;
    else
        upper = middle-1;
    end
end
end
