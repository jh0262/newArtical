function verify_mask_covariance
R=fileparts(mfilename('fullpath'));D=4;CR=.2;S=[1,.3,.1,.2;.3,2,.1,-.2;.1,.1,1,.4;.2,-.2,.4,2];
assert(all(eig(S)>0));retention=zeros(D);covariance=zeros(D);total=0;
for forced=1:D
 for bits=0:2^D-1
  b=double(bitget(bits,1:D));prob=CR^sum(b)*(1-CR)^(D-sum(b))/D;m=b;m(forced)=1;
  retention=retention+prob*(m'*m);covariance=covariance+prob*(diag(m)*S*diag(m));total=total+prob;
 end
end
p=CR+(1-CR)/D;q=CR^2+2*CR*(1-CR)/D;expected=q*S+(p-q)*diag(diag(S));
assert(abs(total-1)<1e-14&&max(abs(covariance-expected),[],'all')<1e-14);
assert(max(abs(diag(retention)-p))<1e-14);off=retention-diag(diag(retention));assert(max(abs(off(~eye(D))-q))<1e-14);
report=struct('dimension',D,'CR',CR,'enumeratedCases',D*2^D,'marginalRetention',p,'jointRetention',q,'correlationMultiplier',q/p,'maximumCovarianceResidual',max(abs(covariance-expected),[],'all'));
P3Experiment.json(fullfile(R,'audit','mask_covariance_check.json'),report);disp(report);
end
