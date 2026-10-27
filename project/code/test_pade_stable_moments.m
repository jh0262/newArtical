function check = test_pade_stable_moments(qaDir)
%TEST_PADE_STABLE_MOMENTS Synthetic arithmetic regression, no optimisation.
arguments
    qaDir (1,1) string
end
assert(~isfolder(qaDir),'PADE:MomentFixtureExists','Use a new QA fixture directory.');
mkdir(qaDir); rawDir=fullfile(qaDir,'SYNTHETIC_MOMENT_FIXTURES'); mkdir(rawDir);
n=30; cost=1.7248523085973648; ulp=eps(8);
problems=["CONSTANT_NONBINARY","NEARBY_BINARY","CONSTANT_CV"];
for p=1:3
    for seed=1:n
        f=cost; cv=0;
        if p==2, f=8+(seed-1)*ulp; elseif p==3, cv=0.1; end
        for id=["A","B"]
            result=struct('problem_id',problems(p),'variant_id',id,'seed',seed,...
                'FE',20,'budget_FE',20,'best_f',f,'best_cv',cv,'best_x',[1 2],...
                'trace_fe',[10 20],'trace_f',[f f],'trace_cv',[cv cv],...
                'run_seconds',cost,'status','complete');
            save(fullfile(rawDir,problems(p)+"_"+id+"_"+seed+".mat"),'result');
        end
    end
end
comparisons=table("moment_fixture_family","A","B",...
    'VariableNames',{'family_id','a_id','b_id'});
report=pade_analyze(rawDir,fullfile(qaDir,'analysis'),comparisons,...
    ExpectedRuns=n,ExpectedSeeds=(1:n)',ExpectedProblems=problems,ExpectedFE=20);
s=report.summaries(report.summaries.problem_id=="CONSTANT_NONBINARY",:);
assert(all(s.mean_f==cost&s.std_f==0&s.mean_feasible_f==cost&s.std_feasible_f==0));
assert(all(s.mean_f>=s.best_f&s.mean_f<=s.worst_f));
assert(all(s.mean_seconds==cost));
t=report.traces(report.traces.problem_id=="CONSTANT_NONBINARY",:);
assert(all(t.mean_f==cost&t.std_f==0));
s=report.summaries(report.summaries.problem_id=="NEARBY_BINARY",:);
expectedMean=8+(n-1)/2*ulp;
expectedStd=ulp*sqrt(n*(n+1)/12); % Exact sample variance of integers 0:29.
assert(all(s.mean_f==expectedMean));
assert(all(abs(s.std_f-expectedStd)<=8*eps(expectedStd)));
assert(all(s.std_f>0&s.mean_f>=s.best_f&s.mean_f<=s.worst_f));
t=report.traces(report.traces.problem_id=="NEARBY_BINARY",:);
assert(all(t.mean_f==expectedMean&abs(t.std_f-expectedStd)<=8*eps(expectedStd)));
s=report.summaries(report.summaries.problem_id=="CONSTANT_CV",:);
t=report.traces(report.traces.problem_id=="CONSTANT_CV",:);
assert(all(s.mean_cv==0.1)&&all(t.mean_cv==0.1));
assert(all(report.tests.p_raw==1&report.tests.effect==0&report.tests.n_nonzero==0));
check=struct('scope','SYNTHETIC ARITHMETIC QA ONLY; NO OPTIMIZER EXECUTED',...
    'passed',true,'fixture_runs',180,'constant_value',cost,...
    'constant_mean_exact',true,'constant_sd_exact_zero',true,...
    'nearby_reference_mean',expectedMean,'nearby_reference_sample_sd',expectedStd,...
    'trace_moments_checked',true,'CV_moments_checked',true,...
    'paired_tests_unchanged_all_zero',true,...
    'method','anchor=x(1); mean=anchor+mean(x-anchor); sample_SD=std(x-anchor,0)');
fid=fopen(fullfile(qaDir,'STABLE_MOMENTS_QA.json'),'w','n','UTF-8');
cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(check,'PrettyPrint',true));
end
