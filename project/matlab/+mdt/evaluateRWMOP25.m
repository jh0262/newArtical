function [obj, con] = evaluateRWMOP25(X)
%EVALUATERWMOP25 Evaluate the published RCM25 process-synthesis problem.

if ~isnumeric(X) || size(X, 2) ~= 2 || any(~isfinite(X), 'all')
    error('mdt:InvalidRWMOP25DecisionMatrix', ...
        'X must be a finite numeric matrix with two columns.');
end
if any(X(:, 1) < 0 | X(:, 1) > 1.6)
    error('mdt:RWMOP25DecisionOutOfBounds', ...
        'x1 must remain in [0,1.6].');
end
if any(X(:, 2) ~= round(X(:, 2))) || any(X(:, 2) < 0 | X(:, 2) > 1)
    error('mdt:RWMOP25InvalidDiscreteCode', ...
        'x2_binary must be either zero or one.');
end

x1 = X(:, 1);
x2 = X(:, 2);
obj = [x2+2.*x1, -x1.^2-x2];
con = [obj(:, 2)+1.25, x1+x2-1.6];
end

