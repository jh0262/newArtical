classdef SearchExperiment
    % Frozen, resumable experiments. Each job records raw evaluations and source.
    methods (Static)
        function root=root()
            root=fileparts(mfilename('fullpath'));
        end
        function s=source()
            root=SearchExperiment.root();names={'PACPOSearch','SearchMechanism','SearchVariants','SearchExperiment'};s=struct();
            for i=1:numel(names),s.(names{i})=fileread(fullfile(root,[names{i},'.m']));end
            s.PPaPaRModel=fileread(fullfile(root,'reference','PPaPaRModel.m'));
        end
        function freeze()
            root=SearchExperiment.root();z=load(fullfile(root,'results','preconfirm_tests.mat'),'t');
            assert(all([z.t.Passed]) && ~any([z.t.Incomplete]),'Search:Tests','Tests have not passed');
            source=SearchExperiment.source();candidate=SearchVariants.config('candidate',1);
            versionInfo=ver;stamp=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            file=fullfile(root,'freeze.mat');assert(~isfile(file),'Search:Frozen','Freeze already exists');
            save(file,'source','candidate','versionInfo','stamp');
            SearchExperiment.json(fullfile(root,'freeze.json'),struct('stamp',stamp,'testsPassed',numel(z.t), ...
                'candidate',candidate,'version',version,'comparabilityProtocol','PROTOCOL.md'));
        end
        function jobs=jobs(phase)
            tasks={'ZDT1','ZDT2','ZDT3','DTLZ1','DTLZ2'};modes={'candidate','legacy','NSGAII','MOEAD','MOPSO'};base=710000;
            switch phase
                case 'confirmation'
                case 'external',tasks={'ZDT4','ZDT6','DTLZ3'};base=810000;
                case 'ablation',modes={'candidateDiagonal','candidateNoNoise','candidateNoLock','candidateNoEC','candidateFixed'};
                case 'physical',tasks={'PPAR'};modes={'candidate'};base=399000;
                otherwise,error('Search:Phase','Unknown phase');
            end
            jobs=struct('problem',{},'mode',{},'seed',{},'id',{});
            for k=1:numel(tasks)
                for r=1:30
                    for v=1:numel(modes)
                        seed=base+1000*k+r;
                        jobs(end+1)=struct('problem',tasks{k},'mode',modes{v},'seed',seed, ...
                            'id',sprintf('%s_%s_%d',tasks{k},modes{v},seed)); %#ok<AGROW>
                    end
                end
            end
        end
        function futures=start(phase)
            root=SearchExperiment.root();addpath(root,fullfile(root,'reference'));
            freeze=load(fullfile(root,'freeze.mat'),'source');source=SearchExperiment.source();
            assert(isequal(source,freeze.source),'Search:Changed','Frozen solver/runner changed');
            jobs=SearchExperiment.jobs(phase);folder=fullfile(root,'results',phase);
            if ~isfolder(folder),mkdir(folder);end
            save(fullfile(folder,'plan.mat'),'jobs','source');
            SearchExperiment.json(fullfile(folder,'plan.json'),jobs);
            pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',8);end
            updateAttachedFiles(pool);
            SearchExperiment.json(fullfile(folder,'environment.json'),struct('version',version,'computer',computer, ...
                'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')),'workers',pool.NumWorkers));
            futures=parallel.FevalFuture.empty(0,numel(jobs));
            for i=1:numel(jobs),futures(i)=parfeval(pool,@SearchExperiment.one,1,jobs(i),folder,source);end
            fprintf('Submitted %s: %d runs.\n',phase,numel(jobs));
        end
        function status=one(job,folder,source)
            path=fullfile(folder,[job.id,'.mat']);
            try
                maxNumCompThreads(1);
                c=SearchVariants.config(job.mode,job.seed);
                if ismember(job.mode,{'NSGAII','MOEAD','MOPSO'}),algorithm=job.mode;else,algorithm='PACPO';end
                if isfile(path)
                    z=load(path,'result','source');result=z.result;
                    assert(isequal(z.source,source) && isequal(result.config,c),'Search:Cache','Cached source/config mismatch');
                else
                    assert(isequal(SearchExperiment.source(),source),'Search:Worker','Worker code mismatch');
                    result=PACPOSearch.solve(PACPOSearch.problem(job.problem),algorithm,c);result.variant=job.mode;
                    assert(result.FE==25100 && size(result.evaluations,1)==25100,'Search:Budget','Incorrect FE');
                    assert(isequal(result.archive,result.evaluations(result.archiveIDs,:)),'Search:Trace','Archive trace failed');
                    save(path,'result','source','-v7');
                end
                status=struct('id',job.id,'ok',true,'message','');
            catch ex
                status=struct('id',job.id,'ok',false,'message',getReport(ex,'extended','hyperlinks','off'));
            end
            SearchExperiment.json(fullfile(folder,[job.id,'_status.json']),status);
        end
        function collect(phase)
            root=SearchExperiment.root();folder=fullfile(root,'results',phase);z=load(fullfile(folder,'plan.mat'));
            jobs=z.jobs;rows=cell(numel(jobs),1);histories=zeros(251,numel(jobs));diagnostics=zeros(250,8,numel(jobs));
            for i=1:numel(jobs)
                s=jsondecode(fileread(fullfile(folder,[jobs(i).id,'_status.json'])));assert(s.ok,s.message);
                zrun=load(fullfile(folder,[jobs(i).id,'.mat']),'result','source');r=zrun.result;
                assert(isequal(zrun.source,z.source),'Search:Source','Source mismatch');
                assert(r.FE==25100 && isequal(r.archive,r.evaluations(r.archiveIDs,:)),'Search:Audit','Audit failure');
                rows{i}=table(string(jobs(i).problem),string(jobs(i).mode),r.seed,r.IGD,r.HV,r.Spacing,r.FE,r.elapsed, ...
                    sum(r.history(:,4)),'VariableNames',{'Problem','Variant','Seed','IGD','HV','SP','FE','Seconds','Pulses'});
                histories(:,i)=r.history(:,3);diagnostics(:,:,i)=r.diagnostic;
            end
            runs=vertcat(rows{:});writetable(runs,fullfile(folder,'runs.csv'));
            summary=groupsummary(runs,{'Problem','Variant'},{'mean','std','median'},{'IGD','HV','SP','Seconds','Pulses'});
            writetable(summary,fullfile(folder,'summary.csv'));save(fullfile(folder,'aggregate.mat'),'runs','summary','histories','diagnostics');
            SearchExperiment.json(fullfile(folder,'completion.json'),struct('passed',height(runs),'FE',sum(runs.FE),'phase',phase));
            disp(summary(:,{'Problem','Variant','mean_IGD','mean_HV','mean_Pulses'}));
        end
        function run(phase)
            futures=SearchExperiment.start(phase);wait(futures);SearchExperiment.collect(phase);
        end
        function json(path,value)
            fid=fopen(path,'w','n','UTF-8');assert(fid>0);cleanup=onCleanup(@()fclose(fid));
            fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
        end
    end
end
