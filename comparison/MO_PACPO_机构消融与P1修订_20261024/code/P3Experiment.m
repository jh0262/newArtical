classdef P3Experiment
    methods (Static)
        function r=root(value)
            persistent sharedRoot
            if nargin>0,sharedRoot=value;end
            if isempty(sharedRoot),sharedRoot=fileparts(fileparts(mfilename('fullpath')));end
            r=sharedRoot;
        end
        function s=source()
            r=P3Experiment.root();ff=dir(fullfile(r,'code','*.m'));s=struct();
            for k=1:numel(ff),[~,n]=fileparts(ff(k).name);s.(n)=fileread(fullfile(ff(k).folder,ff(k).name));end
            s.PPaPaRModel=fileread(fullfile(r,'code','reference','PPaPaRModel.m'));s.protocol=fileread(fullfile(r,'PROTOCOL.md'));
        end
        function verify()
            r=P3Experiment.root();old=fullfile(fileparts(r),'MO_PACPO_P1修正版_20261024');addpath(old);P3Tape.store('clear',[]);
            z=load(fullfile(old,'results','runs','PPAR_noLock_400001.mat'),'result');p=P3Core.problem('PPAR');rows={};
            for mode=["revised","Diagonal","noNoise"]
                c=P3Variants.config(mode,400001);cp=P1Variants.config(mode,400001);assert(isequal(c,cp));
                for stagnation=[0,100]
                    pop=z.result.population;archive=z.result.archive;
                    % Force low covariance dimension to exercise the conditional pulse.
                    archive(:,1)=mean(archive(:,1));st=struct('sigma',.5,'success',.2);
                    rng(191,'twister');[a,sa,pa,la]=P1Mechanism.propose(p,pop,archive,c,st,1,stagnation);ra=rng;
                    rng(191,'twister');[b,sb,pb,lb]=P3Mechanism.propose(p,pop,archive,c,st,1,stagnation);rb=rng;
                    assert(isequal(a,b)&&isequal(ra,rb)&&isequal(pa,pb)&&isequal(la,lb));sb=rmfield(sb,'components');assert(isequal(sa,sb));
                    if stagnation==100,assert(pa);end
                    rows{end+1}=struct('mode',char(mode),'stagnation',stagnation,'pulse',pa,'exact',true); %#ok<AGROW>
                end
            end
            assert(isequal(fileread(fullfile(old,'reference','PPaPaRModel.m')),fileread(fullfile(r,'code','reference','PPaPaRModel.m'))));
            P3Experiment.json(fullfile(r,'audit','proposal_contract.json'),vertcat(rows{:}));
            source=P3Experiment.source();versionInfo=ver;save(fullfile(r,'freeze.mat'),'source','versionInfo');
        end
        function futures=start()
            r=P3Experiment.root();addpath(fullfile(r,'code'),fullfile(r,'code','reference'));z=load(fullfile(r,'freeze.mat'),'source');assert(isequal(z.source,P3Experiment.source()));
            pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',8);end
            files=dir(fullfile(r,'code','*.m'));paths=fullfile({files.folder},{files.name});paths{end+1}=fullfile(r,'code','reference','PPaPaRModel.m');addAttachedFiles(pool,paths);
            futures=parallel.FevalFuture.empty();
            for seed=400001:400030
                for mode=["revised","Diagonal","noNoise"]
                    futures(end+1)=parfeval(pool,@P3Experiment.one,1,char(mode),seed,z.source,r); %#ok<AGROW>
                end
            end
            fprintf('Submitted 60 new searches and 30 exact saved-evaluation replays.\n');
        end
        function status=one(mode,seed,source,sharedRoot)
            r=P3Experiment.root(sharedRoot);id=sprintf('PPAR_%s_%d',mode,seed);path=fullfile(r,'results','runs',[id,'.mat']);
            try
                maxNumCompThreads(1);assert(isequal(source,P3Experiment.source()));P3Tape.store('clear',[]);clean=onCleanup(@()P3Tape.store('clear',[]));
                c=P3Variants.config(mode,seed);p=P3Core.problem('PPAR');
                if isfile(path)
                    z=load(path,'source','result');assert(isequal(source,z.source)&&isequal(c,z.result.config));result=z.result;
                else
                    original='';
                    if strcmp(mode,'revised')
                        original=fullfile(fileparts(r),'MO_PACPO_搜索机制改进_20261024','results','physical',sprintf('PPAR_candidate_%d.mat',seed));z=load(original,'result','source');
                        oldc=P3Core.config(z.result.config);oldc.areaMode='progressive';assert(isequal(oldc,c));
                        assert(isequal(z.source.PPaPaRModel,source.PPaPaRModel));P3Tape.store('set',z.result.evaluations);
                    end
                    result=P3Core.solve(p,'PACPO',c);result.variant=mode;
                    assert(result.FE==25100&&isequal(result.archive,result.evaluations(result.archiveIDs,:)));
                    if strcmp(mode,'revised')
                        assert(P3Tape.store('count',[])==25100);
                        for field=["evaluations","history","population","archive","X","F","CV","HV","Spacing"]
                            assert(isequaln(result.(field),z.result.(field)),'P3:Replay','Full replay differs in %s',field);
                        end
                    end
                    P3Tape.store('clear',[]);save(path,'result','source','original','-v7');
                end
                finePath=fullfile(r,'validation',[id,'.mat']);
                if ~isfile(finePath)
                    if strcmp(mode,'revised')
                        v=load(fullfile(fileparts(r),'MO_PACPO_P1修正版_20261024','validation',sprintf('archive_revised_%d.mat',seed)));
                        X=v.X;allF=v.allF(1:2);allCV=v.allCV(1:2);allKeep=v.allKeep(1:2);hv=v.hv(1:2);sp=v.sp(1:2);counts=v.counts(1:2);assert(isequal(X,result.X));
                    else
                        zz=load(path,'result');X=zz.result.X;allF=cell(2,1);allCV=allF;allKeep=allF;hv=zeros(2,1);sp=hv;counts=hv;
                        for j=1:2
                            ns=262144*4^(j-1);[f,cv]=PPaPaRModel.evaluate(X,PPaPaRModel.config(ns));keep=cv==0&~any(P3Core.dominance(f,cv),1)';
                            [~,hv(j),sp(j)]=P3Core.metrics(p,f(keep,:));allF{j}=f;allCV{j}=cv;allKeep{j}=keep;counts(j)=sum(keep);
                        end
                    end
                    save(finePath,'mode','seed','X','allF','allCV','allKeep','hv','sp','counts','source','-v7');
                end
                status=struct('id',id,'ok',true,'replay',strcmp(mode,'revised'),'error','');
            catch ex
                status=struct('id',id,'ok',false,'replay',strcmp(mode,'revised'),'error',getReport(ex,'extended','hyperlinks','off'));
            end
            P3Experiment.json(fullfile(r,'results','runs',[id,'_status.json']),status);
        end
        function json(path,value)
            fid=fopen(path,'w','n','UTF-8');assert(fid>0);cl=onCleanup(@()fclose(fid));fprintf(fid,'%s',jsonencode(value,'PrettyPrint',true));
        end
    end
end
