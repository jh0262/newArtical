function [obj, con] = evaluateRWMOP6(X)
%EVALUATERWMOP6 Evaluate the published RCM06 speed-reducer problem.
%
% X uses the B5S type-grouped order
% [x1, x2, x4, x5, x6, x7, x3_code], with x3_code in 0:11.

if ~isnumeric(X) || size(X, 2) ~= 7 || any(~isfinite(X), 'all')
    error('mdt:InvalidRWMOP6DecisionMatrix', ...
        'X must be a finite numeric matrix with seven columns.');
end

continuousLower = [2.6, 0.7, 7.3, 7.3, 2.9, 5.0];
continuousUpper = [3.6, 0.8, 8.3, 8.3, 3.9, 5.5];
continuous = X(:, 1:6);
if any(continuous < continuousLower, 'all') || ...
        any(continuous > continuousUpper, 'all')
    error('mdt:RWMOP6DecisionOutOfBounds', ...
        'The six continuous variables must remain within RCM06 bounds.');
end

discreteCode = X(:, 7);
if any(discreteCode ~= round(discreteCode)) || ...
        any(discreteCode < 0 | discreteCode > 11)
    error('mdt:RWMOP6InvalidDiscreteCode', ...
        'x3_code must be an integer from 0 to 11.');
end

x1 = X(:, 1);
x2 = X(:, 2);
x4 = X(:, 3);
x5 = X(:, 4);
x6 = X(:, 5);
x7 = X(:, 6);
x3 = discreteCode + 17;

obj = zeros(size(X, 1), 2);
obj(:, 1) = 0.7854.*x1.*x2.^2.*(10.*x3.^2/3 + ...
    14.933.*x3 - 43.0934) - 1.508.*x1.*(x6.^2 + x7.^2) + ...
    7.477.*(x6.^3 + x7.^3) + 0.7854.*(x4.*x6.^2 + x5.*x7.^2);
obj(:, 2) = sqrt((745.*x4./(x2.*x3)).^2 + 1.69e7)./(0.1.*x6.^3);

con = zeros(size(X, 1), 11);
con(:, 1) = 1./(x1.*x2.^2.*x3) - 1/27;
con(:, 2) = 1./(x1.*x2.^2.*x3.^2) - 1/397.5;
con(:, 3) = x4.^3./(x2.*x3.*x6.^4) - 1/1.93;
con(:, 4) = x5.^3./(x2.*x3.*x7.^4) - 1/1.93;
con(:, 5) = x2.*x3 - 40;
con(:, 6) = x1./x2 - 12;
con(:, 7) = -x1./x2 + 5;
con(:, 8) = 1.9 - x4 + 1.5.*x6;
con(:, 9) = 1.9 - x5 + 1.1.*x7;
con(:, 10) = obj(:, 2) - 1300;
con(:, 11) = sqrt((745.*x5./(x2.*x3)).^2 + 1.575e8)./ ...
    (0.1.*x7.^3) - 850;
end
