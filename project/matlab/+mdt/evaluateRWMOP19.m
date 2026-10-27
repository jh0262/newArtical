function [obj, con] = evaluateRWMOP19(X)
%EVALUATERWMOP19 Evaluate the published RCM19 batch-plant problem.
%
% X uses [V1,V2,V3,TL1,TL2,B1,B2,N1_code,N2_code,N3_code].

if ~isnumeric(X) || size(X, 2) ~= 10 || any(~isfinite(X), 'all')
    error('mdt:InvalidRWMOP19DecisionMatrix', ...
        'X must be a finite numeric matrix with ten columns.');
end

continuousLower = [250, 250, 250, 6, 4, 40, 10];
continuousUpper = [2500, 2500, 2500, 20, 16, 700, 450];
continuous = X(:, 1:7);
if any(continuous < continuousLower, 'all') || ...
        any(continuous > continuousUpper, 'all')
    error('mdt:RWMOP19DecisionOutOfBounds', ...
        'The seven continuous variables must remain within RCM19 bounds.');
end

codes = X(:, 8:10);
if any(codes ~= round(codes), 'all') || ...
        any(codes < 0 | codes > 2, 'all')
    error('mdt:RWMOP19InvalidDiscreteCode', ...
        'N1_code, N2_code, and N3_code must be integers from 0 to 2.');
end

N1 = codes(:, 1)+1;
N2 = codes(:, 2)+1;
N3 = codes(:, 3)+1;
V1 = X(:, 1);
V2 = X(:, 2);
V3 = X(:, 3);
TL1 = X(:, 4);
TL2 = X(:, 5);
B1 = X(:, 6);
B2 = X(:, 7);

Q1 = 40000;
Q2 = 20000;
alpha = 250;
beta = 0.6;

obj = zeros(size(X, 1), 3);
obj(:, 1) = alpha.*(N1.*V1.^beta + N2.*V2.^beta + N3.*V3.^beta);
obj(:, 2) = 65.*(Q1./B1 + Q2./B2) + 0.08.*Q1 + 0.1.*Q2;
obj(:, 3) = Q1.*TL1./B1 + Q2.*TL2./B2;

con = zeros(size(X, 1), 10);
con(:, 1) = obj(:, 3)-6000;
con(:, 2) = 2.*B1 + 4.*B2 - V1;
con(:, 3) = 3.*B1 + 6.*B2 - V2;
con(:, 4) = 4.*B1 + 3.*B2 - V3;
con(:, 5) = 8-N1.*TL1;
con(:, 6) = 20-N2.*TL1;
con(:, 7) = 8-N3.*TL1;
con(:, 8) = 16-N1.*TL2;
con(:, 9) = 4-N2.*TL2;
con(:, 10) = 4-N3.*TL2;
end

