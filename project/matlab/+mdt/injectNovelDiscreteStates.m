function [offspring, info] = injectNovelDiscreteStates( ...
    offspring, cfg, visitCounts, injectionCount, seed)
%INJECTNOVELDISCRETESTATES Replace discrete blocks by least-visited states.

arguments
    offspring double
    cfg (1,1) struct
    visitCounts double
    injectionCount (1,1) double {mustBeInteger,mustBeNonnegative}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end
if size(offspring, 2) ~= 2+cfg.L || any(~isfinite(offspring), 'all')
    error('mdt:InvalidNoveltyOffspring', ...
        'offspring must be finite and contain 2+L decision columns.');
end
visitCounts = visitCounts(:);
if numel(visitCounts) ~= cfg.Q || any(~isfinite(visitCounts)) || ...
        any(visitCounts < 0) || any(visitCounts ~= floor(visitCounts))
    error('mdt:InvalidVisitCounts', ...
        'visitCounts must contain one nonnegative integer per discrete state.');
end
if injectionCount > size(offspring, 1) || injectionCount > cfg.Q
    error('mdt:InvalidNoveltyInjectionCount', ...
        'injectionCount cannot exceed offspring count or discrete state count.');
end

stream = RandStream('mt19937ar', 'Seed', seed);
rowOrder = randperm(stream, size(offspring, 1));
stateOrder = randperm(stream, cfg.Q);
tieRank = zeros(cfg.Q, 1);
tieRank(stateOrder) = 1:cfg.Q;
workingCounts = visitCounts;
selectedRanks = zeros(injectionCount, 1);
for i = 1:injectionCount
    [~, order] = sortrows([workingCounts, tieRank]);
    rank = order(1)-1;
    selectedRanks(i) = rank;
    workingCounts(rank+1) = workingCounts(rank+1)+1;
end
selectedRows = reshape(rowOrder(1:injectionCount), [], 1);
offspring(selectedRows, 3:end) = decodeRanks(selectedRanks, cfg.q, cfg.L);

info = struct();
info.schema = "mdt.novelty-injection.v0.1";
info.selectedRows = selectedRows;
info.selectedRanks = selectedRanks;
info.injectionCount = injectionCount;
info.truthUsedByGeneration = false;
end

function states = decodeRanks(ranks, q, L)
states = zeros(numel(ranks), L);
for j = 1:L
    states(:, j) = mod(floor(ranks/q^(L-j)), q);
end
end
