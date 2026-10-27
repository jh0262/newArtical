function c=ec_config(mode)
if nargin==0, mode='formal'; end
c=struct('study','EarClip_MODE_Study','version','v1','mode',mode,'N',100,'M',2,'generations',500,'seeds',41001:41020,'referenceSamples',1001,'metricInterval',10);
names={'ZDT1','ZDT2','ZDT3','ZDT4','ZDT6','DTLZ2','DTLZ4','DTLZ7'};
dims=[30 30 30 10 10 11 11 21];
for k=1:numel(names), c.problems(k)=struct('name',names{k},'D',dims(k)); end
alg=struct('name','','class','GECMODE','A',false,'B',false,'C',false,'adaptive',true,'shuffle',false);
c.algorithms=repmat(alg,1,13);
for k=0:7
    bits=dec2bin(k,3)-'0'; c.algorithms(k+1).name=['G' num2str(bits,'%d')];
    c.algorithms(k+1).A=logical(bits(1)); c.algorithms(k+1).B=logical(bits(2)); c.algorithms(k+1).C=logical(bits(3));
end
c.algorithms(9).name='MODE_FIXED'; c.algorithms(9).adaptive=false;
for k=1:3
    classic={'NSGAII','SPEA2','MOEAD'};
    c.algorithms(9+k).name=classic{k}; c.algorithms(9+k).class=classic{k}; c.algorithms(9+k).adaptive=false;
end
c.algorithms(13)=c.algorithms(8); c.algorithms(13).name='G111_SHUFFLE'; c.algorithms(13).shuffle=true;
c.constants=struct('memorySize',6,'initialF',.5,'initialCR',.9,'samplingWidth',.1,'learningRate',.1,'armProbabilityFloor',.1,'fixedArmProbability',.5,'coverageTolerance',1e-12,'areaTieTolerance',1e-12,'successTolerance',1e-14,'MOEADtype',2);
if strcmp(mode,'smoke'), c.generations=5; c.seeds=99001; end
end
