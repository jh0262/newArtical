function [offspring, info] = injectRandomDiscreteStatesBlackBox( ...
    offspring, variableSpec, injectionCount, seed)
%INJECTRANDOMDISCRETESTATESBLACKBOX Uniform-state H14 targeting control.

arguments
    offspring double
    variableSpec (1,1) struct
    injectionCount (1,1) double {mustBeInteger,mustBeNonnegative}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end
spec = normalizeBlackBoxSpec(variableSpec);
N = size(offspring, 1);
dummyObj = zeros(N, 2);
dummyCon = zeros(N, numel(spec.constraintScales));
validateBlackBoxCandidates(offspring, dummyObj, dummyCon, spec);
if injectionCount > N || injectionCount > spec.discreteStateCount
    error('mdt:InvalidRandomInjectionCount', ...
        'injectionCount cannot exceed offspring count or state count.');
end

stream = RandStream('mt19937ar', 'Seed', seed);
rowOrder = randperm(stream, N);
selectedRows = reshape(rowOrder(1:injectionCount), [], 1);
selectedRanks = sampleUniqueRanks(stream, ...
    spec.discreteStateCount, injectionCount);
C = spec.continuousCount;
offspring(selectedRows, C+1:end) = mdt.decodeMixedRadixState( ...
    selectedRanks, spec.discreteCardinalities);

info = struct();
info.schema = "mdt.random-blackbox-novelty-injection.v1.0";
info.scheduler = "uniform_rejection_without_replacement";
info.selectedRows = selectedRows;
info.selectedRanks = selectedRanks;
info.injectionCount = injectionCount;
info.truthUsedByGeneration = false;
end

function ranks = sampleUniqueRanks(stream, stateCount, count)
% Rejection sampling avoids materializing 0:(Q-1), preserving large-Q scope.
ranks = zeros(count, 1);
filled = 0;
attempts = 0;
maximumAttempts = 10000*max(count, 1);
while filled < count
    attempts = attempts+1;
    if attempts > maximumAttempts
        error('mdt:RandomInjectionSamplingFailed', ...
            'Unable to draw unique random states within the attempt limit.');
    end
    candidate = randi(stream, stateCount)-1;
    if ~any(ranks(1:filled) == candidate)
        filled = filled+1;
        ranks(filled) = candidate;
    end
end
end
