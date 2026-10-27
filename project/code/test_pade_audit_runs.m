function summary = test_pade_audit_runs(packageRoot)
%TEST_PADE_AUDIT_RUNS Test the auditor using tiny, labelled synthetic records.
% No optimizer is called. No formal raw file is opened or modified.
arguments
    packageRoot (1,1) string = string(fileparts(fileparts(mfilename('fullpath'))))
end
stamp=string(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
fixture=fullfile(packageRoot,'qa','audit_fixture_'+stamp);
mkdir(fixture); mkdir(fullfile(fixture,'raw','F01'));
variants={'G0P0J0','G2P1J0'};
cfg=struct('version','PADE-FE-v4.0','runs',1,'seeds',1001,...
    'problems',struct('id','F01','index',1,'N',4,'maxFE',8,...
    'variants',{variants},'runs',1),'total_runs',2,'total_search_FE',16,...
    'warmupRatio',.1,'pulseEndRatio',.9,'cv_tolerance',0);
frozen=struct('code_hash','synthetic-code-hash','problem_hash','synthetic-problem-hash',...
    'config_hash','synthetic-config-hash','code_files',struct(),'protocol_files',struct());
writeJson(fullfile(fixture,'CONFIG.json'),cfg);
writeJson(fullfile(fixture,'FROZEN_MANIFEST.json'),frozen);
writeNote(fullfile(fixture,'SYNTHETIC_FIXTURE.md'),...
    'These two tiny MAT records are synthetic auditor fixtures, not optimization results.');
base=makeSyntheticResult();
for k=1:numel(variants)
    result=base; result.variant_id=variants{k}; result.variant.id=variants{k};
    if k==2, result.variant.geometry=2; result.variant.pulse=true; end
    save(fullfile(fixture,'raw','F01',sprintf('F01__%s__s1001.mat',variants{k})),'result','-v7');
end
positive=pade_audit_runs(fixture,StrictPlan=false,CheckFrozenFiles=false,...
    OutputDir=fullfile(fixture,'case_positive'));
assert(positive.passed && positive.valid_runs==2 && positive.successful_total_FE==16,...
    'PADE:AuditFixturePositive','Clean synthetic audit fixture did not pass.');
assert(positive.paired_initialization_checks==1 && positive.paired_initialization_failures==0);
checks={'initial_bytes','objective','strict_cv','exact_fe','frozen_hash',...
    'bounds','counters','trace_monotonic'};
codes={'PairedInitialization','BestObjectiveReevaluation','StrictFeasibilityIdentity',...
    'ExactFE','FrozenResultHashes','Bounds','FEAccounting','DebTraceMonotonic'};
outcomes=false(numel(checks),1);
badFile=fullfile(fixture,'raw','F01','F01__G2P1J0__s1001.mat');
for k=1:numel(checks)
    result=base; result.variant_id='G2P1J0'; result.variant.id='G2P1J0';
    result.variant.geometry=2; result.variant.pulse=true;
    switch checks{k}
        case 'initial_bytes', result.initial_pop(2,1)=1+eps;
        case 'objective', result.best_f=.25;
        case 'strict_cv', result.best_cv=eps;
        case 'exact_fe', result.FE=7;
        case 'frozen_hash', result.code_hash='deliberately-wrong';
        case 'bounds', result.best_x(1)=101;
        case 'counters', result.events.init_FE=3; result.events.trial_FE=5;
        case 'trace_monotonic', result.trace_f(end)=.25;
    end
    save(badFile,'result','-v7');
    negative=pade_audit_runs(fixture,StrictPlan=false,CheckFrozenFiles=false,...
        OutputDir=fullfile(fixture,"case_"+string(checks{k})));
    outcomes(k)=~negative.passed && any(negative.issues.code==string(codes{k}));
    assert(outcomes(k),'PADE:AuditFixtureNegative','Auditor failed to detect injected %s error.',checks{k});
end
% Restore the labelled fixture input to its clean state after negative cases.
result=base; result.variant_id='G2P1J0'; result.variant.id='G2P1J0';
result.variant.geometry=2; result.variant.pulse=true; save(badFile,'result','-v7');
restored=pade_audit_runs(fixture,StrictPlan=false,CheckFrozenFiles=false,...
    OutputDir=fullfile(fixture,'case_restored'));
assert(restored.passed,'PADE:AuditFixtureRestore','Restored synthetic fixture did not pass.');
summary=struct('passed',true,'synthetic_fixture',true,'fixture_root',char(fixture),...
    'optimizer_calls',0,'formal_raw_files_read',0,'positive_case_passed',positive.passed,...
    'negative_cases',{checks},'negative_case_detection',outcomes,...
    'negative_cases_passed',sum(outcomes),'negative_cases_total',numel(outcomes));
writeJson(fullfile(fixture,'TEST_SUMMARY.json'),summary);
fprintf('Independent auditor fixture: positive pass and %d/%d injected errors detected.\n',sum(outcomes),numel(outcomes));
end

function r=makeSyntheticResult()
pop=[zeros(1,30);ones(1,30);2*ones(1,30);3*ones(1,30)];
fitness=[0;30;120;270]; cv=zeros(4,1);
e=struct('init_FE',4,'trial_FE',4,'pulse_FE',0,'rot_trials',0,...
    'rot_success',0,'pulse_triggers',0,'pulse_trials',0,'pulse_success',0,...
    'pulse_best',0,'jitter_trials',0,'jitter_effective',0,...
    'jitter_candidates',0,'jitter_success',0,'invalid_evals',0);
r=struct('problem_id','F01','variant_id','G0P0J0','seed',1001,...
    'FE',8,'budget_FE',8,'best_f',0,'best_cv',0,'best_x',zeros(1,30),...
    'trace_fe',[4;8],'trace_f',[0;0],'trace_cv',[0;0],...
    'improvement_log',[1,0,0],'events',e,...
    'generation_log',[1,8,NaN,NaN,1,.2,4,0,0,0,0,0],...
    'complete_generations',1,'initial_pop',pop,'initial_f',fitness,'initial_cv',cv,...
    'final_pop',pop,'final_f',fitness,'final_cv',cv,'status','complete',...
    'run_seconds',.01,'rng_scheme','mt19937ar-separated-7-streams',...
    'algorithm_version','PADE-FE-v4.0','options',struct('N',4,'maxFE',8),...
    'variant',struct('id','G0P0J0','geometry',0,'pulse',false,'jitter',false,'classic',false),...
    'code_hash','synthetic-code-hash','config_hash','synthetic-config-hash',...
    'problem_hash','synthetic-problem-hash','synthetic_fixture',true);
end

function writeJson(file,value)
writeNote(file,jsonencode(value,PrettyPrint=true));
end

function writeNote(file,value)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',value);
end
