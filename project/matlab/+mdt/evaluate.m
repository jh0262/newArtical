function [obj, con] = evaluate(X, cfg)
%EVALUATE Evaluate objective values and constraints for phenotype rows.

if ~isnumeric(X) || size(X, 2) ~= 2 + cfg.L || any(~isfinite(X), 'all')
    error('mdt:InvalidDecisionMatrix', ...
        'X must be a finite numeric matrix with 2+L columns.');
end

u = X(:, 1);
v = X(:, 2);
d = X(:, 3:end);
if any(u < 0 | u > 1) || any(v < 0 | v > 1)
    error('mdt:DecisionOutOfBounds', 'Continuous variables must lie in [0,1].');
end
if any(abs(d-round(d)) > 1e-12, 'all') || any(d < 0 | d > cfg.q-1, 'all')
    error('mdt:InvalidDiscreteState', ...
        'Discrete variables must be integer indices from 0 to q-1.');
end
dExternal = round(d);
d = dExternal;
for j = 3:cfg.L
    mapped = cfg.labelPermutation(dExternal(:, j)+1);
    d(:, j) = reshape(mapped, [], 1);
end

valid = validDiscreteMask(d, cfg);

powers = cfg.q.^((cfg.L-1):-1:0);
rank = d*powers';
p = (rank + u)/cfg.Q;
penalty = cfg.lambda*(v-0.5).^2;

if cfg.family == "IR" && any(valid)
    truth = mdt.enumerateTruth(cfg);
    externalRank = dExternal*powers';
    validRank = truth.validRankByState(externalRank(valid)+1) - 1;
    pairIndex = floor(validRank/2);
    nPairs = ceil(size(truth.validDiscreteStates, 1)/2);
    p(valid) = (pairIndex + u(valid))/nPairs;
    penalty(valid) = penalty(valid) + cfg.delta*mod(validRank, 2);
end

obj = [p + penalty, 1 - p + penalty];
con = [double(~valid), abs(v-0.5) - cfg.rho];
end
