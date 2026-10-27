function report = pade_audit_runs(root, opts)
%PADE_AUDIT_RUNS Independently audit saved PADE-FE runs against frozen inputs.
%   REPORT = PADE_AUDIT_RUNS(ROOT) reads CONFIG.json, FROZEN_MANIFEST.json and
%   the expected raw MAT files. It never calls an optimizer or edits raw data.
%   It re-evaluates deterministic terminal best_x once per saved run; F07 is
%   explicitly excluded because its objective includes a fresh RAND draw.
%   Output: audit_summary.json, audit_runs.csv, audit_issues.csv,
%   raw_manifest.csv, frozen_file_manifest.csv and AUDIT_README.md.
%   StrictPlan=false is ONLY for explicitly synthetic, small audit fixtures.
arguments
    root (1,1) string
    opts.OutputDir (1,1) string = ""
    opts.AllowPartial (1,1) logical = false
    opts.HashRawFiles (1,1) logical = true
    opts.CheckFrozenFiles (1,1) logical = true
    opts.ReevaluateBest (1,1) logical = true
    opts.StrictPlan (1,1) logical = true
    opts.NumericULPs (1,1) double {mustBeInteger,mustBePositive} = 64
end
started = tic;
assert(isfolder(root),'PADE:AuditRoot','Audit root does not exist.');
rawDir = fullfile(root,'raw');
if opts.OutputDir=="", outDir=fullfile(root,'qa','run_audit');
else, outDir=opts.OutputDir; end
assert(~strcmpi(outDir,rawDir) && ...
    ~startsWith(lower(outDir),lower(rawDir+filesep)),...
    'PADE:AuditOutput','Audit output must be outside raw/.');
if ~isfolder(outDir), mkdir(outDir); end
cfg = jsondecode(fileread(fullfile(root,'CONFIG.json')));
frozen = jsondecode(fileread(fullfile(root,'FROZEN_MANIFEST.json')));
probs = pade_problems();
issues = repmat(issueTemplate(),0,1);
fileRows = repmat(fileTemplate(),0,1);
rows = repmat(runTemplate(),0,1);
seeds = double(cfg.seeds(:));
expectedCount=0; expectedFE=0;
for p=1:numel(cfg.problems)
    cp=cfg.problems(p);
    expectedCount=expectedCount+numel(seeds)*numel(string(cp.variants));
    expectedFE=expectedFE+numel(seeds)*numel(string(cp.variants))*cp.maxFE;
end
check(numel(unique(seeds))==numel(seeds),'PlanSeeds','CONFIG.json','Duplicate planned seeds.');
check(expectedCount==cfg.total_runs,'PlanCount','CONFIG.json','Derived run count differs from total_runs.');
check(expectedFE==cfg.total_search_FE,'PlanFE','CONFIG.json','Derived total FE differs from total_search_FE.');
check(all([cfg.problems.runs]==numel(seeds)) && cfg.runs==numel(seeds),...
    'PlanReplication','CONFIG.json','Problem/config run counts differ from seed count.');
if opts.StrictPlan, checkCanonicalPlan(); end
if opts.CheckFrozenFiles
    auditFrozenGroup(frozen.code_files,fullfile(root,'code'),'code');
    auditFrozenGroup(frozen.protocol_files,root,'protocol');
    inputManifest=fullfile(root,'INPUT_MANIFEST.json');
    if isfile(inputManifest)
        inputs=jsondecode(fileread(inputManifest));
        for inputIndex=1:numel(inputs)
            record=fileTemplate(); record.kind="original_input";
            record.source_file=string(inputs(inputIndex).path); record.expected_sha256=string(inputs(inputIndex).sha256);
            record.exists=isfile(record.source_file);
            if record.exists
                record.actual_sha256=sha256File(record.source_file);
                record.passed=record.actual_sha256==record.expected_sha256;
            end
            check(record.passed,'OriginalInputBytes',record.source_file,'Original supplied input changed or is missing.');
            fileRows(end+1)=record; %#ok<AGROW>
        end
        if opts.StrictPlan, check(numel(inputs)==4,'OriginalInputCount',inputManifest,'Expected four preserved original inputs.'); end
    elseif opts.StrictPlan
        addIssue('error','OriginalInputManifestMissing',inputManifest,'Missing manifest for the four supplied original inputs.');
    end
