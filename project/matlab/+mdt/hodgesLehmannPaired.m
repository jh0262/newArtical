function estimate = hodgesLehmannPaired(differences)
%HODGESLEHMANNPAIRED Median of Walsh averages for paired differences.

arguments
    differences double
end
differences = differences(:);
if isempty(differences) || any(~isfinite(differences))
    error('mdt:InvalidPairedDifferences', ...
        'Paired differences must be a nonempty finite numeric vector.');
end

n = numel(differences);
walsh = zeros(n*(n+1)/2, 1);
cursor = 0;
for i = 1:n
    count = n-i+1;
    walsh(cursor+(1:count)) = ...
        (differences(i)+differences(i:n))/2;
    cursor = cursor+count;
end
estimate = median(walsh);
end
