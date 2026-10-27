function value = computePcrAuc(nfe, pcr, budget)
%COMPUTEPCRAUC Compute normalized trapezoidal area under a PCR curve.

nfe = reshape(nfe, 1, []);
pcr = reshape(pcr, 1, []);
if numel(nfe) < 2 || numel(nfe) ~= numel(pcr) || any(~isfinite(nfe)) || ...
        nfe(1) ~= 0 || any(diff(nfe) <= 0) || ~isscalar(budget) || ...
        ~isfinite(budget) || budget <= 0 || nfe(end) ~= budget
    error('mdt:InvalidNfeTimeline', ...
        'nfe must start at 0, strictly increase, and end at the positive budget.');
end
if any(~isfinite(pcr)) || any(pcr < 0 | pcr > 1)
    error('mdt:InvalidPcrValues', 'pcr values must be finite and lie in [0,1].');
end
value = trapz(nfe, pcr)/budget;
end