else
    addIssue('warning','FrozenFileCheckDisabled','FROZEN_MANIFEST.json',...
        'Frozen source/protocol byte hashes were not verified; fixture/diagnostic mode only.');
end
inventory=dir(fullfile(rawDir,'**','*.mat'));
observed=string(fullfile({inventory.folder},{inventory.name}))';
expectedPaths=strings(expectedCount,1); rowIndex=0; pairedCount=0;
for p=1:numel(cfg.problems)
    cp=cfg.problems(p); problemID=string(cp.id);
    match=find(strcmp({probs.id},cp.id));
    if numel(match)~=1
        addIssue('error','UnknownProblem','CONFIG.json','Problem id is absent or duplicated in the problem library: '+problemID);
        continue;
    end
    prob=probs(match); variants=string(cp.variants(:));
    for s=1:numel(seeds)
        reference=[]; referenceID="";
        for v=1:numel(variants)
            rowIndex=rowIndex+1; variantID=variants(v); seed=seeds(s);
            file=fullfile(rawDir,problemID,sprintf('%s__%s__s%d.mat',problemID,variantID,seed));
            expectedPaths(rowIndex)=file;
            row=runTemplate(); row.problem_id=problemID; row.variant_id=variantID;
            row.seed=seed; row.expected_FE=cp.maxFE; row.source_file=file;
            before=numel(issues); row.exists=isfile(file);
            if ~row.exists
                severity='error'; if opts.AllowPartial, severity='warning'; end
                addIssue(severity,'MissingRun',file,'Expected problem/variant/seed run is missing.');
                row.issue_count=numel(issues)-before; rows(end+1)=row; %#ok<AGROW>
                continue;
            end
            metadata=dir(file); row.bytes=metadata.bytes;
            try
                if opts.HashRawFiles, row.sha256=sha256File(file); end
                payload=load(file,'result');
                assert(isfield(payload,'result'),'PADE:AuditSchema','MAT file has no result variable.');
                r=payload.result;
                auditRun(r,prob,cp,variantID,seed,file);
                row.loaded=true; row.FE=r.FE; row.status=string(r.status);
                row.best_f=r.best_f; row.best_cv=r.best_cv;
                row.run_seconds=r.run_seconds;
                row.trial_FE=r.events.trial_FE; row.pulse_FE=r.events.pulse_FE;
                row.invalid_evals=r.events.invalid_evals;
                if isempty(reference)
                    reference=struct('pop',r.initial_pop,'f',r.initial_f,'cv',r.initial_cv);
                    referenceID=variantID; row.initial_pair_equal=true;
                else
                    row.initial_pair_equal=bitEqual(reference.pop,r.initial_pop) && ...
                        bitEqual(reference.f,r.initial_f) && bitEqual(reference.cv,r.initial_cv);
                    pairedCount=pairedCount+1;
                    check(row.initial_pair_equal,'PairedInitialization',file,...
                        'Initial population/objective/CV bytes differ from '+referenceID+'.');
                end
                row.initial_reference=referenceID;
                if problemID=="F07"
                    row.reevaluation="skipped_stochastic_F07";
                    check(r.best_cv==0,'F07CV',file,'The unconstrained F07 CV must equal zero exactly.');
                elseif opts.ReevaluateBest
                    [fCheck,cvCheck]=prob.eval(r.best_x);
                    row.reevaluation="deterministic";
                    row.reeval_f=fCheck; row.reeval_cv=cvCheck;
                    row.reeval_f_abs_error=abs(fCheck-r.best_f);
                    row.reeval_cv_abs_error=abs(cvCheck-r.best_cv);
                    check(closeNumeric(fCheck,r.best_f),'BestObjectiveReevaluation',file,...
                        sprintf('Saved/recomputed objective: %.17g / %.17g.',r.best_f,fCheck));
                    check(closeNumeric(cvCheck,r.best_cv),'BestCVReevaluation',file,...
                        sprintf('Saved/recomputed CV: %.17g / %.17g.',r.best_cv,cvCheck));
                    check((cvCheck==0)==(r.best_cv==0),'StrictFeasibilityIdentity',file,...
                        'Saved/recomputed CV zero/nonzero feasibility differs; tolerance cannot relax feasibility.');
                else
                    row.reevaluation="disabled";
                end
            catch err
                addIssue('error','RunReadOrSchema',file,string(err.identifier)+": "+string(err.message));
            end
            row.issue_count=numel(issues)-before;
            row.passed=row.loaded && ~any(string({issues(before+1:end).severity})=="error");
            rows(end+1)=row; %#ok<AGROW>
        end
    end
