classdef P1Experiment
    methods (Static)
        function root=root(),root=fileparts(mfilename('fullpath'));end
        function s=source()
            root=P1Experiment.root();names={'PACPOP1','P1Mechanism','P1Variants','P1GDE3','P1Experiment'};s=struct();
            for i=1:numel(names),s.(names{i})=fileread(fullfile(root,[names{i},'.m']));end
            s.PPaPaRModel=fileread(fullfile(root,'reference','PPaPaRModel.m'));
        end
        function freeze()
            root=P1Experiment.root();assert(~isfile(fullfile(root,'freeze.mat')));
            t=runtests(fullfile(root,'tests'));assertSuccess(t);P1Stats.corrected_old();
            source=P1Experiment.source();stamp=char(datetime('now'));versionInfo=ver;
            save(fullfile(root,'freeze.mat'),'source','t','stamp','versionInfo');
            P1Experiment.json(fullfile(root,'freeze.json'),struct('testsPassed',sum([t.Passed]),'timestamp',stamp,'version',version));
        end
        function jobs=jobs()
            jobs=struct('problem',{},'mode',{},'seed',{},'id',{});
            % Physical work starts first; benchmark jobs follow on the same pool.
            for r=1:30
                for mode=["noLock","GDE3"]
                    jobs(end+1)=P1Experiment.job('PPAR',char(mode),400000+r); %#ok<AGROW>
                end
            end
            tasks={'ZDT1','ZDT2','ZDT3','DTLZ1','DTLZ2','ZDT4','ZDT6','DTLZ3'};
            for k=1:8
                if k<=5,base=710000+1000*k;else,base=810000+1000*(k-5);end
                for r=1:30
                    for mode=["revised","Diagonal","noNoise","noLock","Fixed","GDE3"]
                        % Three-objective PACPO results are unchanged: reuse frozen runs.
                        if ismember(k,[4,5,8]) && mode~="GDE3",continue;end
                        jobs(end+1)=P1Experiment.job(tasks{k},char(mode),base+r); %#ok<AGROW>
                    end
                end
            end
        end
        function j=job(task,mode,seed)
            j=struct('problem',task,'mode',mode,'seed',seed,'id',sprintf('%s_%s_%d',task,mode,seed));
        end
        function f=start()
            root=P1Experiment.root();addpath(root,fullfile(root,'reference'));
            z=load(fullfile(root,'freeze.mat'),'source');source=P1Experiment.source();assert(isequal(z.source,source));
            jobs=P1Experiment.jobs();save(fullfile(root,'results','plan.mat'),'jobs','source');P1Experiment.json(fullfile(root,'results','plan.json'),jobs);
            pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',8);end
            addAttachedFiles(pool,{fullfile(root,'PACPOP1.m'),fullfile(root,'P1Mechanism.m'),fullfile(root,'P1Variants.m'),fullfile(root,'P1GDE3.m'),fullfile(root,'P1Experiment.m'),fullfile(root,'reference','PPaPaRModel.m')});
            f=parallel.FevalFuture.empty(0,numel(jobs));
            for i=1:numel(jobs),f(i)=parfeval(pool,@P1Experiment.one,1,jobs(i),source);end
            fprintf('Submitted %d jobs.\n',numel(jobs));
        end
        function status=one(job,source)
            root=P1Experiment.root();folder=fullfile(root,'results','runs');if ~isfolder(folder),mkdir(folder);end
            path=fullfile(folder,[job.id,'.mat']);
            try
                maxNumCompThreads(1);c=P1Variants.config(job.mode,job.seed);assert(isequal(source,P1Experiment.source()));
                if isfile(path)
                    z=load(path,'result','source');assert(isequal(z.source,source)&&isequal(z.result.config,c));
                else
                    p=PACPOP1.problem(job.problem);
                    if strcmp(job.mode,'GDE3'),result=P1GDE3.solve(p,c);else,result=PACPOP1.solve(p,'PACPO',c);end
                    result.variant=job.mode;assert(result.FE==25100&&isequal(result.archive,result.evaluations(result.archiveIDs,:)));
                    save(path,'result','source','-v7');
                end
                status=struct('id',job.id,'ok',true,'error','');
            catch ex
                status=struct('id',job.id,'ok',false,'error',getReport(ex,'extended','hyperlinks','off'));
            end
            P1Experiment.json(fullfile(folder,[job.id,'_status.json']),status);
        end
        function json(path,value)
            fid=fopen(path,'w','n','UTF-8');assert(fid>0);cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
        end
    end
end
