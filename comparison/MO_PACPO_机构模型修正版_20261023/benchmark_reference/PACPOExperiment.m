classdef PACPOExperiment
    methods (Static)
        function jobs = jobs(mode)
            jobs=struct('id',{},'study',{},'problem',{},'algorithm',{},'variant',{},'config',{});
            tasks={'ZDT1','ZDT2','ZDT3','DTLZ1','DTLZ2'};
            algorithms={'PACPO','NSGAII','MOEAD','MOPSO'};
            if ismember(mode,{'all','main','extended','demo'})
                if strcmp(mode,'extended'), tasks=[tasks,{'ZDT4','ZDT6','DTLZ3'}]; end
                runs=30; generation=250;
                if strcmp(mode,'demo'), tasks={'ZDT1','DTLZ2'}; runs=1; generation=10; end
                for p=1:numel(tasks)
                    for a=1:4
                        for r=1:runs
                            c=PACPO.config(struct('seed',100000+p*1000+r,'G',generation));
                            jobs(end+1)=PACPOExperiment.job('main',tasks{p},algorithms{a},'full',c); %#ok<AGROW>
                        end
                    end
                end
            end
            if ismember(mode,{'all','ablation'})
                tasks={'ZDT1','ZDT3','DTLZ1','DTLZ2'}; variants={'full','noPado','noLock','noEC'};
                for p=1:4
                    for v=1:4
                        for r=1:10
                            c=PACPO.config(struct('seed',200000+p*1000+r));
                            c.usePado=v~=2; c.useLock=v~=3; c.useEC=v~=4;
                            jobs(end+1)=PACPOExperiment.job('ablation',tasks{p},'PACPO',variants{v},c); %#ok<AGROW>
                        end
                    end
                end
            end
            if ismember(mode,{'all','sensitivity'})
                windows=[2,5,8,10,15]; rho=[1e-8,1e-6,1e-4,1e-2,.1];
                for parameter=1:2
                    for v=1:5
                        for r=1:5
                            c=PACPO.config(struct('seed',300000+r));
                            if parameter==1, c.window=windows(v); label=sprintf('W_%d',windows(v));
                            else, c.rho=rho(v); label=sprintf('rho_%g',rho(v)); end
                            jobs(end+1)=PACPOExperiment.job('sensitivity','ZDT3','PACPO',label,c); %#ok<AGROW>
                        end
                    end
                end
            end
            if ismember(mode,{'complete','engineering'})
                for a=1:4
                    for r=1:30
                        c=PACPO.config(struct('seed',400000+r));
                        jobs(end+1)=PACPOExperiment.job('engineering','ENGINEERING',algorithms{a},'full',c); %#ok<AGROW>
                    end
                end
            end
            if strcmp(mode,'complete'), jobs=[PACPOExperiment.jobs('all'),jobs]; end
            assert(~isempty(jobs),'PACPO:Mode','Unknown experiment mode %s',mode);
        end

        function job = job(study,problem,algorithm,variant,c)
            if ~strcmp(algorithm,'PACPO'), c.useEC=false; c.usePado=false; c.useLock=false; end
            id=sprintf('%s_%s_%s_%s_%d',study,problem,algorithm,variant,c.seed);
            job=struct('id',id,'study',study,'problem',problem,'algorithm',algorithm,'variant',variant,'config',c);
        end

        function status = one(job,out)
            file=fullfile(out,'runs',[job.id,'.mat']);
            try
                if isfile(file)
                    existing=load(file,'result');
                    assert(isequal(existing.result.config,job.config),'PACPO:ResumeMismatch','Configuration changed');
                    status=struct('id',job.id,'ok',true,'cached',true,'message',''); return;
                end
                p=PACPO.problem(job.problem); result=PACPO.solve(p,job.algorithm,job.config);
                result.job=job;
                save(file,'result','-v7');
                status=struct('id',job.id,'ok',true,'cached',false,'message','');
            catch exception
                status=struct('id',job.id,'ok',false,'cached',false,'message',getReport(exception,'extended','hyperlinks','off'));
                PACPOExperiment.json(fullfile(out,'logs',[job.id,'_error.json']),status);
            end
            PACPOExperiment.json(fullfile(out,'logs',[job.id,'_status.json']),status);
        end

        function summary = run(jobs,out,workers)
            if ~isfolder(out), mkdir(out); end
            if ~isfolder(fullfile(out,'runs')), mkdir(fullfile(out,'runs')); end
            if ~isfolder(fullfile(out,'logs')), mkdir(fullfile(out,'logs')); end
            root=fileparts(mfilename('fullpath')); freeze=fullfile(root,'code_freeze.json');
            assert(isfile(freeze),'PACPO:NotVerified','Run validation and freeze code before experiments');
            snapshot=jsondecode(fileread(freeze));
            assert(snapshot.testsPassed,'PACPO:NotVerified','Tests must pass before experiments');
            source=struct('PACPO',fileread(fullfile(root,'PACPO.m')), ...
                'PACPOExperiment',fileread(fullfile(root,'PACPOExperiment.m')));
            sourceFile=fullfile(out,'source_snapshot.mat');
            if isfile(sourceFile)
                previous=load(sourceFile,'source');
                assert(isequal(previous.source,source),'PACPO:SourceChanged','Source differs from frozen run');
            else
                save(sourceFile,'source');
            end
            PACPOExperiment.json(fullfile(out,'planned_jobs.json'),jobs);
            PACPOExperiment.json(fullfile(out,'environment.json'),struct('version',version,'computer',computer, ...
                'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')),'workers',workers,'jobs',numel(jobs)));
            timer=tic; status=cell(numel(jobs),1);
            if workers>1
                pool=gcp('nocreate');
                if isempty(pool), pool=parpool('Processes',workers); end
                workers=min(workers,pool.NumWorkers);
                queue=parallel.pool.DataQueue; afterEach(queue,@(s)fprintf('%s %s\n',s.id,string(s.ok)));
                parfor (i=1:numel(jobs),workers)
                    status{i}=PACPOExperiment.one(jobs(i),out); send(queue,status{i});
                end
            else
                for i=1:numel(jobs)
                    status{i}=PACPOExperiment.one(jobs(i),out); fprintf('%d/%d %s\n',i,numel(jobs),jobs(i).id);
                end
            end
            summary=struct('jobs',numel(jobs),'passed',sum(cellfun(@(x)x.ok,status)), ...
                'seconds',toc(timer),'status',{status});
            PACPOExperiment.json(fullfile(out,'run_completion.json'),summary);
            assert(summary.passed==summary.jobs,'PACPO:RunFailures','Some runs failed; inspect logs');
        end

        function json(file,value)
            fid=fopen(file,'w','n','UTF-8'); assert(fid~=-1,'PACPO:File','Cannot write %s',file);
            cleanup=onCleanup(@()fclose(fid));
            fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
        end
    end
end
