classdef PTStudy
 methods(Static)
  function r=root()
   r=fileparts(fileparts(mfilename('fullpath')));
  end
  function c=default(seed)
   c=PTCore.config(struct('seed',seed,'mechanism','directional','principalGain',.05,'sparseRate',.2,'areaMode','progressive'));
  end
  function t=configurations()
   levels=[1 1 1 1;1 2 2 2;1 3 3 3;2 1 2 3;2 2 3 1;2 3 1 2;3 1 3 2;3 2 1 3;3 3 2 1];
   a=[.02,.05,.15];b=[.02,.1,.3];c=[.05,.2,.6];d=[3,5,10];
   t=table(["B00";compose('C%02d',(1:9)')],[.05;a(levels(:,1))'],[.02;b(levels(:,2))'],[.2;c(levels(:,3))'],[5;d(levels(:,4))'], ...
    'VariableNames',{'Config','principalGain','sigmaMin','pulseCap','window'});
  end
  function c=config(row,seed)
   c=PTStudy.default(seed);fields={'principalGain','sigmaMin','pulseCap','window'};
   for i=1:numel(fields),c.(fields{i})=row.(fields{i});end
  end
  function s=source()
   root=PTStudy.root();fs=dir(fullfile(root,'code','*.m'));s=struct();
   for i=1:numel(fs),[~,key]=fileparts(fs(i).name);s.(key)=fileread(fullfile(fs(i).folder,fs(i).name));end
   s.model=fileread(fullfile(root,'code','reference','PPaPaRModel.m'));s.protocol=fileread(fullfile(root,'PROTOCOL.md'));
  end
  function freeze()
   root=PTStudy.root();assert(~isfile(fullfile(root,'freeze.mat')));source=PTStudy.source();versionInfo=ver;stamp=char(datetime('now'));configurations=PTStudy.configurations();
   save(fullfile(root,'freeze.mat'),'source','versionInfo','stamp','configurations');writetable(configurations,fullfile(root,'data','configurations.csv'));
  end
  function jobs=jobs(phase)
   t=PTStudy.configurations();jobs=struct('phase',{},'problem',{},'variant',{},'seed',{},'config',{},'id',{});
   if strcmp(phase,'screen')
    tasks=["PPAR","ZDT4","ZDT6","DTLZ3"];repeats=5;variants=t.Config;base=910000;
   else
    tasks=["PPAR","ZDT1","ZDT2","ZDT3","ZDT4","ZDT6","DTLZ1","DTLZ2","DTLZ3"];repeats=30;variants=["Default","Tuned","Joint"];base=920000;
    selected=jsondecode(fileread(fullfile(PTStudy.root(),'selection.json')));chosen=t(t.Config==selected.config,:);
   end
   % Interleave problems so engineering work is distributed across workers.
   for v=1:numel(variants)
    for rep=1:repeats
     for k=1:numel(tasks)
      seed=base+1000*k+rep;
      if strcmp(phase,'screen'),row=t(v,:);elseif v==1,row=t(1,:);else,row=chosen;end
      c=PTStudy.config(row,seed);if variants(v)=="Joint",c.principalGain=0;c.useLock=false;end
      id=sprintf('%s_%s_%d',tasks(k),variants(v),seed);
      c.failureFile=fullfile(PTStudy.root(),'failures',[phase,'_',id,'.mat']);
      jobs(end+1)=struct('phase',phase,'problem',char(tasks(k)),'variant',char(variants(v)),'seed',seed,'config',c,'id',id); %#ok<AGROW>
     end
    end
   end
  end
  function futures=start(phase)
   root=PTStudy.root();z=load(fullfile(root,'freeze.mat'),'source');assert(isequal(z.source,PTStudy.source()));
   pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',8);end
   fs=dir(fullfile(root,'code','*.m'));files=fullfile({fs.folder},{fs.name});files{end+1}=fullfile(root,'code','reference','PPaPaRModel.m');addAttachedFiles(pool,files);
   futures=parallel.FevalFuture.empty();jobs=PTStudy.jobs(phase);PTStudy.json(fullfile(root,'results',[phase,'_plan.json']),jobs);
   for j=jobs,futures(end+1)=parfeval(pool,@PTStudy.one,1,j,root,z.source);end %#ok<AGROW>
   fprintf('Submitted %d %s searches, %.0f objective evaluations.\n',numel(jobs),phase,numel(jobs)*25100);
  end
  function status=one(job,root,source)
   path=fullfile(root,'results',job.phase,[job.id,'.mat']);status=struct('id',job.id,'ok',false,'error','');
   try
    maxNumCompThreads(1);PTTape.store('clear',[]);c=job.config;p=PTCore.problem(job.problem);
    if isfile(path)
     z=load(path,'result','source');assert(isequal(z.source,source)&&isequal(z.result.config,c));result=z.result;
    else
     result=PTCore.solve(p,'PACPO',c);result.variant=job.variant;
     assert(result.FE==25100&&isequal(result.archive,result.evaluations(result.archiveIDs,:)));
     assert(all(isfinite(result.evaluations),'all')&&all(result.evaluations(:,1:p.D)>=0,'all')&&all(result.evaluations(:,1:p.D)<=1,'all'));
     if strcmp(job.variant,'Joint'),assert(all(result.operatorTrace(:,[3,6,8])==0,'all'));end
     % Independent output rule over the entire search evaluation history.
     a=result.evaluations;ii=find(a(:,end-1)==0);ii=ii(PTFront.nd(a(ii,p.D+(1:p.M))));ii=ii(PTFront.cap(a(ii,p.D+(1:p.M))));
     [ig,hv,sp]=PTCore.metrics(p,a(ii,p.D+(1:p.M)));result.common=struct('IDs',a(ii,end),'F',a(ii,p.D+(1:p.M)),'IGD',ig,'HV',hv,'SP',sp);
     save(path,'result','source','-v7');
    end
    vp=fullfile(root,'results',job.phase,[job.id,'_fine.mat']);
    if strcmp(job.problem,'PPAR')&&~isfile(vp)
     counts=262144;if strcmp(job.phase,'validation'),counts=[262144,1048576];end
     X=result.X;fine=cell(numel(counts),1);timer=tic;
     for k=1:numel(counts)
      [F,CV,G]=PPaPaRModel.evaluate(X,PPaPaRModel.config(counts(k)));ii=find(CV==0);ii=ii(PTFront.nd(F(ii,:)));[~,hv,sp]=PTCore.metrics(p,F(ii,:));
      fine{k}=struct('count',counts(k),'F',F,'CV',CV,'G',G,'keep',ii,'HV',hv,'SP',sp,'archiveIDs',result.archiveIDs);
     end
     seconds=toc(timer);save(vp,'fine','X','seconds','-v7');
    end
    status.ok=true;
   catch ex
    status.error=getReport(ex,'extended','hyperlinks','off');
   end
   PTStudy.json(fullfile(root,'results',job.phase,[job.id,'_status.json']),status);
  end
  function t=collect(phase)
   root=PTStudy.root();jobs=PTStudy.jobs(phase);rows=cell(numel(jobs),1);
   for i=1:numel(jobs)
    j=jobs(i);st=jsondecode(fileread(fullfile(root,'results',phase,[j.id,'_status.json'])));assert(st.ok,'%s: %s',j.id,st.error);
    z=load(fullfile(root,'results',phase,[j.id,'.mat']),'result');a=z.result;
    hv=a.HV;million=NaN;if strcmp(j.problem,'PPAR'),v=load(fullfile(root,'results',phase,[j.id,'_fine.mat']),'fine');hv=v.fine{1}.HV;if numel(v.fine)>1,million=v.fine{2}.HV;end;end
    rows{i}=struct('Problem',string(j.problem),'Variant',string(j.variant),'Seed',j.seed,'FE',a.FE,'IGD',a.IGD,'HV',hv,'SearchHV',a.HV,'MillionHV',million,'SP',a.Spacing,'Seconds',a.elapsed,'CommonHV',a.common.HV,'CommonIGD',a.common.IGD, ...
     'Pulses',sum(a.gateTrace(:,5)),'HVEligible',sum(a.gateTrace(:,1)),'LowEligible',sum(a.gateTrace(:,2)),'LateSigma',mean(a.diagnostic(201:250,7)),'LateNoise',mean(a.operatorTrace(201:250,6)),'LatePulse',mean(a.operatorTrace(201:250,8)),'LateStep',mean(a.diagnostic(201:250,5)),'HV_AUC',trapz(a.history(:,2),a.history(:,3))/25000);
   end
   t=struct2table(vertcat(rows{:}));writetable(t,fullfile(root,'data',[phase,'_runs.csv']));
  end
  function selection=select()
   root=PTStudy.root();assert(~isfile(fullfile(root,'selection.json')));t=PTStudy.collect('screen');c=PTStudy.configurations();a=t(t.Problem=="PPAR",:);score=zeros(height(c),1);
   for i=1:height(c),score(i)=mean(a.HV(a.Variant==c.Config(i)));end
   ranked=sortrows(addvars(c,score,'NewVariableNames','MeanFineHV'),{'MeanFineHV','Config'},{'descend','ascend'});writetable(ranked,fullfile(root,'data','screen_engineering_ranking.csv'));
   eligible=ranked(ranked.Config~="B00",:);selection=struct('config',char(eligible.Config(1)),'meanFineHV',eligible.MeanFineHV(1),'baselineMeanFineHV',score(1),'rule','highest engineering mean fine HV among nine tested nondefault configurations','timestamp',char(datetime('now')));
   PTStudy.json(fullfile(root,'selection.json'),selection);disp(ranked);disp(selection);
  end
  function json(path,value)
   fid=fopen(path,'w','n','UTF-8');assert(fid>0);cl=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
  end
 end
end
