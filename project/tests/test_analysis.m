function tests=test_analysis
tests=functiontests(localfunctions);
end
function testHolmGold(t)
verifyEqual(t,ec_holm([.01 .04 .03]),[.03 .06 .06],'AbsTol',1e-12);
verifyEqual(t,ec_holm([.5 .9 1]),[1 1 1],'AbsTol',1e-12);
end
function testFactorialGold(t)
b=dec2bin(0:7,3)-'0'; A=b(:,1)'; B=b(:,2)'; C=b(:,3)';
effects=ec_factorial(10+2*A+3*B+5*C);
verifyEqual(t,effects,[2 3 5 0 0 0 0],'AbsTol',1e-12);
effects=ec_factorial(A.*B.*C);
verifyEqual(t,effects,[.25 .25 .25 .5 .5 .5 1],'AbsTol',1e-12);
end
