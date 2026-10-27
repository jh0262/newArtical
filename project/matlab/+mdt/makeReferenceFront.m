function [referenceSet, componentIds] = makeReferenceFront(truth, samplesPerComponent)
%MAKEREFERENCEFRONT Discretize each Pareto-relevant component equally.

required = {'componentIdByValidState', 'paretoRelevantByComponent', ...
    'paretoSegments', 'nParetoRelevantComponents'};
if ~isstruct(truth) || ~all(isfield(truth, required)) || ...
        ~isscalar(samplesPerComponent) || ~isfinite(samplesPerComponent) || ...
        samplesPerComponent < 2 || samplesPerComponent ~= floor(samplesPerComponent)
    error('mdt:InvalidReferenceFrontInput', ...
        'truth is incomplete or samplesPerComponent is not an integer >= 2.');
end
if size(truth.paretoSegments, 1) ~= numel(truth.componentIdByValidState) || ...
        size(truth.paretoSegments, 2) ~= 2
    error('mdt:InvalidReferenceFrontInput', ...
        'truth Pareto segments are not aligned with valid states.');
end

relevant = find(truth.paretoRelevantByComponent);
if numel(relevant) ~= truth.nParetoRelevantComponents
    error('mdt:InvalidReferenceFrontInput', ...
        'truth Pareto-relevant component count is inconsistent.');
end
referenceSet = zeros(numel(relevant)*samplesPerComponent, 2);
componentIds = zeros(numel(relevant)*samplesPerComponent, 1);
for i = 1:numel(relevant)
    component = relevant(i);
    rows = truth.componentIdByValidState == component;
    if ~any(rows)
        error('mdt:InvalidReferenceFrontInput', ...
            'A Pareto-relevant component has no valid-state segment.');
    end
    segments = truth.paretoSegments(rows, :);
    lower = min(segments(:, 1));
    upper = max(segments(:, 2));
    parameter = linspace(lower, upper, samplesPerComponent)';
    outputRows = (i-1)*samplesPerComponent + (1:samplesPerComponent);
    referenceSet(outputRows, :) = [parameter, 1-parameter];
    componentIds(outputRows) = component;
end
end
