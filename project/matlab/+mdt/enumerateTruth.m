function truth = enumerateTruth(cfg)
%ENUMERATETRUTH Enumerate exact discrete truth for an MDT instance.

validateConfig(cfg);
states = enumerateStates(cfg.q, cfg.L);
semanticStates = applyCategoryPermutation(states, cfg);

validMask = validDiscreteMask(semanticStates, cfg);

validStates = states(validMask, :);
validSemanticStates = semanticStates(validMask, :);
componentIds = connectedComponents(validSemanticStates, cfg);
nComponents = max(componentIds);

stateToComponent = zeros(cfg.Q, 1);
stateToComponent(validMask) = componentIds;
validRankByState = zeros(cfg.Q, 1);
powers = cfg.q.^((cfg.L-1):-1:0);
semanticRanks = semanticStates*powers';
validSemanticRanks = semanticRanks(validMask);
[~, canonicalOrder] = sort(validSemanticRanks);
canonicalRanks = zeros(size(validStates, 1), 1);
canonicalRanks(canonicalOrder) = (1:size(validStates, 1))';
validRankByState(validMask) = canonicalRanks;

fullRanks = validSemanticRanks;
if cfg.family == "IR"
    validOrdinal = canonicalRanks - 1;
    pairIndex = floor(validOrdinal/2);
    nParetoRelevant = ceil(size(validStates, 1)/2);
    paretoSegments = [pairIndex/nParetoRelevant, (pairIndex+1)/nParetoRelevant];
    paretoRelevantByComponent = false(nComponents, 1);
    relevantRows = mod(validOrdinal, 2) == 0;
    paretoRelevantByComponent(componentIds(relevantRows)) = true;
else
    paretoSegments = [fullRanks/cfg.Q, (fullRanks+1)/cfg.Q];
    paretoRelevantByComponent = true(nComponents, 1);
    nParetoRelevant = nComponents;
end

truth = struct();
truth.schema = "mdt.truth.v0.1";
truth.validDiscreteStates = validStates;
truth.validMaskByState = validMask;
truth.componentIdByValidState = componentIds;
truth.componentIdByState = stateToComponent;
truth.validRankByState = validRankByState;
truth.nComponents = nComponents;
truth.paretoRelevantByComponent = paretoRelevantByComponent;
truth.nParetoRelevantComponents = nParetoRelevant;
truth.feasibleFractionAnalytic = ...
    2*cfg.rho*(nnz(validMask)/cfg.Q);
truth.paretoSegments = paretoSegments;
end

function semanticStates = applyCategoryPermutation(states, cfg)
semanticStates = states;
for j = 3:cfg.L
    mapped = cfg.labelPermutation(states(:, j)+1);
    semanticStates(:, j) = reshape(mapped, [], 1);
end
end

function states = enumerateStates(q, L)
Q = q^L;
ranks = (0:Q-1)';
states = zeros(Q, L);
for j = 1:L
    states(:, j) = mod(floor(ranks/q^(L-j)), q);
end
end

function ids = connectedComponents(states, cfg)
n = size(states, 1);
ids = zeros(n, 1);
component = 0;

for start = 1:n
    if ids(start) ~= 0
        continue;
    end
    component = component + 1;
    ids(start) = component;
    queue = start;
    head = 1;
    while head <= numel(queue)
        current = queue(head);
        head = head + 1;
        for candidate = 1:n
            if ids(candidate) ~= 0
                continue;
            end
            if isSemanticNeighbor(states(current, :), states(candidate, :), cfg)
                ids(candidate) = component;
                queue(end+1) = candidate; %#ok<AGROW>
            end
        end
    end
end
end

function tf = isSemanticNeighbor(a, b, cfg)
changed = find(a ~= b);
if numel(changed) ~= 1
    tf = false;
    return;
end

j = changed(1);
if j <= 2
    tf = abs(a(j)-b(j)) == 1;
else
    tf = cfg.categoryAdjacency(a(j)+1, b(j)+1) ~= 0;
end
end

function validateConfig(cfg)
required = {'family', 'q', 'L', 'rho', 'lambda', 'Q', 'categoryAdjacency'};
if ~isstruct(cfg) || ~all(isfield(cfg, required))
    error('mdt:InvalidConfiguration', 'cfg is not a complete MDT configuration.');
end
end
