classdef PhysicalExperiment
    methods (Static)
        function jobs=jobs()
            jobs=struct('id',{},'algorithm',{},'config',{}); algorithms={'PACPO','NSGAII','MOEAD','MOPSO'};
            for a=1:4
                for r=1:30
                    c=PACPOPhysical.config(struct('seed',400000+r));
                    if a>1, c.usePado=false; c.useLock=false; c.useEC=false; end
                    jobs(end+1)=struct('id',sprintf('physical_%s_%d',algorithms{a},c.seed), ...
                        'algorithm',algorithms{a},'config',c); %#ok<AGROW>
                end
            end
        end
        function status=one(job,out,p)
            file=fullfile(out,'runs',[job.id,'.mat']);
            try
                if isfile(file)
                    z=load(file,'result'); assert(isequal(z.result.config,job.config),'Resume configuration mismatch');
                    status=struct('id',job.id,'ok',true,'cached',true,'message',''); return;
                end
                result=PACPOPhysical.solve(p,job.algorithm,job.config); result.job=job;
                save(file,'result','-v7');
                status=struct('id',job.id,'ok',true,'cached',false,'message','');
            catch ex
                status=struct('id',job.id,'ok',false,'cached',false,'message',getReport(ex,'extended','hyperlinks','off'));
            end
            PhysicalExperiment.json(fullfile(out,'logs',[job.id,'.json']),status);
        end
        function summary=run(out,workers)
            root=fileparts(mfilename('fullpath'));
            freeze=jsondecode(fileread(fullfile(root,'code_freeze.json')));
            assert(freeze.testsPassed,'Code has not passed verification');
            if ~isfolder(out), mkdir(out); end
            if ~isfolder(fullfile(out,'runs')), mkdir(fullfile(out,'runs')); end
            if ~isfolder(fullfile(out,'logs')), mkdir(fullfile(out,'logs')); end
            source=struct(); names={'PACPOPhysical','PPaPaRModel','PhysicalExperiment'};
            for i=1:numel(names), source.(names{i})=fileread(fullfile(root,[names{i},'.m'])); end
            assert(isequal(source,freeze.source),'Frozen code changed');
            p=PACPOPhysical.problem('PPAR'); jobs=PhysicalExperiment.jobs();
            save(fullfile(out,'configuration.mat'),'p','source','jobs');
            PhysicalExperiment.json(fullfile(out,'planned_jobs.json'),jobs);
            PhysicalExperiment.json(fullfile(out,'environment.json'),struct('version',version, ...
                'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')),'workers',workers));
            pool=gcp('nocreate'); if isempty(pool), pool=parpool('Processes',workers); end
            queue=parallel.pool.DataQueue; afterEach(queue,@(s)fprintf('%s completed=%d\n',s.id,s.ok));
            timer=tic; status=cell(numel(jobs),1);
            parfor (i=1:numel(jobs),min(workers,pool.NumWorkers))
                maxNumCompThreads(1); %#ok<MNCT>
                status{i}=PhysicalExperiment.one(jobs(i),out,p); send(queue,status{i});
            end
            summary=struct('runs',numel(jobs),'passed',sum(cellfun(@(s)s.ok,status)), ...
                'seconds',toc(timer),'status',{status});
            PhysicalExperiment.json(fullfile(out,'completion.json'),summary);
            assert(summary.passed==numel(jobs),'Some physical runs failed');
        end
        function json(file,obj)
            fid=fopen(file,'w','n','UTF-8'); assert(fid>0); clean=onCleanup(@()fclose(fid));
            fprintf(fid,'%s',jsonencode(obj,'PrettyPrint',true));
        end
    end
end
