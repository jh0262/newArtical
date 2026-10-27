% Numerical verification before optimization. All outputs are actual MATLAB results.
root=fileparts(mfilename('fullpath')); addpath(root);
out=fullfile(root,'validation'); if ~isfolder(out), mkdir(out); end
testResult=runtests(fullfile(root,'TestPPaPaRModel.m'));
assert(all([testResult.Passed]),'Model tests failed');
designs=[400,700,1000,150;600,1000,1200,400;200,600,800,100; ...
    500,650,1100,300;350,900,1150,200;550,800,900,350];
powers=11:18; values=zeros(size(designs,1),3,numel(powers)); timings=zeros(numel(powers),1);
for j=1:numel(powers)
    m=PPaPaRModel.config(2^powers(j)); timer=tic;
    values(:,:,j)=PPaPaRModel.evaluate(designs,m); timings(j)=toc(timer)/size(designs,1);
end
relative=abs(values./values(:,:,end)-1);
% Independent reproducible randomized shifts assess integration uncertainty.
rng(721,'twister'); shifts=rand(8,3); shifted=zeros(6,3,8);
for j=1:8, shifted(:,:,j)=PPaPaRModel.evaluate(designs,PPaPaRModel.config(16384,shifts(j,:))); end
shiftCV=std(shifted,0,3)./abs(mean(shifted,3));
% Nonlinear Monte Carlo compared to the local covariance at an interior pose.
m=PPaPaRModel.config(4096); d=designs(1,:); g=PPaPaRModel.geometry(d,m);
pose=[1000,100,-1250,20*pi/180]; v=PPaPaRModel.inverse(pose,g,m);
[J,S]=PPaPaRModel.differential(pose,v,g);
rng(722,'twister'); Z=randn(12000,12);
scales=[.1,.5,1]; monteCarlo=struct([]);
for j=1:numel(scales)
    noise=Z.*([m.sigmaQ,m.sigmaQ,m.sigmaAlpha,m.sigmaAlpha,m.sigmaG]*scales(j));
    actual=zeros(size(noise,1),4); linear=noise*[J,S]'; valid=false(size(noise,1),1);
    for k=1:size(noise,1)
        [p,valid(k)]=PPaPaRModel.forward(v+noise(k,1:4),g+noise(k,5:12),m);
        actual(k,:)=p-pose;
    end
    assert(all(valid),'Unexpected assembly/limit failure in small-noise Monte Carlo');
    expected=[J,S]*diag(([m.sigmaQ,m.sigmaQ,m.sigmaAlpha,m.sigmaAlpha,m.sigmaG]*scales(j)).^2)*[J,S]';
    observed=cov(actual); residual=actual-linear;
    monteCarlo(j).scale=scales(j); monteCarlo(j).samples=size(noise,1);
    monteCarlo(j).predictedRMS=sqrt(trace(expected(1:3,1:3)));
    monteCarlo(j).observedRMS=sqrt(mean(sum(actual(:,1:3).^2,2)));
    monteCarlo(j).covarianceRelativeError=norm(observed-expected,'fro')/norm(expected,'fro');
    monteCarlo(j).linearResidualRMS=sqrt(mean(sum(residual(:,1:3).^2,2)));
end
thresholds=[.01,.02,.04]; sensitivity=zeros(3,3);
for j=1:3
    mm=PPaPaRModel.config(262144,zeros(1,3),thresholds(j));
    sensitivity(j,:)=PPaPaRModel.evaluate(d,mm);
end
report=struct('testsPassed',sum([testResult.Passed]),'testsTotal',numel(testResult), ...
    'version',version,'designs',designs,'powers',powers,'objectives',values, ...
    'relativeTo262144',relative,'secondsPerDesign',timings,'shiftCV16384',shiftCV, ...
    'monteCarlo',monteCarlo,'thresholds',thresholds,'thresholdObjectives',sensitivity);
save(fullfile(out,'model_validation.mat'),'report','testResult','shifted','shifts','monteCarlo');
fid=fopen(fullfile(out,'model_validation.json'),'w','n','UTF-8'); fprintf(fid,'%s',jsonencode(report,'PrettyPrint',true)); fclose(fid);
disp('Relative integration errors by count (maximum across 6 designs):');
disp([2.^powers',squeeze(max(relative,[],1))']);
disp('Shift CV at 16384:'); disp(shiftCV);
disp('Model baseline and threshold sensitivity:'); disp(sensitivity);
disp(monteCarlo); disp(timings);
