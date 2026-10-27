classdef P1NumericsExtra
    % Same numerical protocol, extra workers and atomic completed-file publication.
    methods (Static)
        function run()
            root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));maxNumCompThreads(1);
            z=load(fullfile(root,'validation','integration_protocol.mat'),'shifts');shifts=z.shifts;
            staging=fullfile(root,'validation','extra');if ~isfolder(staging),mkdir(staging);end
            pool=gcp('nocreate');if isempty(pool),parpool('Processes',8);end
            modes=["revised","NSGAII","noLock","GDE3"];
            % Reverse order reduces overlap with the existing numerical batch.
            parfor ii=1:120
                idx=121-ii;mode=modes(ceil(idx/30));seed=400000+mod(idx-1,30)+1;
                P1NumericsExtra.one(root,mode,seed,shifts,staging);
            end
            P1Experiment.json(fullfile(staging,'completed.json'),struct('completed',true,'protocol','identical to P1Numerics','timestamp',char(datetime('now'))));
        end
        function one(root,mode,seed,shifts,staging)
            name=sprintf('archive_%s_%d.mat',mode,seed);dest=fullfile(root,'validation',name);if isfile(dest),return;end
            parent=fileparts(root);
            if mode=="revised",src=fullfile(parent,'MO_PACPO_搜索机制改进_20261024','results','physical',sprintf('PPAR_candidate_%d.mat',seed));
            elseif mode=="NSGAII",src=fullfile(parent,'MO_PACPO_机构模型修正版_20261023','results','runs',sprintf('physical_NSGAII_%d.mat',seed));
            else,src=fullfile(root,'results','runs',sprintf('PPAR_%s_%d.mat',mode,seed));end
            while ~isfile(src),pause(10);end
            if isfile(dest),return;end
            z=load(src,'result');X=z.result.X;p=PACPOP1.problem('PPAR');n=10;if mode=="GDE3",n=1;end
            allF=cell(n,1);allCV=allF;allKeep=allF;hv=zeros(n,1);sp=hv;counts=hv;
            for j=1:n
                count=262144;shift=zeros(1,3);if j==2,count=1048576;elseif j>2,shift=shifts(j-2,:);end
                [f,cv]=PPaPaRModel.evaluate(X,PPaPaRModel.config(count,shift));keep=cv==0 & ~any(PACPOP1.dominance(f,cv),1)';
                [~,hv(j),sp(j)]=PACPOP1.metrics(p,f(keep,:));allF{j}=f;allCV{j}=cv;allKeep{j}=keep;counts(j)=sum(keep);
            end
            temp=fullfile(staging,name);save(temp,'mode','seed','X','allF','allCV','allKeep','hv','sp','counts','shifts','src','-v7');
            if isfile(dest),return;end
            try
                empty=javaArray('java.lang.String',0);from=java.nio.file.Paths.get(temp,empty);to=java.nio.file.Paths.get(dest,empty);
                java.nio.file.Files.move(from,to,javaArray('java.nio.file.CopyOption',0));
            catch ex
                if ~isfile(dest),rethrow(ex);end
            end
        end
    end
end
