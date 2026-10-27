classdef P4ReplayDL
 methods(Static)
  function out=all(sharedRoot)
   r=P4Experiment.root(sharedRoot);
   old=fullfile(fileparts(r),'MO_PACPO_搜索机制改进_20261024');p1=fullfile(fileparts(r),'MO_PACPO_P1修正版_20261024');p3=fullfile(fileparts(r),'MO_PACPO_机构消融与P1修订_20261024');
   jobs=P4Experiment.jobs();jobs=jobs(strcmp({jobs.mode},'DR'));source=P4Experiment.source();n=0;
   for j=jobs
    id=sprintf('%s_DL_%d',j.problem,j.seed);path=fullfile(r,'results','runs',[id,'.mat']);
    try
     if strcmp(j.problem,'PPAR')
      origin=fullfile(p3,'results','runs',sprintf('PPAR_revised_%d.mat',j.seed));
     else
      origin=fullfile(p1,'results','runs',sprintf('%s_revised_%d.mat',j.problem,j.seed));
      if ~isfile(origin)
       phase='confirmation';if ismember(j.problem,{'ZDT4','ZDT6','DTLZ3'}),phase='external';end
       origin=fullfile(old,'results',phase,sprintf('%s_candidate_%d.mat',j.problem,j.seed));
      end
     end
     z=load(origin,'result');p=P4Core.problem(j.problem);c=P4Variants.config('DL',j.seed);
     if isfile(path)
      a=load(path,'result','source');assert(isequal(a.source,source));result=a.result;
     else
      P4Tape.store('set',z.result.evaluations);cl=onCleanup(@()P4Tape.store('clear',[]));
      result=P4Core.solve(p,'PACPO',c);result.variant='DL';result.sourceKind='reused_with_exact_tape_replay';result.original=origin;
      for field=["evaluations","history","population","archive","X","F","CV","HV","Spacing"]
       assert(isequaln(result.(field),z.result.(field)),'P4:Replay','%s differs in %s',id,field);
      end
      result.replaySeconds=result.elapsed;result.elapsed=z.result.elapsed;
      if strcmp(j.problem,'PPAR')
       timing=load(fullfile(old,'results','physical',sprintf('PPAR_candidate_%d.mat',j.seed)),'result');result.elapsed=timing.result.elapsed;
      end
      clear cl;save(path,'result','source','origin','-v7');
     end
     if strcmp(j.problem,'PPAR')
      v=load(fullfile(p3,'validation',sprintf('PPAR_revised_%d.mat',j.seed)));assert(isequal(v.X,result.X));v.source=source;save(fullfile(r,'validation',[id,'.mat']),'-struct','v','-v7');
     end
     status=struct('id',id,'ok',true,'error','','replay',true);n=n+1;
    catch ex,status=struct('id',id,'ok',false,'error',getReport(ex,'extended','hyperlinks','off'),'replay',true);end
    P4Experiment.json(fullfile(r,'results','runs',[id,'_status.json']),status);
   end
   out=struct('replayed',n,'planned',numel(jobs));
  end
 end
end
