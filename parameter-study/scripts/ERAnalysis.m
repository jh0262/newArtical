classdef ERAnalysis
 methods(Static)
 function t=collect(phase)
  maxNumCompThreads(1);ERTape.store('clear',[]);
  root=ERStudy.root();frozen=load(fullfile(root,'freeze.mat'),'source');jobs=ERStudy.jobs(phase);rows={};curves={};profiles={};fronts={};initial=containers.Map();nFinal=0;objectiveChecks=0;
  target=jsondecode(fileread(fullfile(root,'data/targets.json')));target=target.engineering_HV_target;
  for k=1:numel(jobs)
   j=jobs(k);path=fullfile(root,'results',phase,[j.id,'.mat']);st=jsondecode(fileread(strrep(path,'.mat','_status.json')));assert(st.ok,j.id);
   z=load(path,'result','source');r=z.result;p=ERCore.problem(j.problem);d=p.D;m=p.M;a=r.evaluations;assert(isequal(z.source,frozen.source));cfg=r.config;cfg.failureFile='';assert(isequal(cfg,ERStudy.config(j.variant,j.seed)));
   assert(r.FE==25100&&size(a,1)==25100&&isequal(a(:,end),(1:25100)')&&isequal(r.archive,a(r.archiveIDs,:)));
   key=sprintf('%s_%d',j.problem,j.seed);if isKey(initial,key),assert(isequal(initial(key),a(1:100,1:d)));else,initial(key)=a(1:100,1:d);end
   idx=[1,12550,25100];xx=p.lb+a(idx,1:d).*(p.ub-p.lb);[F,CV,G]=ERCore.evaluate(p,xx);assert(max(abs(F-a(idx,d+(1:m))),[],'all')<1e-9&&isequal(CV,a(idx,end-1))&&isequal(G,r.rawG(idx,:)));objectiveChecks=objectiveChecks+3;
   fine={};hv=NaN;mhv=NaN;fineSeconds=0;vmax=NaN;emin=NaN;dmax=NaN;fineND=NaN;valid=NaN;
   if strcmp(j.problem,'PPAR')
    v=load(strrep(path,'.mat','_fine.mat'));assert(isequal(v.X,r.X));fine=v.fine;hv=fine{1}.HV;mhv=fine{2}.HV;nFinal=nFinal+v.newFinalFE;fineSeconds=v.seconds;
    q=fine{2};vmax=max(-q.F(q.keep,1));emin=min(q.F(q.keep,2));dmax=max(-q.F(q.keep,3));fineND=numel(q.keep);valid=sum(q.CV==0);
   end
   reached=NaN;first=NaN;capped=NaN;
   if strcmp(j.problem,'PPAR'),at=find(r.history(:,3)>=target,1);reached=~isempty(at);capped=25100;if reached,first=r.history(at,2);capped=first;end;end
   [g,sq,osc,proj]=ERTheory.landscape(p,r.X(r.CV==0,:));coverage=NaN;if ~isempty(proj),[coverage,~,~]=ERCore.metrics(p,proj);end
   sig=r.operatorTrace(:,13);pulses=r.gateTrace(:,5)>0;
   row=struct('Phase',string(phase),'Problem',string(j.problem),'Variant',string(j.variant),'Seed',j.seed,'Eta',cfg.principalGain,'SigmaMin',cfg.sigmaMin,'Window',cfg.window,'Cap',cfg.pulseCap,'FE',r.FE,'SearchHV',r.HV,'FineHV',hv,'MillionHV',mhv,'AUC',trapz(r.history(:,2),r.history(:,3))/25000,'Reached',reached,'FirstTargetFE',first,'CappedTargetFE',capped,'IGD',r.IGD,'MeanG',mean(g),'MeanSquare',mean(sq),'MeanOscillatory',mean(osc),'CoverageIGD',coverage,'Pulses',sum(pulses),'BindingPulses',sum(pulses&sig>cfg.pulseCap),'FirstFloorGeneration',NaN,'VolumeMax',vmax,'ErrorMin',emin,'DexterityMax',dmax,'FineNondominated',fineND,'FineFeasible',valid,'SearchSeconds',r.elapsed,'FineSeconds',fineSeconds);
   at=find(sig<=cfg.sigmaMin+eps,1);if ~isempty(at),row.FirstFloorGeneration=at;end
   row.LateSigma=mean(sig(201:250));row.LateNoise=mean(r.operatorTrace(201:250,6));row.LatePulse=mean(r.operatorTrace(201:250,8));row.LateFloorFraction=mean(sig(201:250)<=cfg.sigmaMin+eps);row.LateStrict=mean(r.diagnostic(201:250,1));row.LateEntry=mean(r.diagnostic(201:250,3));row.LateClip=mean(r.operatorTrace(201:250,9));
   row.LateNoiseToProposalRatio=mean(r.operatorTrace(201:250,6)./max(r.operatorTrace(201:250,7),realmin));row.LateGuide=mean(r.operatorTrace(201:250,4));row.LateDifference=mean(r.operatorTrace(201:250,5));row.LateMutation=mean(r.operatorTrace(201:250,10));rows{k}=row;
   fronts{k}=struct('problem',j.problem,'variant',j.variant,'seed',j.seed,'nativeX',r.X,'nativeF',r.F,'nativeCV',r.CV,'history',r.history,'fine',{fine});
   curves{k}=table(repmat(string(phase),251,1),repmat(string(j.problem),251,1),repmat(string(j.variant),251,1),repmat(j.seed,251,1),r.history(:,1),r.history(:,2),r.history(:,3),'VariableNames',{'Phase','Problem','Variant','Seed','Generation','FE','HV'});
   segs={1:50,51:200,201:250};names=["early","middle","late"];
   for s=1:3,ii=segs{s};profiles{end+1}=struct('Phase',string(phase),'Problem',string(j.problem),'Variant',string(j.variant),'Seed',j.seed,'Stage',names(s),'Sigma',mean(sig(ii)),'NoiseRMS',mean(r.operatorTrace(ii,6)),'PulseRMS',mean(r.operatorTrace(ii,8)),'FloorFraction',mean(sig(ii)<=cfg.sigmaMin+eps),'Pulses',sum(pulses(ii)),'BindingPulses',sum(pulses(ii)&sig(ii)>cfg.pulseCap),'StrictRate',mean(r.diagnostic(ii,1)),'EntryRate',mean(r.diagnostic(ii,3)),'ClippingRMS',mean(r.operatorTrace(ii,9)));end %#ok<AGROW>
  end
  t=struct2table(vertcat(rows{:}));save(fullfile(root,'data',[phase,'_table.mat']),'t');writetable(t,fullfile(root,'data',[phase,'_runs.csv']));ERStudy.json(fullfile(root,'data',[phase,'_runs.json']),table2struct(t));ERStudy.json(fullfile(root,'data',[phase,'_fronts.json']),fronts);writetable(vertcat(curves{:}),fullfile(root,'data',[phase,'_curves.csv']));writetable(struct2table(vertcat(profiles{:})),fullfile(root,'data',[phase,'_profiles.csv']));
  ERStudy.json(fullfile(root,'audit',[phase,'_audit.json']),struct('status','pass','runs',height(t),'new_search_FE',sum(t.FE),'new_final_FE',nFinal,'audit_objective_FE',objectiveChecks,'paired_initial_groups',initial.Count));
 end
 function summarize(phase)
  root=ERStudy.root();z=load(fullfile(root,'data',[phase,'_table.mat']));t=z.t;metrics=["MillionHV","FineHV","SearchHV","AUC","CappedTargetFE","Reached","IGD","MeanG","Pulses","BindingPulses","LateNoise","LateSigma","LateFloorFraction","VolumeMax","ErrorMin","DexterityMax","SearchSeconds"];
  rows={};for task=unique(t.Problem,'stable')',for id=unique(t.Variant,'stable')',a=t(t.Problem==task&t.Variant==id,:);for metric=metrics,x=a.(metric);x=x(isfinite(x));if isempty(x),continue;end;rows{end+1}=struct('Problem',task,'Variant',id,'Metric',metric,'N',numel(x),'Mean',mean(x),'SD',std(x),'Median',median(x),'P10',prctile(x,10),'P25',prctile(x,25),'P75',prctile(x,75),'Min',min(x),'Max',max(x));end;end;end %#ok<AGROW>
  writetable(struct2table(vertcat(rows{:})),fullfile(root,'data',[phase,'_summary.csv']));
 end
 function select()
  root=ERStudy.root();assert(~isfile(fullfile(root,'data/selection.json')));z=load(fullfile(root,'data/screen_table.mat'));t=z.t;ids=ERStudy.variants();ids=ids(ids~="B");means=zeros(numel(ids),2);
  for i=1:numel(ids),a=t(t.Problem=="PPAR"&t.Variant==ids(i),:);assert(height(a)==16);means(i,:)=[mean(a.MillionHV),mean(a.AUC)];end
  [~,i]=max(means(:,1));[~,j]=max(means(:,2));chosen=unique([ids(i),ids(j)],'stable');
  ERStudy.json(fullfile(root,'data/selection.json'),struct('accuracy',ids(i),'speed',ids(j),'candidates',chosen,'basis','PPAR screen only; mean million-point HV and mean search AUC','variants',ids,'means',means,'timestamp',char(datetime('now'))));
 end
 function [p,e]=exact(d)
  d=d(d~=0);if isempty(d),p=1;e=0;return;end;r=tiedrank(abs(d));w=round(2*r);counts=1;
  for k=w',v=zeros(1,numel(counts)+k);v(1:numel(counts))=counts;v(k+(1:numel(counts)))=v(k+(1:numel(counts)))+counts;counts=v;end
  obs=sum(w(d>0));p=min(1,2*min(sum(counts(1:obs+1)),sum(counts(obs+1:end)))/2^numel(d));e=sum(sign(d).*r)/sum(r);
 end
 function [delta,names]=effects(v)
  delta=[mean(v(:,4:6)-v(:,1:3),2),mean(v(:,7:9)-v(:,4:6),2),mean(v(:,[2,5,8])-v(:,[1,4,7]),2),mean(v(:,[3,6,9])-v(:,[2,5,8]),2),(v(:,9)-v(:,7))-(v(:,3)-v(:,1)),.5*((v(:,10)-v(:,5))+(v(:,13)-v(:,12))),.5*((v(:,12)-v(:,5))+(v(:,13)-v(:,10))),(v(:,13)-v(:,10))-(v(:,12)-v(:,5)),v(:,11)-v(:,5)];
  names=["eta_low_to_mid","eta_mid_to_high","floor_low_to_mid","floor_mid_to_high","noise_corner_interaction","window_5_to_2","cap_020_to_0005","window_cap_interaction","window_5_to_10"];
 end
 function statistics(phase)
  root=ERStudy.root();z=load(fullfile(root,'data',[phase,'_table.mat']));t=z.t;n=16;if strcmp(phase,'confirm'),n=30;end;rng(20261027);boot=randi(n,n,10000);writematrix(boot,fullfile(root,'data',[phase,'_bootstrap.csv']));rows={};stability={};
  ids=ERStudy.variants();if strcmp(phase,'confirm'),sel=jsondecode(fileread(fullfile(root,'data/selection.json')));ids=["B",string(sel.candidates(:)')];end
  for task=["PPAR","DTLZ3"]
   metrics=["MillionHV","AUC","CappedTargetFE"];if task=="DTLZ3",metrics=["IGD","MeanG"];end
   for metric=metrics
    v=zeros(n,numel(ids));for i=1:numel(ids),a=sortrows(t(t.Problem==task&t.Variant==ids(i),:),'Seed');assert(height(a)==n);v(:,i)=a.(metric);end
    if strcmp(phase,'screen'),[delta,names]=ERAnalysis.effects(v);else,delta=v(:,2:end)-v(:,1);names=ids(2:end)+"_minus_B";end
    for i=1:numel(names),d=delta(:,i);[p,e]=ERAnalysis.exact(d);ci=prctile(mean(d(boot)),[2.5,97.5]);direction=1;if ismember(metric,["CappedTargetFE","IGD","MeanG"]),direction=-1;end;rows{end+1}=struct('Phase',string(phase),'Problem',task,'Metric',metric,'Contrast',names(i),'N',n,'MeanDifference',mean(d),'MedianDifference',median(d),'CILow',ci(1),'CIHigh',ci(2),'RawP',p,'BenefitRankEffect',direction*e,'Positive',sum(d>0),'Zero',sum(d==0),'Negative',sum(d<0));end %#ok<AGROW>
    if strcmp(phase,'confirm')&&task=="PPAR"&&ismember(metric,["MillionHV","AUC"])
     for i=2:numel(ids),a=v(:,i);b=v(:,1);ratio=std(a)/std(b);rb=std(a(boot))./std(b(boot));ci=prctile(rb,[2.5,97.5]);q=prctile(a(boot),10)-prctile(b(boot),10);qc=prctile(q,[2.5,97.5]);stability{end+1}=struct('Variant',ids(i),'Metric',metric,'SDRatio',ratio,'SDRatioLow',ci(1),'SDRatioHigh',ci(2),'P10Difference',prctile(a,10)-prctile(b,10),'P10Low',qc(1),'P10High',qc(2));end %#ok<AGROW>
    end
   end
  end
  s=struct2table(vertcat(rows{:}));s.HolmLocal=nan(height(s),1);s.HolmGlobal=s.HolmLocal;
  for task=["PPAR","DTLZ3"],ii=s.Problem==task;s.HolmGlobal(ii)=ERCore.holm(s.RawP(ii));for metric=unique(s.Metric(ii))',jj=ii&s.Metric==metric;s.HolmLocal(jj)=ERCore.holm(s.RawP(jj));end;end
  writetable(s,fullfile(root,'data',[phase,'_statistics.csv']));if ~isempty(stability),writetable(struct2table(vertcat(stability{:})),fullfile(root,'data/confirm_stability.csv'));end
 end
 end
end
