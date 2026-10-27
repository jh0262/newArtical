function [selectedRanks, info] = selectLeastVisitedSparse( ...
    ledger, selectionCount, seedOrStream, scheduler)
%SELECTLEASTVISITEDSPARSE Select exact minimum-count ranks without Q arrays.

arguments
    ledger (1,1) struct
    selectionCount (1,1) double {mustBeInteger,mustBeNonnegative}
    seedOrStream
    scheduler (1,1) string = "affine"
end
validateSparseLedger(ledger);
if selectionCount > ledger.stateCount
    error('mdt:SparseLedgerInvalidSelectionCount', ...
        'selectionCount cannot exceed the state count.');
end
scheduler = lower(scheduler);
if ~ismember(scheduler, ["affine", "legacy"])
    error('mdt:SparseLedgerInvalidScheduler', ...
        'scheduler must be affine or legacy.');
end
[stream, seedSource] = resolveStream(seedOrStream);

if scheduler == "legacy"
    tieOrder = reshape(randperm(stream, ledger.stateCount)-1, [], 1);
    offset = NaN;
    step = NaN;
    schedulerName = "legacy_random_permutation";
else
    [offset, step] = makeAffineParameters(ledger.stateCount, stream);
    tieOrder = zeros(0, 1);
    schedulerName = "implicit_affine_permutation";
end

working = ledger;
selectedRanks = zeros(selectionCount, 1);
scanCount = 0;
for i = 1:selectionCount
    minimumCount = currentMinimum(working);
    if scheduler == "legacy"
        counts = mdt.querySparseLedger(working, tieOrder);
        location = find(counts == minimumCount, 1, 'first');
        rank = tieOrder(location);
        scanCount = scanCount + location;
    else
        [rank, scanned] = findAffineMinimum( ...
            working, minimumCount, offset, step);
        scanCount = scanCount + scanned;
    end
    selectedRanks(i) = rank;
    working = mdt.observeSparseLedger(working, rank);
end

info = struct();
info.schema = "mdt.sparse-least-visited-selection.v1.0";
info.scheduler = schedulerName;
info.seedSource = seedSource;
info.stateCount = ledger.stateCount;
info.selectionCount = selectionCount;
info.affineOffset = offset;
info.affineStep = step;
info.scannedCandidates = scanCount;
info.truthUsedByGeneration = false;
end

function [stream, seedSource] = resolveStream(seedOrStream)
if isa(seedOrStream, 'RandStream')
    stream = seedOrStream;
    seedSource = "provided_stream";
    return;
end
if ~isnumeric(seedOrStream) || ~isscalar(seedOrStream) || ...
        ~isfinite(seedOrStream) || seedOrStream < 0 || ...
        seedOrStream ~= floor(seedOrStream)
    error('mdt:SparseLedgerInvalidSeed', ...
        'seed must be a nonnegative integer or a RandStream.');
end
stream = RandStream('mt19937ar', 'Seed', seedOrStream);
seedSource = "numeric_seed";
end

function minimumCount = currentMinimum(ledger)
if ledger.storedStateCount < ledger.stateCount
    minimumCount = 0;
else
    minimumCount = min(ledger.counts);
end
end

function [offset, step] = makeAffineParameters(stateCount, stream)
if stateCount == 1
    offset = 0;
    step = 0;
    return;
end
offset = floor(rand(stream)*stateCount);
step = 1 + floor(rand(stream)*(stateCount-1));
while gcd(step, stateCount) ~= 1
    step = step + 1;
    if step >= stateCount
        step = 1;
    end
end
end

function [rank, scanned] = findAffineMinimum( ...
    ledger, minimumCount, offset, step)
position = 0;
scanned = 0;
while position < ledger.stateCount
    rank = affineRank(offset, step, position, ledger.stateCount);
    scanned = scanned + 1;
    if mdt.querySparseLedger(ledger, rank) == minimumCount
        return;
    end
    position = position + 1;
end
error('mdt:SparseLedgerSelectionFailure', ...
    'No state matched the computed minimum visit count.');
end

function rank = affineRank(offset, step, position, modulus)
if modulus == 1
    rank = 0;
    return;
end
m = uint64(modulus);
product = multiplyMod(uint64(position), uint64(step), m);
rank = double(mod(uint64(offset) + product, m));
end

function result = multiplyMod(a, b, modulus)
result = uint64(0);
while b > 0
    if bitand(b, uint64(1)) ~= 0
        result = mod(result + a, modulus);
    end
    a = mod(a + a, modulus);
    b = bitshift(b, -1);
end
end
