function [offspring, info] = injectRandomDiscreteStates( ...
    offspring, cfg, injectionCount, seed)
%INJECTRANDOMDISCRETESTATES Uniform-state control for B4 targeting ablation.

arguments
    offspring double
    cfg (1,1) struct
    injectionCount (1,1) double {mustBeInteger,mustBeNonnegative}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end
if size(offspring, 2) ~= 2+cfg.L || any(~isfinite(offspring), 'all')
    error('mdt:InvalidRandomInjectionOffspring', ...
        'offspring must be finite and contain 2+L decision columns.');
end
if injectionCount > size(offspring, 1) || injectionCount > cfg.Q
    error('mdt:InvalidRandomInjectionCount', ...
        'injectionCount cannot exceed offspring count or state count.');
end

stream = RandStream('mt19937ar', 'Seed', seed);
rows = reshape(randperm(stream, size(offspring, 1), injectionCount), [], 1);
ranks = reshape(randperm(stream, cfg.Q, injectionCount)-1, [], 1);
offspring(rows, 3:end) = decodeRanks(ranks, cfg.q, cfg.L);

info = struct('schema', "mdt.random-discrete-injection.v0.1", ...
    'selectedRows', rows, 'selectedRanks', ranks, ...
    'injectionCount', injectionCount, 'truthUsedByGeneration', false);
end

function states = decodeRanks(ranks, q, L)
states = zeros(numel(ranks), L);
for j = 1:L
    states(:, j) = mod(floor(ranks/q^(L-j)), q);
end
end
