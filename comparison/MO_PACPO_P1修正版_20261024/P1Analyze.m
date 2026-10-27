classdef P1Analyze
    methods (Static)
        function run(benchmarkOnly)
            if nargin<1,benchmarkOnly=false;end
            root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));
            old=fullfile(fileparts(root),'MO_PACPO_搜索机制改进_20261024');
            jobs=P1Experiment.jobs();assert(all(arrayfun(@(j)isfile(fullfile(root,'results','runs',[j.id,'.mat'])),jobs)),'Incomplete optimization jobs');
            tasks=["ZDT1","ZDT2","ZDT3","DTLZ1","DTLZ2","ZDT4","ZDT6","DTLZ3"];
            modes=["revised","legacy","NSGAII","MOEAD","MOPSO","GDE3","oldArea","Diagonal","noNoise","noLock","noEC","Fixed"];
            records={};H=[];pulses={};origins={};
            for k=1:8
                phase='confirmation';base=710000+1000*k;if k>5,phase='external';base=810000+1000*(k-5);end
                for mode=modes
                    for repeat=1:30
                        seed=base+repeat;file=fullfile(root,'results','runs',sprintf('%s_%s_%d.mat',tasks(k),mode,seed));
                        if ~isfile(file)
                            folder=phase;variant=mode;
                            if ismember(mode,["revised","oldArea"]),variant="candidate";
                            elseif ismember(mode,["Diagonal","noNoise","noLock","noEC","Fixed"])
                                folder='ablation';if k>5,folder='external_ablation';end
                                variant=replace(mode,["Diagonal","noNoise","noLock","noEC","Fixed"],["candidateDiagonal","candidateNoNoise","candidateNoLock","candidateNoEC","candidateFixed"]);
                            end
                            file=fullfile(old,'results',folder,sprintf('%s_%s_%d.mat',tasks(k),variant,seed));
                        end
                        z=load(file,'result');r=z.result;assert(r.FE==25100);assert(numel(r.CV)==size(r.F,1)&&numel(r.archiveIDs)==size(r.F,1)&&all(r.archiveIDs>=1&r.archiveIDs<=r.FE));
                        [r.IGD,r.HV,r.Spacing]=PACPOP1.metrics(PACPOP1.problem(tasks(k)),r.F(r.CV==0,:));
                        records{end+1}=table(tasks(k),mode,seed,r.IGD,r.HV,r.Spacing,r.FE,r.elapsed,sum(r.history(:,4)), ...
                            'VariableNames',{'Problem','Variant','Seed','IGD','HV','SP','FE','Seconds','Pulses'}); %#ok<AGROW>
                        H(:,end+1)=r.history(:,3);origins{end+1,1}=file; %#ok<AGROW>
                        if mode=="revised" && isfield(r,'pulseEvents') && ~isempty(r.pulseEvents)
                            t=array2table(r.pulseEvents,'VariableNames',{'Generation','Perturbed','Improved','ArchiveEntered','DeltaHV','LowDimension'});t.Problem=repmat(tasks(k),height(t),1);t.Seed=repmat(seed,height(t),1);pulses{end+1}=t; %#ok<AGROW>
                        end
                    end
                end
            end
            runs=vertcat(records{:});writetable(runs,fullfile(root,'results','benchmark_runs.csv'));
            summary=groupsummary(runs,{'Problem','Variant'},{'mean','std','median'},{'IGD','HV','SP','Pulses'});
            writetable(summary,fullfile(root,'results','benchmark_summary.csv'));
            save(fullfile(root,'results','benchmark_analysis.mat'),'runs','summary','H','origins','-v7');
            if ~isempty(pulses),writetable(vertcat(pulses{:}),fullfile(root,'results','pulse_events.csv'));end
            P1Analyze.compare(root,runs,tasks(1:5),["legacy","NSGAII","MOEAD","MOPSO"],'confirmation');
            P1Analyze.compare(root,runs,tasks(6:8),["legacy","NSGAII","MOEAD","MOPSO"],'external');
            P1Analyze.compare(root,runs,tasks,["Diagonal","noNoise","noLock","noEC","Fixed"],'ablation');
            P1Analyze.compare(root,runs,tasks,["oldArea","noEC"],'area');
            P1Analyze.compare(root,runs,tasks,"GDE3",'GDE3');
            if ~benchmarkOnly,P1Analyze.physical(root,old);P1Analyze.numerics(root);end
            speed={};
            for task=tasks
                q=runs(runs.Problem==task & ismember(runs.Variant,["NSGAII","MOEAD","MOPSO"]),:);s=groupsummary(q,'Variant','mean','HV');target=.95*max(s.mean_HV);
                for mode=modes(1:6)
                    rows=find(runs.Problem==task & runs.Variant==mode);hit=nan(30,1);
                    for j=1:30,ix=find(H(:,rows(j))>=target,1);if ~isempty(ix),hit(j)=100*ix;end;end
                    speed{end+1}=table(task,mode,target,sum(isfinite(hit)),median(hit,'omitnan'),'VariableNames',{'Problem','Variant','Target','Reached','MedianFE'}); %#ok<AGROW>
                end
            end
            writetable(vertcat(speed{:}),fullfile(root,'results','time_to_target.csv'));
            name='completion.json';if benchmarkOnly,name='benchmark_completed.json';end
            P1Experiment.json(fullfile(root,'audit',name),struct('newOptimizationRuns',numel(jobs),'newOptimizationFE',numel(jobs)*25100,'benchmarkRowsWithReuse',height(runs),'compactArchiveChecks',true,'created',char(datetime('now'))));
        end
        function compare(root,runs,tasks,modes,label)
            rows={};for task=tasks
                a=sortrows(runs(runs.Problem==task & runs.Variant=="revised",:),'Seed');
                for mode=modes
                    b=sortrows(runs(runs.Problem==task & runs.Variant==mode,:),'Seed');assert(isequal(a.Seed,b.Seed));
                    for metric=["IGD","HV","SP"]
                        dir=-1;if metric=="HV",dir=1;end;t=struct2table(P1Stats.paired(a.(metric),b.(metric),dir));t.Problem=task;t.Comparator=mode;t.Metric=metric;rows{end+1}=t; %#ok<AGROW>
                    end
                end
            end
            t=P1Stats.adjust(vertcat(rows{:}));writetable(t,fullfile(root,'results',[label,'_statistics.csv']));
        end
        function physical(root,old)
            prior=load(fullfile(old,'results','physical','analysis.mat'),'runs');runs=prior.runs;runs.Variant=string(runs.Variant);runs.Variant(runs.Variant=="candidate")="revised";
            % Use exact MAT values, not a mix of rounded CSV and new doubles.
            % The common integration audit is authoritative for re-evaluated archives.
            for mode=["revised","NSGAII"]
                for repeat=1:30
                    seed=400000+repeat;v=load(fullfile(root,'validation',sprintf('archive_%s_%d.mat',mode,seed)),'hv','sp');k=runs.Variant==mode & runs.Seed==seed;
                    runs.FineHV(k)=v.hv(1);runs.FineSpacing(k)=v.sp(1);
                end
            end
            for mode=["noLock","GDE3"]
                for repeat=1:30
                    seed=400000+repeat;z=load(fullfile(root,'results','runs',sprintf('PPAR_%s_%d.mat',mode,seed)),'result');r=z.result;
                    f=load(fullfile(root,'validation',sprintf('archive_%s_%d.mat',mode,seed)),'hv','sp');
                    runs=[runs;table(mode,seed,r.FE,r.HV,f.hv(1),f.sp(1),r.elapsed,sum(r.history(:,4)),'VariableNames',runs.Properties.VariableNames)]; %#ok<AGROW>
                end
            end
            writetable(runs,fullfile(root,'results','physical_runs.csv'));summary=groupsummary(runs,'Variant',{'mean','std','median'},{'FineHV','FineSpacing','Pulses'});writetable(summary,fullfile(root,'results','physical_summary.csv'));
            rows={};a=sortrows(runs(runs.Variant=="revised",:),'Seed');
            for mode=["noLock","GDE3"]
                b=sortrows(runs(runs.Variant==mode,:),'Seed');
                for metric=["FineHV","FineSpacing"]
                    dir=1;if metric=="FineSpacing",dir=-1;end;t=struct2table(P1Stats.paired(a.(metric),b.(metric),dir));t.Comparator=mode;t.Metric=metric;rows{end+1}=t; %#ok<AGROW>
                end
            end
            statistics=P1Stats.adjust(vertcat(rows{:}));writetable(statistics,fullfile(root,'results','physical_new_statistics.csv'));
        end
        function numerics(root)
            modes=["revised","NSGAII","noLock","GDE3"];hv=zeros(30,10,4);sp=hv;counts=hv;
            for j=1:4
                folder=fullfile(root,'validation');if j==4,folder=fullfile(folder,'gde3_extended');end
                for i=1:30
                    z=load(fullfile(folder,sprintf('archive_%s_%d.mat',modes(j),400000+i)));
                    assert(numel(z.hv)==10,'Archive audit is incomplete');
                    hv(i,:,j)=z.hv;sp(i,:,j)=z.sp;counts(i,:,j)=z.counts;
                end
            end
            % An additional shift-averaged observation is one number per search
            % seed, not 240 independent optimizer observations.
            hv(:,11,:)=mean(hv(:,3:10,:),2);sp(:,11,:)=mean(sp(:,3:10,:),2);
            rawRows={};for j=1:4,for setting=1:11,rawRows{end+1}=table(repmat(modes(j),30,1),(400001:400030)',repmat(setting,30,1),hv(:,setting,j),sp(:,setting,j),'VariableNames',{'Variant','Seed','Setting','HV','SP'});end;end %#ok<AGROW>
            writetable(vertcat(rawRows{:}),fullfile(root,'validation','archive_runs.csv'));
            rng(20261024,'twister');bootstrapIndices=randi(30,30,20000);
            rows={};for setting=1:11
                parts={};for j=2:4
                    t=struct2table(P1Stats.paired(hv(:,setting,1),hv(:,setting,j),1));t.Comparator=modes(j);t.Metric="HV";t.Setting=setting;t.RevisedMean=mean(hv(:,setting,1));t.ComparatorMean=mean(hv(:,setting,j));t.RelativeGain=t.MeanDifference/t.ComparatorMean;t.PositivePairs=sum(hv(:,setting,1)>hv(:,setting,j));delta=hv(:,setting,1)-hv(:,setting,j);interval=quantile(mean(delta(bootstrapIndices),1),[.025,.975]);t.CILower=interval(1);t.CIUpper=interval(2);parts{end+1}=t; %#ok<AGROW>
                end
                rows{end+1}=P1Stats.adjust(vertcat(parts{:})); %#ok<AGROW>
            end
            statistics=vertcat(rows{:});writetable(statistics,fullfile(root,'validation','archive_hv_statistics.csv'));
            save(fullfile(root,'validation','archive_analysis.mat'),'hv','sp','counts','statistics','modes','bootstrapIndices');
        end
    end
end
