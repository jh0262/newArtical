function records=verify_p0_replay()
% Verify P0 against saved evaluation tapes; no objective calls or new samples.
R=fileparts(mfilename('fullpath'));B=fileparts(R);maxNumCompThreads(1);
addpath(fullfile(R,'code'),fullfile(R,'code','reference'));
tasks=["ZDT1","ZDT2","ZDT3","DTLZ1","DTLZ2","ZDT4","ZDT6","DTLZ3"];
records=struct('problem',{},'seed',{},'exact',{},'FE',{});
cleanup=onCleanup(@()P5Tape.store('clear',[]));
for k=1:numel(tasks)
 phase='confirmation';seed=710001+1000*k;
 if k>5,phase='external';seed=810001+1000*(k-5);end
 file=fullfile(B,'MO_PACPO_搜索机制改进_20261024','results',phase,sprintf('%s_legacy_%d.mat',tasks(k),seed));
 z=load(file,'result');old=z.result;assert(strcmp(old.config.mechanism,'legacy'));
 P5Tape.store('set',old.evaluations);
 now=P5Core.solve(P5Core.problem(tasks(k)),'PACPO',old.config);
 for field=["evaluations","history","archive","population","X","F","CV","IGD","HV","Spacing"]
  assert(isequaln(now.(field),old.(field)),'P5:P0Replay','%s differs in %s',tasks(k),field);
 end
 assert(P5Tape.store('count',[])==25100);
 records(end+1)=struct('problem',char(tasks(k)),'seed',seed,'exact',true,'FE',now.FE); %#ok<AGROW>
 fprintf('%s P0 replay matched.\n',tasks(k));
end
P5Experiment.json(fullfile(R,'audit','P0_replay.json'),records);
end
