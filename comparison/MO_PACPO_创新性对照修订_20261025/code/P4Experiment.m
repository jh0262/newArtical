classdef P4Experiment
 methods(Static)
  function r=root(value)
   persistent sharedRoot
   if nargin>0,sharedRoot=value;end
   if isempty(sharedRoot),sharedRoot=fileparts(fileparts(mfilename('fullpath')));end
   r=sharedRoot;
  end
  function s=source()
   r=P4Experiment.root();s=struct();
   for name=["P4Core","P4Mechanism","P4Pulse","P4Variants","P4Experiment","P4Tape"]
    s.(name)=fileread(fullfile(r,'code',name+".m"));
   end
   s.PPaPaRModel=fileread(fullfile(r,'code','reference','PPaPaRModel.m'));s.protocol=fileread(fullfile(r,'PROTOCOL.md'));
  end
  function jobs=jobs()
   jobs=struct('problem',{},'mode',{},'seed',{},'id',{});
   tasks=["PPAR","ZDT1","ZDT2","ZDT3","DTLZ1","DTLZ2","ZDT4","ZDT6","DTLZ3"];
   for k=1:9
    if k==1,base=400000;elseif k<=6,base=710000+1000*(k-1);else,base=810000+1000*(k-6);end
    for seed=base+(1:30)
     for mode=["DR","SL","SR"]
      jobs(end+1)=struct('problem',char(tasks(k)),'mode',char(mode),'seed',seed,'id',sprintf('%s_%s_%d',tasks(k),mode,seed)); %#ok<AGROW>
     end
    end
   end
  end
  function freeze()
   r=P4Experiment.root();assert(~isfile(fullfile(r,'freeze.mat')));
   source=P4Experiment.source();versionInfo=ver;stamp=char(datetime('now'));
   save(fullfile(r,'freeze.mat'),'source','versionInfo','stamp');
   P4Experiment.json(fullfile(r,'results','plan.json'),P4Experiment.jobs());
  end
  function futures=start()
   r=P4Experiment.root();z=load(fullfile(r,'freeze.mat'),'source');assert(isequal(z.source,P4Experiment.source()));
   pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',8);end
   ff=dir(fullfile(r,'code','*.m'));paths=fullfile({ff.folder},{ff.name});paths{end+1}=fullfile(r,'code','reference','PPaPaRModel.m');addAttachedFiles(pool,paths);
   jobs=P4Experiment.jobs();futures=parallel.FevalFuture.empty();
   for k=1:numel(jobs)
    futures(end+1)=parfeval(pool,@P4Experiment.one,1,jobs(k),z.source,r); %#ok<AGROW>
   end
   fprintf('Submitted %d searches.\n',numel(jobs));
  end
  function status=one(job,source,sharedRoot)
   r=P4Experiment.root(sharedRoot);path=fullfile(r,'results','runs',[job.id,'.mat']);
   try
    maxNumCompThreads(1);assert(isequal(source,P4Experiment.source()));P4Tape.store('clear',[]);
    c=P4Variants.config(job.mode,job.seed);p=P4Core.problem(job.problem);
    if isfile(path)
     z=load(path,'source','result');assert(isequal(z.source,source)&&isequal(z.result.config,c));result=z.result;
    else
     result=P4Core.solve(p,'PACPO',c);result.variant=job.mode;
     assert(result.FE==25100&&isequal(result.archive,result.evaluations(result.archiveIDs,:)));
     save(path,'result','source','-v7');
    end
    if strcmp(job.problem,'PPAR')
     fp=fullfile(r,'validation',[job.id,'.mat']);
     if ~isfile(fp)
      X=result.X;allF=cell(2,1);allCV=allF;allKeep=allF;hv=zeros(2,1);sp=hv;counts=hv;
      for j=1:2
       [f,cv]=PPaPaRModel.evaluate(X,PPaPaRModel.config(262144*4^(j-1)));keep=cv==0&~any(P4Core.dominance(f,cv),1)';
       [~,hv(j),sp(j)]=P4Core.metrics(p,f(keep,:));allF{j}=f;allCV{j}=cv;allKeep{j}=keep;counts(j)=sum(keep);
      end
      save(fp,'X','allF','allCV','allKeep','hv','sp','counts','source','-v7');
     end
    end
    status=struct('id',job.id,'ok',true,'error','');
   catch ex
    status=struct('id',job.id,'ok',false,'error',getReport(ex,'extended','hyperlinks','off'));
   end
   P4Experiment.json(fullfile(r,'results','runs',[job.id,'_status.json']),status);
  end
  function json(path,value)
   fid=fopen(path,'w','n','UTF-8');assert(fid>0);cl=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
  end
 end
end
