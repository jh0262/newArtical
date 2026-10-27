classdef ERStudy
 methods(Static)
 function r=root(),r=fileparts(fileparts(mfilename('fullpath')));end
 function ids=variants(),ids=["N11","N12","N13","N21","B","N23","N31","N32","N33","W2","W10","C005","W2C005"];end
 function c=config(id,seed)
  c=ERCore.config(struct('seed',seed,'mechanism','directional','principalGain',.05,'sparseRate',.2,'areaMode','progressive'));
  assert(ismember(string(id),ERStudy.variants()));
  if startsWith(id,'N'),eta=[.025,.05,.10];sm=[.005,.02,.05];c.principalGain=eta(str2double(extractBetween(string(id),2,2)));c.sigmaMin=sm(str2double(extractBetween(string(id),3,3)));end
  if ismember(string(id),["W2","W2C005"]),c.window=2;end
  if strcmp(id,'W10'),c.window=10;end
  if ismember(string(id),["C005","W2C005"]),c.pulseCap=.005;end
 end
 function s=source()
  r=ERStudy.root();fs=dir(fullfile(r,'code','*.m'));s=struct();
  for i=1:numel(fs),[~,key]=fileparts(fs(i).name);s.(key)=fileread(fullfile(fs(i).folder,fs(i).name));end
  s.model=fileread(fullfile(r,'code/reference/PPaPaRModel.m'));s.protocol=fileread(fullfile(r,'PROTOCOL.md'));s.targets=fileread(fullfile(r,'data/targets.json'));
 end
 function freeze()
  root=ERStudy.root();assert(~isfile(fullfile(root,'freeze.mat')));source=ERStudy.source();versionInfo=ver;stamp=char(datetime('now'));save(fullfile(root,'freeze.mat'),'source','versionInfo','stamp');
 end
 function jobs=jobs(phase)
  ids=ERStudy.variants();n=16;bases=[941000,942000];
  if strcmp(phase,'confirm'),v=jsondecode(fileread(fullfile(ERStudy.root(),'data/selection.json')));ids=["B",string(v.candidates(:)')];n=30;bases=[951000,952000];end
  jobs=struct('phase',{},'problem',{},'variant',{},'seed',{},'id',{});tasks=["PPAR","DTLZ3"];
  for k=1:2
   for rep=1:n
    % Rotate submission order to spread parameter groups across run times.
    order=circshift(ids,mod(rep-1,numel(ids)));
    for id=order,seed=bases(k)+rep;jobs(end+1)=struct('phase',phase,'problem',char(tasks(k)),'variant',char(id),'seed',seed,'id',sprintf('%s_%s_%d',tasks(k),id,seed));end %#ok<AGROW>
   end
  end
 end
 function futures=start(phase)
  root=ERStudy.root();z=load(fullfile(root,'freeze.mat'));assert(isequal(z.source,ERStudy.source()));
  pool=gcp('nocreate');if isempty(pool),cl=parcluster('Processes');pool=parpool(cl,8);end
  ff=dir(fullfile(root,'code','*.m'));files=fullfile({ff.folder},{ff.name});files{end+1}=fullfile(root,'code/reference/PPaPaRModel.m');addAttachedFiles(pool,files);
  jobs=ERStudy.jobs(phase);ERStudy.json(fullfile(root,'data',[phase,'_plan.json']),jobs);futures=parallel.FevalFuture.empty();
  for j=jobs
   fp=fullfile(root,'results',phase,[j.id,'_status.json']);
   if isfile(fp),st=jsondecode(fileread(fp));if st.ok,continue;end;end
   futures(end+1)=parfeval(pool,@ERStudy.one,1,j,root,z.source); %#ok<AGROW>
  end
  fprintf('Submitted %d %s jobs\n',numel(futures),phase);
 end
 function st=one(j,root,source)
  path=fullfile(root,'results',j.phase,[j.id,'.mat']);st=struct('id',j.id,'ok',false,'error','');
  try
   maxNumCompThreads(1);ERTape.store('clear',[]);p=ERCore.problem(j.problem);c=ERStudy.config(j.variant,j.seed);
   c.failureFile=fullfile(root,'failures',[j.phase,'_',j.id,'.mat']);
   if isfile(path),z=load(path);assert(isequal(z.source,source)&&isequal(z.result.config,c));result=z.result;
   else
    result=ERCore.solve(p,'PACPO',c);assert(result.FE==25100&&size(result.evaluations,1)==25100);result.variant=j.variant;result.phase=j.phase;result.kind='new_search';result.newSearchFE=25100;save(path,'result','source','-v7');
   end
   finePath=fullfile(root,'results',j.phase,[j.id,'_fine.mat']);
   if strcmp(j.problem,'PPAR')&&~isfile(finePath)
    fine=cell(2,1);X=result.X;timer=tic;
    for k=1:2
     count=262144*4^(k-1);[F,CV,G]=PPaPaRModel.evaluate(X,PPaPaRModel.config(count));ii=find(CV==0);ii=ii(ERFront.nd(F(ii,:)));[~,hv,sp]=ERCore.metrics(p,F(ii,:));fine{k}=struct('count',count,'F',F,'CV',CV,'G',G,'keep',ii,'HV',hv,'SP',sp,'archiveIDs',result.archiveIDs);
    end
    seconds=toc(timer);newFinalFE=size(X,1)*2;save(finePath,'fine','X','seconds','newFinalFE','-v7');
   end
   st.ok=true;
  catch ex,st.error=getReport(ex,'extended','hyperlinks','off');end
  ERStudy.json(fullfile(root,'results',j.phase,[j.id,'_status.json']),st);
 end
 function json(path,value)
  f=fopen(path,'w','n','UTF-8');assert(f>0);close=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(value,'PrettyPrint',true));
 end
 end
end
