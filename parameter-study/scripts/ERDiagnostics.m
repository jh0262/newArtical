classdef ERDiagnostics
 methods(Static)
 function run()
  root=ERStudy.root();rows={};sources={};
  ids=["N12","N32","N11","N13","N21","N23","N31","N33","W2","W10","C005","W2C005"];
  refs=["B","B","N12","N12","B","B","N32","N32","B","B","B","B"];
  types=["eta","eta","floor","floor","floor","floor","floor","floor","gate","gate","gate","gate"];
  tasks=["PPAR","DTLZ3"];bases=[941000,942000];
  for k=1:2
   for rep=1:16
    results=containers.Map();seed=bases(k)+rep;
    for id=ERStudy.variants(),v=load(fullfile(root,'results/screen',sprintf('%s_%s_%d.mat',tasks(k),id,seed)),'result');results(char(id))=v.result;end
    for j=1:numel(ids)
     a=results(char(ids(j)));b=results(char(refs(j)));d=size(a.X,2);ix=find(any(a.evaluations(:,1:d)~=b.evaluations(:,1:d),2),1);fe=NaN;gen=NaN;before=[];after=[];
     if ~isempty(ix),fe=ix;gen=floor((ix-1)/100);before=b.evaluations(ix,1:d);after=a.evaluations(ix,1:d);end
     sg=find(a.operatorTrace(:,13)~=b.operatorTrace(:,13),1);if isempty(sg),sg=NaN;end
     pg=find(a.operatorTrace(:,8)~=b.operatorTrace(:,8),1);if isempty(pg),pg=NaN;end
     rows{end+1}=struct('Problem',tasks(k),'Variant',ids(j),'Reference',refs(j),'Seed',seed,'ParameterType',types(j),'IdenticalTrajectory',isempty(ix),'FirstDifferentFE',fe,'FirstDifferentGeneration',gen,'FirstSigmaDifference',sg,'FirstPulseRMSDifference',pg); %#ok<AGROW>
     sources{end+1}=struct('problem',tasks(k),'variant',ids(j),'reference',refs(j),'seed',seed,'firstFE',fe,'referenceX',before,'variantX',after); %#ok<AGROW>
    end
   end
  end
  t=struct2table(vertcat(rows{:}));writetable(t,fullfile(root,'data/screen_activation.csv'));ERStudy.json(fullfile(root,'data/activation_samples.json'),sources);
  ERStudy.json(fullfile(root,'audit/activation_audit.json'),struct('records',height(t),'new_objective_evaluations',0,'scope','descriptive trace comparison; no new inferential tests or candidate selection'));
 end
 end
end
