function diag = enumeratePermutationSensitivity(q, F)
%ENUMERATEPERMUTATIONSENSITIVITY Exact label-permutation sensitivity of rounding.

if ~isscalar(q) || ~isfinite(q) || q < 2 || q ~= floor(q)
    error('mdt:InvalidLevelCount', 'q must be an integer greater than or equal to 2.');
end
if q > 8
    error('mdt:PermutationEnumerationTooLarge', ...
        'Exact permutation enumeration is limited to q <= 8.');
end

roundDiag = mdt.enumerateRoundTransition(q, F);
labelPermutations = perms(0:(q-1));
nPermutations = size(labelPermutations, 1);
semanticDistributions = zeros(nPermutations, q);

for i = 1:nPermutations
    permutation = labelPermutations(i, :);
    for externalCode = 0:(q-1)
        semanticLabel = permutation(externalCode+1);
        semanticDistributions(i, semanticLabel+1) = ...
            roundDiag.probabilities(externalCode+1);
    end
end

maxJsd = 0;
maxPair = [1, 1];
for i = 1:nPermutations
    for j = (i+1):nPermutations
        value = jensenShannon(semanticDistributions(i, :), ...
            semanticDistributions(j, :));
        if value > maxJsd
            maxJsd = value;
            maxPair = [i, j];
        end
    end
end

diag = struct();
diag.schema = "mdt.permutation-sensitivity.v0.1";
diag.q = q;
diag.F = F;
diag.labelPermutations = labelPermutations;
diag.semanticDistributions = semanticDistributions;
diag.maxJensenShannonDivergence = maxJsd;
diag.maxPairIndices = maxPair;
diag.logarithmBase = "natural";
end

function value = jensenShannon(p, q)
m = 0.5*(p+q);
value = 0.5*klTerm(p, m) + 0.5*klTerm(q, m);
end

function value = klTerm(p, q)
positive = p > 0;
value = sum(p(positive).*log(p(positive)./q(positive)));
end

