function [offspring, info] = injectNovelDiscreteStatesSparseBlackBox( ...
    offspring, variableSpec, ledger, injectionCount, seed, scheduler)
%INJECTNOVELDISCRETESTATESSPARSEBLACKBOX Sparse novelty injection for mixed radices.

arguments
    offspring double
    variableSpec (1,1) struct
    ledger (1,1) struct
    injectionCount (1,1) double {mustBeInteger,mustBeNonnegative}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    scheduler (1,1) string = "affine"
end
spec = normalizeBlackBoxSpec(variableSpec);
N = size(offspring, 1);
dummyObj = zeros(N, 2);
dummyCon = zeros(N, numel(spec.constraintScales));
validateBlackBoxCandidates(offspring, dummyObj, dummyCon, spec);
validateSparseLedger(ledger);
if ledger.stateCount ~= spec.discreteStateCount
    error('mdt:SparseLedgerStateCountMismatch', ...
        'ledger stateCount must equal the mixed-radix state count.');
end
if injectionCount > N || injectionCount > spec.discreteStateCount
    error('mdt:InvalidNoveltyInjectionCount', ...
        'injectionCount cannot exceed offspring count or state count.');
end

stream = RandStream('mt19937ar', 'Seed', seed);
rowOrder = randperm(stream, N);
selectedRows = reshape(rowOrder(1:injectionCount), [], 1);
[selectedRanks, selectionInfo] = mdt.selectLeastVisitedSparse( ...
    ledger, injectionCount, stream, scheduler);
C = spec.continuousCount;
offspring(selectedRows, C+1:end) = mdt.decodeMixedRadixState( ...
    selectedRanks, spec.discreteCardinalities);

info = struct();
info.schema = "mdt.sparse-blackbox-novelty-injection.v1.0";
info.ledgerBackend = ledger.backend;
info.scheduler = selectionInfo.scheduler;
info.selectedRows = selectedRows;
info.selectedRanks = selectedRanks;
info.injectionCount = injectionCount;
info.selectionAudit = selectionInfo;
info.truthUsedByGeneration = false;
end

