classdef P5Experiment
 methods(Static)
  function r=root(value)
   persistent sharedRoot
   if nargin>0,sharedRoot=value;end
   if isempty(sharedRoot),sharedRoot=fileparts(fileparts(mfilename('fullpath')));end
   r=sharedRoot;
  end
  function s=source()
   r=P5Experiment.root();s=struct();
   for n=["Core","Mechanism","Pulse","Variants","Experiment","Tape","Stats"]
    s.("P5"+n)=fileread(fullfile(r,'code',"P5"+n+".m"));
   end
   s.model=fileread(fullfile(r,'code','reference','PPaPaRModel.m'));s.protocol=fileread(fullfile(r,'PROTOCOL.md'));
  end
  function jobs=jobs()
   jobs=struct('problem',{},'mode',{},'seed',{},'id',{});
   for mode=["joint","Full","noNoise","noLock"]
    for task=["PPAR","ZDT6","DTLZ3"]
     if task=="PPAR",base=400000;elseif task=="ZDT6",base=812000;else,base=813000;end
     for seed=base+(1:30)
      jobs(end+1)=struct('problem',char(task),'mode',char(mode),'seed',seed,'id',sprintf('%s_%s_%d',task,mode,seed)); %#ok<AGROW>
     end
    end
   end
  end
  function [path,vpath]=origin(job)
   base=fileparts(P5Experiment.root());p1=fullfile(base,'MO_PACPO_P1修正版_20261024');p3=fullfile(base,'MO_PACPO_机构消融与P1修订_20261024');
   mode=job.mode;if strcmp(mode,'Full'),mode='revised';end
   id=sprintf('%s_%s_%d.mat',job.problem,mode,job.seed);vpath='';
   if strcmp(job.problem,'PPAR') && ~strcmp(mode,'noLock')
    path=fullfile(p3,'results','runs',id);vpath=fullfile(p3,'validation',id);
   else
    path=fullfile(p1,'results','runs',id);
    if ~isfile(path) && strcmp(mode,'revised')
     path=fullfile(base,'MO_PACPO_创新性对照修订_20261025','results','runs',sprintf('%s_DL_%d.mat',job.problem,job.seed));
    end
    if ~isfile(path) && ismember(mode,{'noNoise','noLock'})
     legacyName=['candidate',upper(mode(1)),mode(2:end)];
     path=fullfile(base,'MO_PACPO_搜索机制改进_20261024','results','external_ablation',sprintf('%s_%s_%d.mat',job.problem,legacyName,job.seed));
    end
    if strcmp(job.problem,'PPAR'),vpath=fullfile(p1,'validation',sprintf('archive_noLock_%d.mat',job.seed));end
   end
  end
  function freeze()
   r=P5Experiment.root();assert(~isfile(fullfile(r,'freeze.mat')));source=P5Experiment.source();versionInfo=ver;stamp=char(datetime('now'));
   save(fullfile(r,'freeze.mat'),'source','versionInfo','stamp');P5Experiment.json(fullfile(r,'results','plan.json'),P5Experiment.jobs());
  end
  function futures=start()
   r=P5Experiment.root();z=load(fullfile(r,'freeze.mat'),'source');assert(isequal(z.source,P5Experiment.source()));
   pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',8);end
   ff=dir(fullfile(r,'code','*.m'));paths=fullfile({ff.folder},{ff.name});paths{end+1}=fullfile(r,'code','reference','PPaPaRModel.m');addAttachedFiles(pool,paths);
   futures=parallel.FevalFuture.empty();jobs=P5Experiment.jobs();
   for j=jobs,futures(end+1)=parfeval(pool,@P5Experiment.one,1,j,z.source,r);end %#ok<AGROW>
   fprintf('Submitted 90 new searches and 270 exact replays.\n');
  end
  function result=replay(job)
   [origin,~]=P5Experiment.origin(job);z=load(origin,'result');
   P5Tape.store('set',z.result.evaluations);cl=onCleanup(@()P5Tape.store('clear',[]));
   result=P5Core.solve(P5Core.problem(job.problem),'PACPO',P5Variants.config(job.mode,job.seed));
   for f=["evaluations","history","archive","population","X","F","CV","HV","Spacing"]
    assert(isequaln(result.(f),z.result.(f)),'P5:ReplayMismatch','%s differs: %s',job.id,f);
   end
   assert(P5Tape.store('count',[])==25100);result.replaySeconds=result.elapsed;result.elapsed=z.result.elapsed;
   result.sourceKind='reused_with_exact_replay';result.origin=origin;
  end
  function status=one(job,source,sharedRoot)
   r=P5Experiment.root(sharedRoot);path=fullfile(r,'results','runs',[job.id,'.mat']);
   try
    maxNumCompThreads(1);assert(isequal(source,P5Experiment.source()));P5Tape.store('clear',[]);c=P5Variants.config(job.mode,job.seed);p=P5Core.problem(job.problem);
    if isfile(path)
     z=load(path,'source','result');assert(isequal(z.source,source)&&isequal(z.result.config,c));result=z.result;
    else
     if strcmp(job.mode,'joint'),result=P5Core.solve(p,'PACPO',c);result.sourceKind='new_search';
     else,result=P5Experiment.replay(job);end
     result.variant=job.mode;assert(result.FE==25100&&isequal(result.archive,result.evaluations(result.archiveIDs,:)));
     if strcmp(job.mode,'joint'),assert(all(result.operatorTrace(:,[3,6,8])==0,'all')&&all(result.history(:,4)==0));end
     save(path,'result','source','-v7');
    end
    if strcmp(job.problem,'PPAR')
     vp=fullfile(r,'validation',[job.id,'.mat']);
     if ~isfile(vp)
      if strcmp(job.mode,'joint')
       X=result.X;allF=cell(2,1);allCV=allF;allKeep=allF;hv=zeros(2,1);sp=hv;counts=hv;
       for j=1:2
        [f,cv]=PPaPaRModel.evaluate(X,PPaPaRModel.config(262144*4^(j-1)));keep=cv==0&~any(P5Core.dominance(f,cv),1)';
        [~,hv(j),sp(j)]=P5Core.metrics(p,f(keep,:));allF{j}=f;allCV{j}=cv;allKeep{j}=keep;counts(j)=sum(keep);
       end
       save(vp,'X','allF','allCV','allKeep','hv','sp','counts','source','-v7');
      else
       [~,vo]=P5Experiment.origin(job);v=load(vo);assert(isequal(v.X,result.X));v.source=source;v.origin=vo;save(vp,'-struct','v','-v7');
      end
     end
    end
    status=struct('id',job.id,'ok',true,'error','','kind',result.sourceKind);
   catch ex,status=struct('id',job.id,'ok',false,'error',getReport(ex,'extended','hyperlinks','off'));end
   P5Experiment.json(fullfile(r,'results','runs',[job.id,'_status.json']),status);
  end
  function json(path,value)
   fid=fopen(path,'w','n','UTF-8');assert(fid>0);cl=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
  end
 end
end
