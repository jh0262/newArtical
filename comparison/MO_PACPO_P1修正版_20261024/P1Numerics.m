classdef P1Numerics
    methods (Static)
        function run()
            root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));maxNumCompThreads(1);
            pool=gcp('nocreate');if isempty(pool),parpool('Processes',4);end
            rng(20261024,'twister');shifts=rand(8,3);save(fullfile(root,'validation','integration_protocol.mat'),'shifts');
            % The shared shift is identical across methods and seeds at every setting.
            names=["revised","NSGAII","noLock","GDE3"];
            parfor idx=1:120
                mode=names(ceil(idx/30));seed=400000+mod(idx-1,30)+1;
                P1Numerics.archive(root,mode,seed,shifts);
            end
            P1Numerics.candidates(root,shifts);P1Numerics.localErrors(root);
            P1Experiment.json(fullfile(root,'validation','completed.json'),struct('completed',true,'timestamp',char(datetime('now'))));
        end
        function archive(root,mode,seed,shifts)
            dest=fullfile(root,'validation',sprintf('archive_%s_%d.mat',mode,seed));if isfile(dest),return;end
            parent=fileparts(root);
            if mode=="revised"
                src=fullfile(parent,'MO_PACPO_搜索机制改进_20261024','results','physical',sprintf('PPAR_candidate_%d.mat',seed));
            elseif mode=="NSGAII"
                src=fullfile(parent,'MO_PACPO_机构模型修正版_20261023','results','runs',sprintf('physical_NSGAII_%d.mat',seed));
            else
                src=fullfile(root,'results','runs',sprintf('PPAR_%s_%d.mat',mode,seed));
            end
            while ~isfile(src),pause(10);end
            z=load(src,'result');X=z.result.X;p=PACPOP1.problem('PPAR');
            % GDE3 contributes the fine-resolution comparison; the P1 numerical
            % stability family compares revised/NSGA-II/noLock at all 10 settings.
            n=10;if mode=="GDE3",n=1;end
            allF=cell(n,1);allCV=allF;allKeep=allF;hv=zeros(n,1);sp=hv;counts=zeros(n,1);
            for j=1:n
                count=262144;shift=zeros(1,3);if j==2,count=1048576;elseif j>2,shift=shifts(j-2,:);end
                [f,cv]=PPaPaRModel.evaluate(X,PPaPaRModel.config(count,shift));
                keep=cv==0 & ~any(PACPOP1.dominance(f,cv),1)';
                [~,hv(j),sp(j)]=PACPOP1.metrics(p,f(keep,:));
                allF{j}=f;allCV{j}=cv;allKeep{j}=keep;counts(j)=sum(keep);
            end
            save(dest,'mode','seed','X','allF','allCV','allKeep','hv','sp','counts','shifts','src','-v7');
        end
        function candidates(root,shifts)
            t=readtable(fullfile(fileparts(root),'MO_PACPO_论文同步修订_20261024','data','physical_candidates.csv'));
            [~,order]=sort(t.TOPSISEqual,'descend');pick=order(1:20);X=table2array(t(pick,{'a','b','c','d'}));
            originalF=[-t.Volume,t.Error,-t.GCI];p=PACPOP1.problem('PPAR');F=cell(9,1);ranking=zeros(20,9);scores=zeros(20,9);
            for j=1:9
                count=262144;shift=zeros(1,3);if j==1,count=1048576;else,shift=shifts(j-1,:);end
                F{j}=PPaPaRModel.evaluate(X,PPaPaRModel.config(count,shift));
                % Freeze the complete original candidate set's column norm, so
                % a shortlist does not silently become a different decision rule.
                base=PACPOP1.normalize(p,originalF);den=sqrt(sum(base.^2,1));
                normalized=PACPOP1.normalize(p,F{j});weighted=normalized./den/3;
                ideal=min(base./den/3,[],1);nadir=max(base./den/3,[],1);
                d1=sqrt(sum((weighted-ideal).^2,2));d2=sqrt(sum((weighted-nadir).^2,2));scores(:,j)=d2./(d1+d2);
                [~,ranking(:,j)]=sort(scores(:,j),'descend');
            end
            rawMin=min(originalF,[],1);rawRange=max(originalF,[],1)-rawMin;
            [rangeScores,rangeOrder]=PACPOP1.topsis((originalF-rawMin)./rawRange,[1,1,1]/3);
            save(fullfile(root,'validation','candidate_stability.mat'),'t','pick','X','F','ranking','scores','rangeScores','rangeOrder','rawMin','rawRange');
            P1Experiment.json(fullfile(root,'validation','candidate_stability.json'),struct('top20Indices',pick,'rankings',ranking,'scores',scores,'rangeBest',table2struct(t(rangeOrder(1),:)),'rangeBestOriginalRank',find(order==rangeOrder(1)),'normalization','fixed full-set column norms/ideals for shortlist perturbation; range alternative is a separate rule'));
        end
        function localErrors(root)
            t=readtable(fullfile(fileparts(root),'MO_PACPO_论文同步修订_20261024','data','physical_representatives.csv'));
            [~,high]=max(t.Error);designs=[400,700,1000,150;table2array(t(1,{'a','b','c','d'}));table2array(t(high,{'a','b','c','d'}))];
            mm=PPaPaRModel.config(262144);contributions=zeros(3,3);sensitivity=zeros(3,3,3);rows={};raw=cell(3,2);
            for d=1:3
                x=designs(d,:);g=PPaPaRModel.geometry(x,mm);
                for group=1:3
                    z=mm;if group~=1,z.sigmaQ=0;end;if group~=2,z.sigmaAlpha=0;end;if group~=3,z.sigmaG(:)=0;end
                    f=PPaPaRModel.evaluate(x,z);contributions(d,group)=f(2)^2;
                    scale=[.5,1,2];for k=1:3
                        z=mm;if group==1,z.sigmaQ=z.sigmaQ*scale(k);elseif group==2,z.sigmaAlpha=z.sigmaAlpha*scale(k);else,z.sigmaG=z.sigmaG*scale(k);end
                        f=PPaPaRModel.evaluate(x,z);sensitivity(d,group,k)=f(2);
                    end
                end
                [w,v,~,pose,control]=PPaPaRModel.integrand(x,mm);valid=find(w>0);[~,ord]=sort(v(valid));
                ids=[valid(ord(round(numel(ord)/2))),valid(ord(end))];
                for k=1:2
                    pp=pose(ids(k),:);cc=control(ids(k),:);[J,S,A,B,C]=PPaPaRModel.differential(pp,cc,g);
                    rng(20261024+10*d+k,'twister');n=12000;sig=[mm.sigmaQ,mm.sigmaQ,mm.sigmaAlpha,mm.sigmaAlpha,mm.sigmaG];noise=randn(n,12).*sig;
                    linear=noise(:,1:4)*J'+noise(:,5:12)*S';nonlinear=nan(n,4);ok=false(n,1);
                    for i=1:n,[p1,ok(i)]=PPaPaRModel.forward(cc+noise(i,1:4),g+noise(i,5:12),mm);nonlinear(i,:)=p1-pp;end
                    linearRMS=sqrt(mean(sum(linear(ok,1:3).^2,2)));nonlinearRMS=sqrt(mean(sum(nonlinear(ok,1:3).^2,2)));residualRMS=sqrt(mean(sum((nonlinear(ok,1:3)-linear(ok,1:3)).^2,2)));
                    % Central differences of the residual at fixed inputs give a
                    % branch-independent check of all analytic derivative columns.
                    hP=[1e-4,1e-4,1e-4,1e-7];hU=[1e-4,1e-4,1e-7,1e-7];hG=1e-4*ones(1,8);Af=zeros(4);Bf=zeros(4);Cf=zeros(4,8);
                    for j=1:4,dp=zeros(1,4);dp(j)=hP(j);[~,~,~,~,~,pa]=PPaPaRModel.differential(pp+dp,cc,g);[~,~,~,~,~,pb]=PPaPaRModel.differential(pp-dp,cc,g);Af(:,j)=(pa-pb)/(2*hP(j));du=zeros(1,4);du(j)=hU(j);[~,~,~,~,~,pa]=PPaPaRModel.differential(pp,cc+du,g);[~,~,~,~,~,pb]=PPaPaRModel.differential(pp,cc-du,g);Bf(:,j)=(pa-pb)/(2*hU(j));end
                    for j=1:8,dg=zeros(1,8);dg(j)=hG(j);[~,~,~,~,~,pa]=PPaPaRModel.differential(pp,cc,g+dg);[~,~,~,~,~,pb]=PPaPaRModel.differential(pp,cc,g-dg);Cf(:,j)=(pa-pb)/(2*hG(j));end
                    row=struct('Design',d,'Position',k,'Samples',n,'Valid',nnz(ok),'BranchFailureRate',mean(~ok),'LinearRMS',linearRMS,'NonlinearRMS',nonlinearRMS,'RelativeDifference',nonlinearRMS/linearRMS-1,'ResidualRMS',residualRMS,'DerivativeRelativeError',max([norm(Af-A,'fro')/norm(A,'fro'),norm(Bf-B,'fro')/norm(B,'fro'),norm(Cf-C,'fro')/norm(C,'fro')]));rows{end+1}=row; %#ok<AGROW>
                    raw{d,k}=struct('pose',pp,'control',cc,'geometry',g,'noise',noise,'valid',ok,'linear',linear,'nonlinear',nonlinear);
                end
            end
            records=struct2table(vertcat(rows{:}));writetable(records,fullfile(root,'validation','local_errors.csv'));
            save(fullfile(root,'validation','local_errors.mat'),'designs','raw','records','contributions','sensitivity','-v7');
            P1Experiment.json(fullfile(root,'validation','error_groups.json'),struct('designs',designs,'varianceContributions',contributions,'varianceFractions',contributions./sum(contributions,2),'scales',[.5,1,2],'sensitivity',sensitivity));
        end
    end
end
