function passed = exceedsPracticalThreshold(estimate, threshold)
%EXCEEDSPRACTICALTHRESHOLD Strict SESOI comparison with numeric tolerance.

arguments
    estimate (1,1) double {mustBeFinite}
    threshold (1,1) double {mustBeFinite}
end
tolerance = 1e-12*max([1, abs(estimate), abs(threshold)]);
passed = estimate > threshold+tolerance;
end
