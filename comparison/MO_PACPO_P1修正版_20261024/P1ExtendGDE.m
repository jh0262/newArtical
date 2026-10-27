classdef P1ExtendGDE
    methods (Static)
        function futures=start()
            root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));
            folder=fullfile(root,'validation','gde3_extended');if ~isfolder(folder),mkdir(folder);end
            z=load(fullfile(root,'validation','integration_protocol.mat'),'shifts');pool=gcp('nocreate');if isempty(pool),pool=parpool('Processes',8);end
            futures=parallel.FevalFuture.empty(0,30);for i=1:30,futures(i)=parfeval(pool,@P1ExtendGDE.one,1,root,400000+i,z.shifts);end
        end
        function status=one(root,seed,shifts)
            maxNumCompThreads(1);dest=fullfile(root,'validation','gde3_extended',sprintf('archive_GDE3_%d.mat',seed));
            if isfile(dest),status=true;return;end
            old=load(fullfile(root,'validation',sprintf('archive_GDE3_%d.mat',seed)));X=old.X;src=old.src;mode="GDE3";p=PACPOP1.problem('PPAR');
            allF=cell(10,1);allCV=allF;allKeep=allF;hv=zeros(10,1);sp=hv;counts=hv;
            allF{1}=old.allF{1};allCV{1}=old.allCV{1};allKeep{1}=old.allKeep{1};hv(1)=old.hv;sp(1)=old.sp;counts(1)=old.counts;
            for j=2:10
                count=262144;shift=zeros(1,3);if j==2,count=1048576;else,shift=shifts(j-2,:);end
                [f,cv]=PPaPaRModel.evaluate(X,PPaPaRModel.config(count,shift));keep=cv==0 & ~any(PACPOP1.dominance(f,cv),1)';
                [~,hv(j),sp(j)]=PACPOP1.metrics(p,f(keep,:));allF{j}=f;allCV{j}=cv;allKeep{j}=keep;counts(j)=sum(keep);
            end
            save(dest,'mode','seed','X','allF','allCV','allKeep','hv','sp','counts','shifts','src','-v7');status=true;
        end
    end
end
