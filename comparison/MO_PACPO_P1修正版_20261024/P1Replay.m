function P1Replay()
root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));maxNumCompThreads(1);
old=fullfile(fileparts(root),'MO_PACPO_搜索机制改进_20261024');records={};
tasks=["ZDT1","ZDT2","ZDT3","DTLZ1","DTLZ2","ZDT4","ZDT6","DTLZ3"];
for k=1:8
 phase='confirmation';seed=710001+1000*k;if k>5,phase='external';seed=810001+1000*(k-5);end
 modes="noEC";if ismember(k,[4,5,8]),modes=["revised","Diagonal","noNoise","noLock","noEC","Fixed"];end
 for mode=modes
  folder=phase;variant="candidate";
  if mode~="revised",folder='ablation';if k>5,folder='external_ablation';end;variant=replace(mode,["Diagonal","noNoise","noLock","noEC","Fixed"],["candidateDiagonal","candidateNoNoise","candidateNoLock","candidateNoEC","candidateFixed"]);end
  z=load(fullfile(old,'results',folder,sprintf('%s_%s_%d.mat',tasks(k),variant,seed)),'result');c=P1Variants.config(mode,seed);r=PACPOP1.solve(PACPOP1.problem(tasks(k)),'PACPO',c);
  assert(isequal(r.evaluations,z.result.evaluations)&&isequal(r.history,z.result.history));records{end+1}=table(tasks(k),mode,seed,r.FE,true,'VariableNames',{'Problem','Mode','Seed','FE','ExactReplay'}); %#ok<AGROW>
 end
end
% One full physical trace is replayed for instrumentation, not counted as an
% additional independent optimizer run. The seed with most recorded pulses
% is chosen deterministically to check the active conditional branch.
t=readtable(fullfile(old,'results','physical','runs.csv'),'TextType','string');[~,ix]=max(t.Pulses);seed=t.Seed(ix);
z=load(fullfile(old,'results','physical',sprintf('PPAR_candidate_%d.mat',seed)),'result');r=PACPOP1.solve(PACPOP1.problem('PPAR'),'PACPO',P1Variants.config('revised',seed));
assert(isequal(r.evaluations,z.result.evaluations)&&isequal(r.history,z.result.history));
records{end+1}=table("PPAR","revised",seed,r.FE,true,'VariableNames',{'Problem','Mode','Seed','FE','ExactReplay'});
rows=vertcat(records{:});writetable(rows,fullfile(root,'validation','full_budget_replay.csv'));save(fullfile(root,'validation','physical_trace_replay.mat'),'r','seed');
pulseEvents=array2table(r.pulseEvents,'VariableNames',{'Generation','Perturbed','Improved','ArchiveEntered','DeltaHV','LowDimension'});writetable(pulseEvents,fullfile(root,'validation','physical_trace_pulses.csv'));
P1Experiment.json(fullfile(root,'validation','replay_completed.json'),struct('fullBudgetReplays',height(rows),'exactEvaluationsAndHistory',true,'physicalSeed',seed,'physicalPulses',height(pulseEvents),'replayFE',sum(rows.FE)));
end