end
expectedPaths=expectedPaths(expectedPaths~="");
unexpected=setdiff(observed,expectedPaths);
for k=1:numel(unexpected)
    addIssue('error','UnexpectedRawFile',unexpected(k),'MAT file is not in the frozen expected run matrix.');
end
parts=dir(fullfile(rawDir,'**','*.part*'));
for k=1:numel(parts)
    severity='error'; if opts.AllowPartial, severity='warning'; end
    addIssue(severity,'PartialWriteArtifact',fullfile(parts(k).folder,parts(k).name),...
        'Unfinished atomic-write artifact remains in raw/.');
end
failureArtifacts=dir(fullfile(root,'failures','**','*.mat'));
runTable=struct2table(rows); issueTable=struct2table(issues);
fileTable=struct2table(fileRows);
loaded=runTable.loaded; completed=loaded & runTable.status=="complete" & ...
    runTable.FE==runTable.expected_FE;
errorCount=sum(string({issues.severity})=="error");
warningCount=sum(string({issues.severity})=="warning");
complete=height(runTable)==expectedCount && all(runTable.exists) && ...
    all(loaded) && isempty(unexpected) && isempty(parts);
status="failed";
if errorCount==0 && complete && all(runTable.passed), status="passed";
elseif errorCount==0 && opts.AllowPartial, status="partial"; end
report=struct('schema_version','pade-independent-run-audit-1.0',...
    'created_at_utc',char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")),...
    'root',char(root),'status',char(status),'passed',status=="passed",'complete',complete,...
    'strict_canonical_plan',opts.StrictPlan,'expected_runs',expectedCount,...
    'observed_mat_files',numel(inventory),'expected_files_found',sum(runTable.exists),...
    'loaded_runs',sum(loaded),'valid_runs',sum(runTable.passed),...
    'completed_exact_FE_runs',sum(completed),'missing_runs',sum(~runTable.exists),...
    'unexpected_mat_files',numel(unexpected),'partial_write_artifacts',numel(parts),...
    'failure_attempt_artifacts',numel(failureArtifacts),...
    'expected_search_FE',expectedFE,'successful_total_FE',sum(runTable.FE(completed)),...
    'audited_valid_total_FE',sum(runTable.FE(runTable.passed)),...
    'sum_successful_run_seconds',sum(runTable.run_seconds(completed)),...
    'paired_initialization_checks',pairedCount,...
    'paired_initialization_failures',sum(loaded & ~runTable.initial_pair_equal),...
    'deterministic_best_reevaluations',sum(runTable.reevaluation=="deterministic"),...
    'stochastic_F07_reevaluations_skipped',sum(runTable.reevaluation=="skipped_stochastic_F07"),...
    'error_count',errorCount,'warning_count',warningCount,...
    'numeric_ulps',opts.NumericULPs,'numeric_tolerance_formula','NumericULPs*eps*max(1,abs(values))',...
    'feasibility_tolerance',0,'raw_hashes_enabled',opts.HashRawFiles,...
    'frozen_file_hashes_checked',opts.CheckFrozenFiles,...
    'hash_backend','native .NET SHA256 on Windows; Java MessageDigest otherwise',...
    'deterministic_reevaluation_enabled',opts.ReevaluateBest,...
    'frozen_code_hash',frozen.code_hash,'frozen_problem_hash',frozen.problem_hash,...
    'frozen_config_hash',frozen.config_hash,...
    'CONFIG_file_sha256',sha256File(fullfile(root,'CONFIG.json')),...
    'FROZEN_MANIFEST_file_sha256',sha256File(fullfile(root,'FROZEN_MANIFEST.json')),...
    'auditor_file_sha256',sha256File(string(mfilename('fullpath'))+".m"),...
    'audit_elapsed_seconds',toc(started));
writetable(runTable,fullfile(outDir,'audit_runs.csv'),'Encoding','UTF-8');
writetable(issueTable,fullfile(outDir,'audit_issues.csv'),'Encoding','UTF-8');
writetable(runTable(:,{'problem_id','variant_id','seed','source_file','bytes','sha256'}),...
    fullfile(outDir,'raw_manifest.csv'),'Encoding','UTF-8');
