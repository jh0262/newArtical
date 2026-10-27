function diag = enumerateRoundTransition(q, F)
%ENUMERATEROUNDTRANSITION Exactly enumerate clipped MATLAB-round DE outputs.

if ~isscalar(q) || ~isfinite(q) || q < 2 || q ~= floor(q)
    error('mdt:InvalidLevelCount', 'q must be an integer greater than or equal to 2.');
end
if ~isscalar(F) || ~isfinite(F) || F < 0
    error('mdt:InvalidScaleFactor', 'F must be finite and nonnegative.');
end

counts = zeros(1, q);
for a = 0:(q-1)
    for b = 0:(q-1)
        for c = 0:(q-1)
            mutant = a + F*(b-c);
            clipped = min(q-1, max(0, mutant));
            phenotype = round(clipped);
            counts(phenotype+1) = counts(phenotype+1) + 1;
        end
    end
end

probabilities = counts/q^3;
uniform = ones(1, q)/q;

diag = struct();
diag.schema = "mdt.round-transition.v0.1";
diag.q = q;
diag.F = F;
diag.counts = counts;
diag.probabilities = probabilities;
diag.totalVariationFromUniform = 0.5*sum(abs(probabilities-uniform));
diag.boundaryMass = probabilities(1) + probabilities(end);
diag.totalCombinations = q^3;
diag.roundingRule = "clip-to-[0,q-1]-then-MATLAB-round";
end

