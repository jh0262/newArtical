classdef MOCPOExperiment
 methods(Static)
  function s=source()
   r=P4Experiment.root();s=struct('implementation',fileread(fullfile(r,'code','MOCPO2025.m')), ...
    'runner',fileread(fullfile(r,'code','MOCPOExperiment.m')),'protocol',fileread(fullfile(r,'BASELINE_PROTOCOL.md')),'shared',P4Experiment.source());
  end
  function jobs=jobs()
   a=P4Experiment.jobs();a=a(strcmp({a.mode},'DR'));jobs=a([]);
   for i=1:numel(a)
    for mode=["MOCPOF","MOCPOR"]
     j=a(i);j.mode=char(mode);j.id=sprintf('%s_%s_%d',j.problem,mode,j.seed);jobs(end+1)=j; %#ok<AGROW>
    end
   end
  end
  function f=start()
   r=P4Experiment.root();source=MOCPOExperiment.source();versionInfo=ver;
   if isfile(fullfile(r,'baseline_freeze.mat'))
    z=load(fullfile(r,'baseline_freeze.mat'),'source');assert(isequal(z.source,source));
   else,save(fullfile(r,'baseline_freeze.mat'),'source','versionInfo');end
   jobs=MOCPOExperiment.jobs();P4Experiment.json(fullfile(r,'results','baseline_plan.json'),jobs);
   pool=gcp();addAttachedFiles(pool,{fullfile(r,'code','MOCPO2025.m'),fullfile(r,'code','MOCPOExperiment.m')});
   f=parallel.FevalFuture.empty();
   for i=1:numel(jobs),f(end+1)=parfeval(pool,@MOCPOExperiment.one,1,jobs(i),source,r);end %#ok<AGROW>
   fprintf('Submitted %d paper-reconstruction comparison searches.\n',numel(jobs));
  end
  function status=one(job,source,sharedRoot)
   r=P4Experiment.root(sharedRoot);path=fullfile(r,'results','runs',[job.id,'.mat']);
   try
    maxNumCompThreads(1);assert(isequal(source,MOCPOExperiment.source()));P4Tape.store('clear',[]);
    p=P4Core.problem(job.problem);c=MOCPO2025.config(job.mode,job.seed);
    if isfile(path)
     z=load(path,'result','source');assert(isequal(source,z.source)&&isequal(c,z.result.config));result=z.result;
    else
     result=MOCPO2025.solve(p,c);assert(result.FE==25100);save(path,'result','source','-v7');
    end
    if strcmp(job.problem,'PPAR')
     vp=fullfile(r,'validation',[job.id,'.mat']);
     if ~isfile(vp)
      X=result.X;allF=cell(2,1);allCV=allF;allKeep=allF;hv=zeros(2,1);sp=hv;counts=hv;
      for j=1:2
       [f,cv]=PPaPaRModel.evaluate(X,PPaPaRModel.config(262144*4^(j-1)));keep=cv==0&~any(P4Core.dominance(f,cv),1)';
       [~,hv(j),sp(j)]=P4Core.metrics(p,f(keep,:));allF{j}=f;allCV{j}=cv;allKeep{j}=keep;counts(j)=sum(keep);
      end
      save(vp,'X','allF','allCV','allKeep','hv','sp','counts','source','-v7');
     end
    end
    status=struct('id',job.id,'ok',true,'error','');
   catch ex,status=struct('id',job.id,'ok',false,'error',getReport(ex,'extended','hyperlinks','off'));end
   P4Experiment.json(fullfile(r,'results','runs',[job.id,'_status.json']),status);
  end
 end
end