writetable(fileTable,fullfile(outDir,'frozen_file_manifest.csv'),'Encoding','UTF-8');
writeText(fullfile(outDir,'audit_summary.json'),jsonencode(report,PrettyPrint=true));
writeReadme();
report.runs=runTable; report.issues=issueTable; report.frozen_files=fileTable;

    function auditRun(r,prob,cp,variantID,seed,file)
        required={'problem_id','variant_id','seed','FE','budget_FE','best_f','best_cv',...
            'best_x','trace_fe','trace_f','trace_cv','improvement_log','events',...
            'generation_log','complete_generations','initial_pop','initial_f','initial_cv',...
            'final_pop','final_f','final_cv','status','run_seconds','rng_scheme',...
            'algorithm_version','options','variant','config_hash','code_hash','problem_hash'};
        assert(isstruct(r)&&isscalar(r)&&all(isfield(r,required)),...
            'PADE:AuditSchema','Missing required result fields.');
        check(string(r.problem_id)==string(cp.id) && string(r.variant_id)==variantID && r.seed==seed,...
            'RunIdentity',file,'Saved identity differs from the expected filename key.');
        check(string(r.status)=="complete",'RunStatus',file,'Run is not complete.');
        check(r.FE==cp.maxFE && r.budget_FE==cp.maxFE,'ExactFE',file,'Actual/budget FE differs from the frozen problem budget.');
        check(string(r.algorithm_version)==string(cfg.version),'AlgorithmVersion',file,'Algorithm version differs from CONFIG.');
        check(strcmp(r.code_hash,frozen.code_hash) && strcmp(r.config_hash,frozen.config_hash) && ...
            strcmp(r.problem_hash,frozen.problem_hash),'FrozenResultHashes',file,'Run code/config/problem hash differs from the frozen manifest.');
        check(string(r.rng_scheme)=="mt19937ar-separated-7-streams",'RNGScheme',file,'Unexpected random-stream scheme.');
        check(r.options.N==cp.N && r.options.maxFE==cp.maxFE,'RunOptions',file,'Saved N/maxFE differs from CONFIG.');
        if opts.StrictPlan
            parameters={'pBestRate','warmupRatio','pulseEndRatio','gamma','betaCrit','stagnationLimit'};
            for parameterIndex=1:numel(parameters)
                parameter=parameters{parameterIndex};
                check(isfield(r.options,parameter) && r.options.(parameter)==cfg.(parameter),...
                    'OperativeParameter',file,'Saved operative parameter differs from CONFIG: '+string(parameter));
            end
            check(isfield(r,'run_index') && r.run_index==seed-1000 && ...
                isfield(r,'problem_index') && r.problem_index==cp.index,...
                'RunIndices',file,'Saved run/problem indices differ from the frozen task matrix.');
        end
        if isfield(r.options,'stop_after_generations')
            check(isinf(r.options.stop_after_generations),'DiagnosticOption',file,'Finite diagnostic generation stop occurs in formal raw output.');
        end
        if isfield(r.options,'force_quiet'), check(~r.options.force_quiet,'DiagnosticQuiet',file,'force_quiet was enabled in a formal run.'); end
        check(isfinite(r.run_seconds) && isscalar(r.run_seconds) && r.run_seconds>=0,...
            'RunElapsedTime',file,'Invalid run elapsed time.');
        expectedVariant=decodeVariant(variantID);
        names={'geometry','pulse','jitter','classic'};
        check(string(r.variant.id)==variantID,'VariantID',file,'Saved variant struct id differs.');
        for n=1:numel(names)
            name=names{n}; check(r.variant.(name)==expectedVariant.(name),...
                'VariantFlags',file,'Saved flag differs from variant id: '+string(name));
        end
        assert(isequal(size(r.initial_pop),[cp.N,prob.D]) && ...
            isequal(size(r.final_pop),[cp.N,prob.D]),'PADE:AuditPopulationShape','Population size mismatch.');
        assert(numel(r.initial_f)==cp.N && numel(r.initial_cv)==cp.N && ...
            numel(r.final_f)==cp.N && numel(r.final_cv)==cp.N,...
            'PADE:AuditPopulationShape','Population objective/CV size mismatch.');
        check(all(isfinite(r.best_x)) && numel(r.best_x)==prob.D && ...
            isfinite(r.best_f) && isfinite(r.best_cv) && r.best_cv>=0,...
            'TerminalValueShape',file,'Invalid terminal best_x/f/CV.');
        checkCoordinates(r.initial_pop,prob,file,'initial');
        checkCoordinates(r.final_pop,prob,file,'final');
        checkCoordinates(reshape(r.best_x,1,[]),prob,file,'best');
        allCV=[r.initial_cv(:);r.final_cv(:)];
        check(all(isreal(allCV)) && all(allCV>=0) && ~any(isnan(allCV)),...
            'PopulationCV',file,'Population CV must be nonnegative real and not NaN.');
        if isempty(prob.discrete_idx)
            check(~expectedVariant.jitter,'ContinuousJitterVariant',file,'A redundant jitter-on variant is present for a continuous problem.');
        end
        checkTrace(r.trace_fe,r.trace_f,r.trace_cv,r.FE,file,'trace');
        check(r.trace_fe(1)==cp.N,'TraceInitialization',file,'Trace does not start at initialization FE=N.');
        check(r.trace_f(end)==r.best_f && r.trace_cv(end)==r.best_cv,...
            'TraceTerminal',file,'Last trace point differs from saved terminal best.');
        initIndex=1;
        for initialIndex=2:cp.N
            if debBetter(r.initial_f(initialIndex),r.initial_cv(initialIndex),r.initial_f(initIndex),r.initial_cv(initIndex))
                initIndex=initialIndex;
            end
        end
        check(r.trace_f(1)==r.initial_f(initIndex) && r.trace_cv(1)==r.initial_cv(initIndex),...
            'InitialBest',file,'First trace point differs from Deb best of initialization.');
        for finalIndex=1:cp.N
            check(~debBetter(r.final_f(finalIndex),r.final_cv(finalIndex),r.best_f,r.best_cv),...
                'FinalPopulationBest',file,'A final population member dominates the saved best.');
        end
        member=all(r.final_pop==reshape(r.best_x,1,[]),2) & ...
            r.final_f(:)==r.best_f & r.final_cv(:)==r.best_cv;
        check(any(member),'BestInFinalPopulation',file,'Saved historical best is absent from the final elitist population.');
        imp=r.improvement_log;
        assert(size(imp,2)==3 && ~isempty(imp),'PADE:AuditImprovement','Invalid improvement log shape.');
        checkTrace(imp(:,1),imp(:,2),imp(:,3),r.FE,file,'improvement');
        check(imp(end,2)==r.best_f && imp(end,3)==r.best_cv,...
            'ImprovementTerminal',file,'Last improvement differs from terminal best.');
        check(all(debBetterVector(imp(2:end,2),imp(2:end,3),imp(1:end-1,2),imp(1:end-1,3))),...
            'ImprovementStrict',file,'Improvement log contains a non-improving record.');
        auditCounters(r,cp,expectedVariant,prob,file);
    end

    function checkCoordinates(x,prob,file,label)
        lb=reshape(prob.lb,1,[]); ub=reshape(prob.ub,1,[]);
        tol=opts.NumericULPs*eps.*max(1,max(abs(lb),abs(ub)));
        check(all(isfinite(x),'all') && all(x>=lb-tol & x<=ub+tol,'all'),...
            'Bounds',file,'Coordinates outside box or nonfinite: '+string(label));
        for kk=1:numel(prob.discrete_idx)
            d=prob.discrete_idx(kk); q=x(:,d)/prob.discrete_step(kk);
            check(all(abs(q-round(q))<=opts.NumericULPs*eps.*max(1,abs(q))),...
                'DiscreteGrid',file,'Coordinate off discrete grid: '+string(label));
        end
    end

    function checkTrace(fe,f,cv,terminalFE,file,label)
        fe=fe(:); f=f(:); cv=cv(:);
        assert(~isempty(fe)&&numel(fe)==numel(f)&&numel(fe)==numel(cv),...
            'PADE:AuditTrace','Trace vector lengths differ or are empty.');
        check(all(isfinite(fe)) && all(fe==floor(fe)) && all(fe>0) && ...
            all(diff(fe)>0) && fe(end)<=terminalFE,'TraceFE',file,'Invalid increasing FE coordinates: '+string(label));
        check(all(isfinite(f)) && all(isfinite(cv)) && all(cv>=0),...
            'TraceValues',file,'Invalid f/CV trace values: '+string(label));
        if string(label)=="trace", check(fe(end)==terminalFE,'TraceLastFE',file,'Trace does not reach terminal FE.'); end
        check(~any(debBetterVector(f(1:end-1),cv(1:end-1),f(2:end),cv(2:end))),...
            'DebTraceMonotonic',file,'Best-so-far trace worsens under exact Deb order: '+string(label));
    end

    function auditCounters(r,cp,v,prob,file)
        e=r.events;
        names={'init_FE','trial_FE','pulse_FE','rot_trials','rot_success',...
            'pulse_triggers','pulse_trials','pulse_success','pulse_best','jitter_trials',...
            'jitter_effective','jitter_candidates','jitter_success','invalid_evals'};
        assert(isstruct(e)&&isscalar(e)&&all(isfield(e,names)),'PADE:AuditCounters','Missing event counters.');
        vals=cellfun(@(name) double(e.(name)),names);
        check(all(isfinite(vals))&&all(vals>=0)&&all(vals==floor(vals)),...
            'CounterInteger',file,'Event counters must be finite nonnegative integers.');
        check(e.init_FE==cp.N && e.init_FE+e.trial_FE+e.pulse_FE==r.FE,...
            'FEAccounting',file,'Initialization/trial/pulse accounting does not close.');
        check(e.pulse_trials==e.pulse_FE && e.pulse_success<=e.pulse_trials && ...
            e.pulse_best<=e.pulse_success && e.pulse_triggers<=e.pulse_trials && ...
            e.pulse_trials<=max(1,round(.2*cp.N))*e.pulse_triggers,...
            'PulseCounters',file,'Inconsistent pulse counters.');
        check(e.rot_success<=e.rot_trials && e.rot_trials<=e.trial_FE,...
            'RotationCounters',file,'Inconsistent rotation counters.');
        check(e.jitter_effective<=e.jitter_trials && e.jitter_candidates<=e.jitter_trials && ...
            e.jitter_candidates<=e.trial_FE && e.jitter_success<=e.jitter_candidates && ...
            e.jitter_trials<=numel(prob.discrete_idx)*e.trial_FE,...
            'JitterCounters',file,'Inconsistent jitter counters.');
        check(e.invalid_evals<=r.FE,'InvalidCounter',file,'Invalid-evaluation count exceeds all FE.');
        if ~v.pulse, check(e.pulse_FE==0 && e.pulse_triggers==0,'PulseDisabled',file,'Pulse activity when P is disabled.'); end
        if ~v.jitter || isempty(prob.discrete_idx), check(e.jitter_trials==0,'JitterDisabled',file,'Jitter activity when J is disabled/continuous.'); end
        if v.geometry==0, check(e.rot_trials==0,'RotationDisabled',file,'Rotation activity when G is disabled.'); end
        check(r.complete_generations==floor(e.trial_FE/cp.N),...
            'CompletedGenerations',file,'Completed-generation count disagrees with normal trial FE.');
        gl=r.generation_log;
        assert(size(gl,2)==12,'PADE:AuditGenerationLog','Generation log must have 12 columns.');
        if isempty(gl)
            check(r.FE==cp.N,'EmptyGenerationLog',file,'Generation log is empty despite post-initialization FE.');
        else
            check(isequal(gl(:,1),(1:size(gl,1))') && gl(end,2)==r.FE && ...
                isequal(gl(:,2),cp.N+cumsum(gl(:,7)+gl(:,8))),...
                'GenerationFEAccounting',file,'Generation FE history does not close.');
            check(sum(gl(:,7))==e.trial_FE && sum(gl(:,8))==e.pulse_FE && ...
                sum(gl(:,9))==e.rot_trials && sum(gl(:,10))==e.jitter_trials,...
                'GenerationEventAccounting',file,'Generation event totals differ from counters.');
            check(all(gl(:,7)>=0 & gl(:,7)<=cp.N) && ...
                all(gl(:,8)>=0 & gl(:,8)<=max(1,round(.2*cp.N))),...
                'GenerationProposalCounts',file,'A generation exceeds normal/pulse proposal limits.');
            previousFE=[cp.N;gl(1:end-1,2)]; active=gl(:,8)>0;
            check(all(previousFE(active)/r.budget_FE>cfg.warmupRatio) && ...
                all(previousFE(active)+gl(active,8)<=ceil(cfg.pulseEndRatio*r.budget_FE)),...
                'PulseFEClock',file,'Pulse activity lies outside its actual-FE gate.');
            checkTrace(gl(:,2),gl(:,11),gl(:,12),r.FE,file,'generation');
            check(gl(end,11)==r.best_f && gl(end,12)==r.best_cv,...
                'GenerationTerminal',file,'Generation log terminal best differs.');
        end
        if isfield(r,'pulseFE'), check(r.pulseFE==e.pulse_FE,'PulseFEAlias',file,'pulseFE alias differs from events.pulse_FE.'); end
    end

    function checkCanonicalPlan()
        ids=[compose("F%02d",(1:23)');"WB";"CB";"PV"];
        actual=string({cfg.problems.id})';
        check(isequal(actual,ids) && isequal(seeds,(1001:1030)'),...
            'CanonicalProblemSeeds','CONFIG.json','Expected F01-F23/WB/CB/PV and seeds 1001:1030.');
        check(expectedCount==5640 && expectedFE==194577300,...
            'CanonicalTotals','CONFIG.json','Expected 5640 runs and 194577300 search FE.');
        for pp=1:numel(cfg.problems)
            cp=cfg.problems(pp); id=string(cp.id);
            if startsWith(id,"F")
                n=30; number=str2double(extractAfter(id,1));
                if number<=13
                    budget=30030;
                else
                    budget=15030;
                end
            else
                n=40; budget=100040;
            end
            check(cp.N==n && cp.maxFE==budget,'CanonicalBudget','CONFIG.json','Unexpected N/maxFE for '+id);
            planned=strings(7+6*double(id=="PV"),1); plannedIndex=0;
            for gg=0:2
                for ppulse=0:1
                    for jj=0:double(id=="PV")
                        plannedIndex=plannedIndex+1;
                        planned(plannedIndex)=sprintf('G%dP%dJ%d',gg,ppulse,jj);
                    end
                end
            end
            planned(end)="CLASSIC_DE";
            check(isequal(string(cp.variants(:)),planned),'CanonicalVariants','CONFIG.json','Unexpected nested variant matrix for '+id);
        end
        check(cfg.cv_tolerance==0,'CanonicalCV','CONFIG.json','Protocol requires strict CV==0.');
    end

    function auditFrozenGroup(group,folder,kind)
        names=fieldnames(group);
        for frozenIndex=1:numel(names)
            % jsondecode maps the dot in filenames to underscore.
            field=names{frozenIndex}; filename=regexprep(field,'_(m|json|md|csv)$', '.$1');
            file=fullfile(folder,filename); record=fileTemplate();
            record.kind=string(kind); record.source_file=file;
            record.expected_sha256=string(group.(field)); record.exists=isfile(file);
            if record.exists
                record.actual_sha256=sha256File(file);
                record.passed=record.actual_sha256==record.expected_sha256;
            end
            check(record.passed,'FrozenFileBytes',file,'Frozen source/protocol byte hash mismatch or missing file.');
            fileRows(end+1)=record; %#ok<AGROW>
        end
    end

    function check(condition,code,file,detail)
        if ~isscalar(condition)||~condition, addIssue('error',code,file,detail); end
    end

    function addIssue(severity,code,file,detail)
        issues(end+1)=struct('severity',string(severity),'code',string(code),...
            'source_file',string(file),'detail',string(detail));
    end

    function tf=closeNumeric(a,b)
        tf=isscalar(a)&&isscalar(b)&&isfinite(a)&&isfinite(b) && ...
            abs(a-b)<=opts.NumericULPs*eps*max([1,abs(a),abs(b)]);
    end

    function writeReadme()
        text=sprintf(['# PADE独立运行审计\n\n状态：%s。预期%d项，载入%d项，通过%d项。',...
            '错误%d项，警告%d项。\n\n',...
            '- 严格按CONFIG问题/变体/种子矩阵查找，不从已完成子集反推应有覆盖率。\n',...
            '- 核对冻结源码和协议逐文件SHA-256，并核对每份运行的code/config/problem hash。\n',...
            '- 初始种群、初始f和CV使用double底层uint64逐位比较，包含正负零差别。\n',...
            '- 边界/网格及确定性复算容差为%d*eps*max(1,绝对值尺度)。',...
            'CV==0的可行身份严格比较，任何零/非零变化都会报错。\n',...
            '- F07含随机噪声，跳过best_x目标重算；仍核对初值逐位配对、FE、CV和Deb历史。\n',...
            '- 非有限候选允许留在群体原始记录中，但终端best和best轨迹必须有限。\n',...
            '- successful_total_FE只累加status=complete且终端FE等于计划预算的已载入运行；',...
            'audited_valid_total_FE另要求该运行所有审计检查通过。\n',...
            '- sum_successful_run_seconds为各运行耗时之和，不等于六worker并行墙钟时间。\n',...
            '- failures目录按历史失败尝试计数；完整有效的后续运行存在时不将历史日志自动当作缺失运行。\n',...
            '- 本程序不执行优化器、不更改raw，不将客观审计结论解释为算法胜出或投稿通过。\n\n',...
            '详表：audit_runs.csv、audit_issues.csv、raw_manifest.csv、frozen_file_manifest.csv。\n'],...
            status,expectedCount,sum(loaded),sum(runTable.passed),errorCount,warningCount,opts.NumericULPs);
        writeText(fullfile(outDir,'AUDIT_README.md'),text);
    end
end

function tf=debBetter(f1,c1,f2,c2)
if c1==0 && c2==0, tf=f1<f2;
elseif c1==0, tf=true;
elseif c2==0, tf=false;
else, tf=c1<c2;
end
end

function tf=bitEqual(a,b)
tf=isa(a,'double') && isa(b,'double') && isequal(size(a),size(b)) && ...
    isequal(typecast(a(:),'uint64'),typecast(b(:),'uint64'));
end

function tf=debBetterVector(f1,c1,f2,c2)
tf=(c1==0 & c2==0 & f1<f2) | (c1==0 & c2~=0) | ...
    (c1>0 & c2>0 & c1<c2);
end

function v=decodeVariant(id)
if id=="CLASSIC_DE", v=struct('geometry',0,'pulse',false,'jitter',false,'classic',true);
else
    token=regexp(char(id),'^G([012])P([01])J([01])$','tokens','once');
    assert(~isempty(token),'PADE:AuditVariant','Unrecognized variant identifier.');
    v=struct('geometry',str2double(token{1}),'pulse',logical(str2double(token{2})),...
        'jitter',logical(str2double(token{3})),'classic',false);
end
end

function hash=sha256File(file)
if ispc
    % Native CLR hashing works in Windows MATLAB even when Java is disabled.
    digest=System.Security.Cryptography.SHA256.Create();
    stream=System.IO.File.OpenRead(char(file));
    cleanup=onCleanup(@() disposeHash(stream,digest));
    value=uint8(digest.ComputeHash(stream));
    hash=string(lower(reshape(dec2hex(value,2)',1,[])));
    return;
end
fid=fopen(file,'rb'); assert(fid>=0,'PADE:AuditHashRead','Cannot read file for hashing.');
cleanup=onCleanup(@() fclose(fid));
digest=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes=fread(fid,1024*1024,'*uint8');
    if ~isempty(bytes), digest.update(typecast(bytes,'int8')); end
end
value=typecast(digest.digest(),'uint8');
hash=string(lower(reshape(dec2hex(value,2)',1,[])));
end

function disposeHash(stream,digest)
stream.Close(); digest.Dispose();
end

function writeText(file,text)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0,'PADE:AuditWrite','Cannot write audit output.');
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',text);
end

function row=runTemplate()
row=struct('problem_id',"",'variant_id',"",'seed',NaN,'expected_FE',NaN,...
    'source_file',"",'exists',false,'loaded',false,'passed',false,'issue_count',0,...
    'FE',NaN,'status',"missing",'best_f',NaN,'best_cv',NaN,'run_seconds',NaN,...
    'trial_FE',NaN,'pulse_FE',NaN,'invalid_evals',NaN,'bytes',NaN,'sha256',"",...
    'initial_reference',"",'initial_pair_equal',false,'reevaluation',"not_checked",...
    'reeval_f',NaN,'reeval_cv',NaN,'reeval_f_abs_error',NaN,'reeval_cv_abs_error',NaN);
end

function issue=issueTemplate()
issue=struct('severity',"",'code',"",'source_file',"",'detail',"");
end

function file=fileTemplate()
file=struct('kind',"",'source_file',"",'exists',false,'expected_sha256',"",...
    'actual_sha256',"",'passed',false);
end
