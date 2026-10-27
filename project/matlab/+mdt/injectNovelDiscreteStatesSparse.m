function [offspring, info] = injectNovelDiscreteStatesSparse( ...
    offspring, cfg, ledger, injectionCount, seed, scheduler)
%INJECTNOVELDISCRETESTATESSPARSE Inject states selected by a sparse ledger.

arguments
    offspring double
    cfg (1,1) struct
    ledger (1,1) struct
    injectionCount (1,1) double {mustBeInteger,mustBeNonnegative}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    scheduler (1,1) string = "affine"
end
if size(offspring, 2) ~= 2+cfg.L || any(~isfinite(offspring), 'all')
    error('mdt:InvalidNoveltyOffspring', ...
        'offspring must be finite and contain 2+L decision columns.');
end
validateSparseLedger(ledger);
if ledger.stateCount ~= cfg.Q
    error('mdt:SparseLedgerStateCountMismatch', ...
        'ledger stateCount must equal cfg.Q.');
end
if injectionCount > size(offspring, 1) || injectionCount > cfg.Q
    error('mdt:InvalidNoveltyInjectionCount', ...
        'injectionCount cannot exceed offspring count or discrete state count.');
end

stream = RandStream('mt19937ar', 'Seed', seed);
rowOrder = randperm(stream, size(offspring, 1));
selectedRows = reshape(rowOrder(1:injectionCount), [], 1);
[selectedRanks, selectionInfo] = mdt.selectLeastVisitedSparse( ...
    ledger, injectionCount, stream, scheduler);
cardinalities = cfg.q*ones(1, cfg.L);
offspring(selectedRows, 3:end) = ...
    mdt.decodeMixedRadixState(selectedRanks, cardinalities);

info = struct();
info.schema = "mdt.sparse-novelty-injection.v1.0";
info.ledgerBackend = ledger.backend;
info.scheduler = selectionInfo.scheduler;
info.selectedRows = selectedRows;
info.selectedRanks = selectedRanks;
info.injectionCount = injectionCount;
info.selectionAudit = selectionInfo;
info.truthUsedByGeneration = false;
end
