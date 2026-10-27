function tests = test_mdt_sparse_ledger
tests = functiontests(localfunctions);
end

function testMixedRadixRoundTrip(testCase)
cardinalities = [2, 3, 4];
states = [0, 0, 0; 1, 2, 3; 1, 0, 2];
ranks = mdt.encodeMixedRadixState(states, cardinalities);
verifyEqual(testCase, ranks, [0; 23; 14]);
verifyEqual(testCase, ...
    mdt.decodeMixedRadixState(ranks, cardinalities), states);
end

function testSparseLedgerAggregatesDuplicates(testCase)
ledger = mdt.makeSparseLedger(24);
ledger = mdt.observeSparseLedger(ledger, [7; 2; 7; 23; 2; 7]);

verifyEqual(testCase, ledger.ranks, [2; 7; 23]);
verifyEqual(testCase, ledger.counts, [2; 3; 1]);
verifyEqual(testCase, ledger.totalObservations, 6);
verifyEqual(testCase, ledger.storedStateCount, 3);
end

function testSparseLedgerReportsZeros(testCase)
ledger = mdt.makeSparseLedger(10);
ledger = mdt.observeSparseLedger(ledger, [1; 1; 8]);
counts = mdt.querySparseLedger(ledger, [0; 1; 8; 9]);
verifyEqual(testCase, counts, [0; 2; 1; 0]);
end

function testLegacyInjectionMatchesB5Ref(testCase)
cfg = mdt.makeInstance("D", 2, 3, 0.15, 1);
offspring = [linspace(0, 1, 4)', 0.5*ones(4, 1), zeros(4, 3)];
visitCounts = [0; 0; 1; 1; 2; 2; 3; 3];
ledger = mdt.makeSparseLedger(cfg.Q);
observedRanks = repelem((0:(cfg.Q-1))', visitCounts);
ledger = mdt.observeSparseLedger(ledger, observedRanks);

[denseOffspring, denseInfo] = mdt.injectNovelDiscreteStates( ...
    offspring, cfg, visitCounts, 2, 123);
[sparseOffspring, sparseInfo] = mdt.injectNovelDiscreteStatesSparse( ...
    offspring, cfg, ledger, 2, 123, "legacy");

verifyEqual(testCase, sparseOffspring, denseOffspring);
verifyEqual(testCase, sparseInfo.selectedRows, denseInfo.selectedRows);
verifyEqual(testCase, sparseInfo.selectedRanks, denseInfo.selectedRanks);
end

function testAffineSelectionIsDeterministic(testCase)
ledger = mdt.makeSparseLedger(101);
ledger = mdt.observeSparseLedger(ledger, [0; 5; 5; 99]);
[a, infoA] = mdt.selectLeastVisitedSparse(ledger, 8, 456, "affine");
[b, infoB] = mdt.selectLeastVisitedSparse(ledger, 8, 456, "affine");

verifyEqual(testCase, a, b);
verifyEqual(testCase, infoA, infoB);
verifyEqual(testCase, numel(unique(a)), 8);
verifyGreaterThanOrEqual(testCase, a, zeros(8, 1));
verifyLessThan(testCase, a, 101*ones(8, 1));
end

function testAffineSelectionUsesGlobalMinimum(testCase)
ledger = mdt.makeSparseLedger(5);
observedRanks = repelem((0:4)', [1; 2; 3; 4; 5]);
ledger = mdt.observeSparseLedger(ledger, observedRanks);
selected = mdt.selectLeastVisitedSparse(ledger, 1, 77, "affine");
verifyEqual(testCase, selected, 0);
end

function testLargeStateSpaceStaysSparse(testCase)
stateCount = 1e12;
ledger = mdt.makeSparseLedger(stateCount);
ledger = mdt.observeSparseLedger(ledger, ...
    [0; 17; 17; stateCount-1]);
[selected, info] = mdt.selectLeastVisitedSparse( ...
    ledger, 5, 9001, "affine");

verifyEqual(testCase, ledger.storedStateCount, 3);
verifyEqual(testCase, numel(ledger.ranks), 3);
verifyFalse(testCase, isfield(ledger, 'denseCounts'));
verifyEqual(testCase, numel(unique(selected)), 5);
verifyGreaterThanOrEqual(testCase, selected, zeros(5, 1));
verifyLessThan(testCase, selected, stateCount*ones(5, 1));
verifyEqual(testCase, info.scheduler, "implicit_affine_permutation");
end

function testB5SUsesSparseLedger(testCase)
cfg = mdt.makeInstance("D", 3, 3, 0.05, 1);
op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
    'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
    'stagnationHorizon', 10);
result = mdt.runOptimizer("B5S", cfg, op, 701, 20, 80, 20);

verifyEqual(testCase, result.audit.visitLedgerBackend, "sparse");
verifyEqual(testCase, result.audit.noveltyTargeting, ...
    "least_visited_sparse_affine");
verifyLessThanOrEqual(testCase, ...
    result.audit.visitLedgerStoredStateCount, result.metrics.evaluations);
verifyFalse(testCase, result.audit.truthUsedByGeneration);
end

function testInvalidRankRejected(testCase)
ledger = mdt.makeSparseLedger(8);
verifyError(testCase, @() mdt.observeSparseLedger(ledger, [0; 8]), ...
    'mdt:SparseLedgerInvalidRank');
end
