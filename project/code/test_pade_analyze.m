function check = test_pade_analyze(qaDir)
%TEST_PADE_ANALYZE Synthetic statistical fixtures, NEVER optimisation results.
arguments
    qaDir (1,1) string
end
assert(~isfolder(qaDir),'PADE:FixtureExists','Use a new QA fixture directory.');
mkdir(qaDir); rawDir=fullfile(qaDir,'SYNTHETIC_FIXTURES_ONLY'); mkdir(rawDir);
problems=["P_RANK_TIES","P_STRONG","P_ZERO","P_CV","P_MIXED"];
delta=[0;1;1;2;3;-3;5;-8]; n=8;
for p=1:numel(problems)
    for seed=1:n
        af=100; bf=101; acv=0; bcv=0;
        switch problems(p)
            case "P_RANK_TIES", bf=100+delta(seed);
            case "P_ZERO", bf=100;
            case "P_CV", acv=1; bcv=2;
            case "P_MIXED"
                if seed==1, bcv=1; bf=1; end
        end
        for id=["A","B"]
            if id=="A", f=af; cv=acv; else, f=bf; cv=bcv; end
            result=struct('problem_id',problems(p),'variant_id',id,'seed',seed,...
                'FE',20,'budget_FE',20,'best_f',f,'best_cv',cv,'best_x',[1 2],...
                'trace_fe',[10 20],'trace_f',[f+1 f],'trace_cv',[cv cv],...
                'status','complete','pulseFE',0,'events',struct('pulse_trials',0));
            save(fullfile(rawDir,problems(p)+"_"+id+"_"+seed+".mat"),'result');
        end
    end
end
comparisons=table("fixture_family","A","B",'VariableNames',{'family_id','a_id','b_id'});
report=pade_analyze(rawDir,fullfile(qaDir,'analysis'),comparisons,...
    ExpectedRuns=n,ExpectedSeeds=(1:n)',ExpectedProblems=problems,ExpectedFE=20);
tests=report.tests;
strong=tests(tests.problem_id=="P_STRONG",:);
assert(strong.p_raw==2^(1-n)&&strong.p_holm==5*2^(1-n)&&strong.effect==1);
zero=tests(tests.problem_id=="P_ZERO",:);
assert(zero.p_raw==1&&zero.effect==0&&zero.n_nonzero==0);
cv=tests(tests.problem_id=="P_CV",:);
assert(cv.test=="paired_signed_rank_CV"&&cv.p_raw==2^(1-n));
mixed=tests(tests.problem_id=="P_MIXED",:);
assert(mixed.test=="paired_sign_Deb_order"&&mixed.p_raw==2^(1-n)&&mixed.wins==8);
% Independent brute-force enumeration of the 2^7 signed rank assignments.
ranks=[1.5 1.5 3 4.5 4.5 6 7]; observed=16.5; allW=zeros(2^7,1);
for mask=0:2^7-1
    allW(mask+1)=sum(ranks(logical(bitget(mask,1:7))));
end
expected=min(1,2*min(mean(allW<=observed),mean(allW>=observed)));
tie=tests(tests.problem_id=="P_RANK_TIES",:);
assert(tie.p_raw==expected&&tie.w_plus==observed);
% Each trace must include its genuine final checkpoint and observed value.
assert(height(report.traces(report.traces.FE==20,:))==10);
assert(all(report.runs.event_pulse_trials==0));
assert(all(report.summaries.mean_event_pulse_trials==0));
% Missing runs are never silently admitted as a completed 8-pair experiment.
delete(fullfile(rawDir,'P_ZERO_B_8.mat'));
caught=false;
try
    pade_analyze(rawDir,fullfile(qaDir,'missing_must_fail'),comparisons,...
        ExpectedRuns=n,ExpectedProblems=problems);
catch exception
    caught=strcmp(exception.identifier,'PADE:RunCount');
end
assert(caught,'PADE:MissingRunTest','Missing data did not fail strict coverage.');
check=struct('scope','SYNTHETIC STATISTICAL QA ONLY; NO OPTIMIZER EXECUTED',...
    'checks',10,'passed',true,'exact_DP_bruteforce_p',expected,...
    'holm_family_size',5,'fixture_runs',80);
fid=fopen(fullfile(qaDir,'STATISTICS_QA.json'),'w','n','UTF-8');
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(check,'PrettyPrint',true));
end
