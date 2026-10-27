function tests=test_integration
tests=functiontests(localfunctions);
end

function testMatrixAndProblemGold(t)
c=ec_config('formal');
verifyEqual(t,numel(c.algorithms),13); verifyEqual(t,numel(c.problems),8);
verifyEqual(t,c.generations,500); verifyEqual(t,c.N,100); verifyEqual(t,numel(c.seeds),20);
p=ECProblem('N',100,'maxFE',50100,'parameter',{'ZDT1',30,120});
verifyEqual(t,p.CalObj(zeros(1,30)),[0 1],'AbsTol',1e-12);
verifyEqual(t,p.CalObj(ones(1,30)),[1 10*(1-sqrt(.1))],'AbsTol',1e-12);
q=ECProblem('N',100,'maxFE',50100,'parameter',{'DTLZ2',11,120});
verifyEqual(t,q.CalObj([0 .5*ones(1,10)]),[1 0],'AbsTol',1e-12);
end

function testAllAlgorithmsAndCommonInitialization(t)
c=ec_config('smoke'); c.generations=3; c.N=20;
root=fileparts(fileparts(mfilename('fullpath')));
base=fullfile(root,'verification',['integration_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
initial=[];
for a=1:numel(c.algorithms)
    r=ec_run_one(c,1,a,99001,fullfile(base,c.algorithms(a).name));
    verifyEqual(t,r.meta.FE,80); verifyEqual(t,r.meta.generations,3);
    verifySize(t,r.Fronts,[20 2 4]); verifyTrue(t,all(isfinite(r.Fronts),'all'));
    if isempty(initial), initial=r.initialX; else, verifyEqual(t,r.initialX,initial); end
end
end

function testIndependentSameSeedRerun(t)
c=ec_config('smoke'); c.generations=7; c.N=20;
root=fileparts(fileparts(mfilename('fullpath')));
base=fullfile(root,'verification',['repro_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
a=find(strcmp({c.algorithms.name},'G111'));
x=ec_run_one(c,3,a,99003,fullfile(base,'run_a'));
y=ec_run_one(c,3,a,99003,fullfile(base,'run_b'));
verifyEqual(t,x.Fronts,y.Fronts); verifyEqual(t,x.finalX,y.finalX);
verifyEqual(t,x.Telemetry,y.Telemetry); verifyEqual(t,x.HV,y.HV);
end
