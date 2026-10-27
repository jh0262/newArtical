function report = pade_analyze(rawDir, outDir, comparisons, opts)
%PADE_ANALYZE Reproducible paired analysis of saved, completed PADE runs.
% report = pade_analyze(rawDir,outDir,comparisons,Name=Value)
% comparisons is a table with family_id, a_id, b_id (string variables).
% Optional comparisons.problem_id gives one explicit problem per CSV row.
% Alternatively comparisons.problem_ids is a cell column of string vectors;
% otherwise every ExpectedProblems entry (or every observed problem) is used.
% Positive effects and a "win" always favour variant a_id (minimisation).
%
% Each MAT file must contain a scalar structure named result with fields:
% problem_id, variant_id, seed, FE, best_f, best_cv, best_x,
% trace_fe, trace_f, trace_cv. Optional: status, budget_FE, pulseFE,
% run_seconds, events (scalar numeric fields), config_hash, code_hash,
% problem_hash and rng_scheme. No optimiser or objective is called here.
%
% All-pairs-feasible problems: paired Wilcoxon signed-rank on b_f-a_f.
% All-pairs-infeasible problems: signed-rank on b_cv-a_cv.
% Mixed feasibility: exact paired sign test on Deb-ordered wins/losses;
% objective signed-rank for the both-feasible subset is exploratory only.
% This avoids combining objective and CV differences of unrelated units.
% Signed-rank uses exact sign-randomisation DP for <= ExactMaxN nonzero
% pairs, including averaged ties. No Statistics Toolbox is required.
%
% Holm adjustment is over ALL prespecified problem/pair tests in a family.
% With AllowPartial=true, missing tests retain NaN p-values but count in
% the family's planned multiplicity. Partial output is marked descriptive.
arguments
    rawDir (1,1) string
    outDir (1,1) string
    comparisons table = table()
    opts.FeasibilityTolerance (1,1) double {mustBeNonnegative} = 0
    opts.Alpha (1,1) double {mustBeGreaterThan(opts.Alpha,0),mustBeLessThan(opts.Alpha,1)} = 0.05
    opts.ExpectedRuns (1,1) double {mustBeInteger,mustBePositive} = 30
    opts.ExpectedSeeds double = []
    opts.ExpectedProblems string = strings(0,1)
    opts.ExpectedFE double = []
    opts.RequireEqualFE (1,1) logical = true
    opts.AllowPartial (1,1) logical = false
    opts.ZeroAbsTolerance (1,1) double {mustBeNonnegative} = 0
    opts.ZeroRelTolerance (1,1) double {mustBeNonnegative} = 0
    opts.ExactMaxN (1,1) double {mustBeInteger,mustBePositive} = 50
    opts.TracePoints (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(opts.TracePoints,2)} = 101
end
assert(isfolder(rawDir),'PADE:RawFolder','Raw folder does not exist.');
assert(rawDir~=outDir,'PADE:OutputFolder','Keep analysis output separate from raw files.');
if ~isfolder(outDir), mkdir(outDir); end
files = dir(fullfile(rawDir,'**','*.mat'));
assert(~isempty(files),'PADE:NoRuns','No MAT run files found.');
raw = cell(numel(files),1);
rows = repmat(emptyRunRow(),numel(files),1);
for k=1:numel(files)
    source = string(fullfile(files(k).folder,files(k).name));
    payload = load(source,'result');
    assert(isfield(payload,'result'),'PADE:MissingResult','%s has no result variable.',source);
    r = payload.result;
    validateResult(r,source);
    raw{k}=r;
    rows(k).problem_id = string(r.problem_id);
    rows(k).variant_id = string(r.variant_id);
    rows(k).seed = double(r.seed);
    rows(k).FE = double(r.FE);
    rows(k).best_f = double(r.best_f);
    rows(k).best_cv = double(r.best_cv);
    rows(k).feasible = r.best_cv<=opts.FeasibilityTolerance;
    rows(k).budget_FE = scalarField(r,'budget_FE',r.FE);
    rows(k).pulseFE = scalarField(r,'pulseFE',NaN);
    rows(k).run_seconds = scalarField(r,'run_seconds',NaN);
    rows(k).status = stringField(r,'status','complete');
    rows(k).source_file = source;
    rows(k).raw_index = k;
    rows(k).config_hash = stringField(r,'config_hash','');
    rows(k).code_hash = stringField(r,'code_hash','');
    rows(k).problem_hash = stringField(r,'problem_hash','');
    rows(k).rng_scheme = stringField(r,'rng_scheme','');
    assert(rows(k).status=="complete",'PADE:RunStatus','Run is not complete: %s',source);
    assert(rows(k).FE<=rows(k).budget_FE,'PADE:OverBudget','FE exceeds budget: %s',source);
    if ~isempty(opts.ExpectedFE)
        assert(isscalar(opts.ExpectedFE)&&rows(k).FE==opts.ExpectedFE,...
            'PADE:UnexpectedFE','Unexpected terminal FE: %s',source);
    end
end
runs = struct2table(rows);
keys = runs(:,{'problem_id','variant_id','seed'});
assert(height(unique(keys))==height(keys),'PADE:DuplicateRun','Duplicate (problem,variant,seed) run.');
runs = sortrows(runs,{'problem_id','variant_id','seed'});
runs = appendEvents(runs,raw);
if isempty(opts.ExpectedProblems), problems=unique(runs.problem_id,'stable');
else, problems=opts.ExpectedProblems(:); end
assert(numel(unique(problems))==numel(problems),'PADE:RepeatedProblem','ExpectedProblems contains duplicates.');
summaries = makeSummaries(runs,opts);
[tests,pairs] = makeComparisons(runs,comparisons,problems,opts);
tests = applyHolm(tests,opts.Alpha);
familySummary = summarizeFamilies(tests,opts.Alpha);
familyTotals = summarizeFamilyTotals(tests,opts.Alpha);
traces = summarizeTraces(runs,raw,opts);
analysis = struct('schema_version','pade-analysis-1.0','created_at',...
    char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")),...
    'raw_directory',char(rawDir),'options',opts,'comparisons',comparisons,...
    'runs',runs,'summaries',summaries,'tests',tests,'pairs',pairs,...
    'family_summary',familySummary,'family_totals',familyTotals,'traces',traces,...
    'moment_method','anchor-centred mean and sample standard deviation');
save(fullfile(outDir,'raw.mat'),'raw','-v7.3');
save(fullfile(outDir,'analysis.mat'),'analysis','-v7.3');
writetable(runs,fullfile(outDir,'runs.csv'),'Encoding','UTF-8');
writetable(summaries,fullfile(outDir,'summary.csv'),'Encoding','UTF-8');
writetable(tests,fullfile(outDir,'comparisons.csv'),'Encoding','UTF-8');
writetable(pairs,fullfile(outDir,'paired_observations.csv'),'Encoding','UTF-8');
writetable(familySummary,fullfile(outDir,'families.csv'),'Encoding','UTF-8');
writetable(familyTotals,fullfile(outDir,'family_totals.csv'),'Encoding','UTF-8');
writetable(traces,fullfile(outDir,'trace_summary.csv'),'Encoding','UTF-8');
writeJson(fullfile(outDir,'summary.json'),table2struct(summaries));
writeJson(fullfile(outDir,'comparisons.json'),table2struct(tests));
writeJson(fullfile(outDir,'families.json'),table2struct(familySummary));
writeJson(fullfile(outDir,'family_totals.json'),table2struct(familyTotals));
writeJson(fullfile(outDir,'analysis_protocol.json'),struct(...
    'schema_version',analysis.schema_version,'created_at',analysis.created_at,...
    'options',opts,'comparisons',table2struct(comparisons),...
    'raw_run_count',height(runs),'planned_tests',height(tests)));
writeReadme(outDir,analysis);
report=analysis;
end

function row=emptyRunRow()
row=struct('problem_id',"",'variant_id',"",'seed',0,'FE',0,...
    'best_f',0,'best_cv',0,'feasible',false,'budget_FE',0,'pulseFE',NaN,...
    'run_seconds',NaN,'status',"",'source_file',"",'raw_index',0,...
    'config_hash',"",'code_hash',"",'problem_hash',"",'rng_scheme',"");
end

function validateResult(r,source)
required={'problem_id','variant_id','seed','FE','best_f','best_cv','best_x',...
    'trace_fe','trace_f','trace_cv'};
assert(isstruct(r)&&isscalar(r)&&all(isfield(r,required)),...
    'PADE:RunSchema','Invalid result schema: %s',source);
assert(isscalar(string(r.problem_id))&&strlength(string(r.problem_id))>0&&...
    isscalar(string(r.variant_id))&&strlength(string(r.variant_id))>0,...
    'PADE:RunID','Problem and variant IDs must be nonempty scalar text: %s',source);
validateattributes(r.seed,{'numeric'},{'scalar','finite','integer','nonnegative'});
validateattributes(r.FE,{'numeric'},{'scalar','finite','integer','positive'});
validateattributes(r.best_f,{'numeric'},{'scalar','real','finite'});
validateattributes(r.best_cv,{'numeric'},{'scalar','real','finite','nonnegative'});
validateattributes(r.best_x,{'numeric'},{'vector','real','finite','nonempty'});
fe=double(r.trace_fe(:)); f=double(r.trace_f(:)); cv=double(r.trace_cv(:));
assert(~isempty(fe)&&numel(fe)==numel(f)&&numel(fe)==numel(cv)&&...
    all(isfinite(fe))&&all(isfinite(f))&&all(isfinite(cv))&&all(cv>=0)&&...
    all(fe>0)&&all(fe==fix(fe))&&all(diff(fe)>0)&&fe(end)==r.FE,...
    'PADE:TraceSchema','Invalid FE trace: %s',source);
assert(f(end)==r.best_f&&cv(end)==r.best_cv,...
    'PADE:TraceTerminal','Terminal trace differs from terminal result: %s',source);
end

function value=scalarField(s,name,default)
if isfield(s,name)
    value=double(s.(name));
    assert(isscalar(value)&&isreal(value),'PADE:ScalarField','%s must be scalar real.',name);
else
    value=double(default);
end
end

function value=stringField(s,name,default)
if isfield(s,name), value=string(s.(name)); else, value=string(default); end
assert(isscalar(value),'PADE:StringField','%s must be scalar text.',name);
end

function runs=appendEvents(runs,raw)
eventNames=strings(0,1);
for k=1:numel(raw)
    r=raw{k};
    if isfield(r,'events')&&isstruct(r.events)&&isscalar(r.events)
        eventNames=union(eventNames,string(fieldnames(r.events)),'stable');
    end
end
for name=eventNames(:)'
    values=nan(height(runs),1);
    for k=1:height(runs)
        r=raw{runs.raw_index(k)};
        if isfield(r,'events')&&isstruct(r.events)&&isfield(r.events,name)
            candidate=r.events.(name);
            if (isnumeric(candidate)||islogical(candidate))&&isscalar(candidate)&&isreal(candidate)
                values(k)=double(candidate);
            end
        end
    end
    runs.(matlab.lang.makeValidName("event_"+name))=values;
end
end

function summaries=makeSummaries(runs,opts)
groups=unique(runs(:,{'problem_id','variant_id'}),'rows','stable');
rows=repmat(struct('problem_id',"",'variant_id',"",'n_runs',0,...
    'mean_f',NaN,'std_f',NaN,'best_f',NaN,'worst_f',NaN,'median_f',NaN,...
    'mean_feasible_f',NaN,'std_feasible_f',NaN,'n_feasible',0,...
    'feasible_rate',NaN,'mean_cv',NaN,'max_cv',NaN,'min_FE',0,'max_FE',0,...
    'mean_pulseFE',NaN,'mean_seconds',NaN,'complete',false),height(groups),1);
for k=1:height(groups)
    s=runs(runs.problem_id==groups.problem_id(k)&runs.variant_id==groups.variant_id(k),:);
    n=height(s); ok=s.feasible;
    if ~opts.AllowPartial
        assert(n==opts.ExpectedRuns,'PADE:RunCount','%s/%s has %d runs, expected %d.',...
            groups.problem_id(k),groups.variant_id(k),n,opts.ExpectedRuns);
        if ~isempty(opts.ExpectedSeeds)
            assert(isequal(sort(s.seed),sort(opts.ExpectedSeeds(:))),...
                'PADE:SeedCoverage','Seed coverage mismatch.');
        end
    end
    if opts.RequireEqualFE
        assert(isscalar(unique(s.FE)),'PADE:UnequalFE','Unequal within-variant FE.');
    end
    rows(k).problem_id=groups.problem_id(k); rows(k).variant_id=groups.variant_id(k);
    rows(k).n_runs=n; [rows(k).mean_f,rows(k).std_f]=stableMoments(s.best_f);
    rows(k).best_f=min(s.best_f); rows(k).worst_f=max(s.best_f);
    rows(k).median_f=median(s.best_f); rows(k).n_feasible=sum(ok);
    rows(k).feasible_rate=mean(ok); rows(k).mean_cv=stableMoments(s.best_cv); rows(k).max_cv=max(s.best_cv);
    rows(k).min_FE=min(s.FE); rows(k).max_FE=max(s.FE);
    rows(k).mean_pulseFE=stableMoments(s.pulseFE); rows(k).mean_seconds=stableMoments(s.run_seconds);
    rows(k).complete=n==opts.ExpectedRuns;
    if any(ok)
        [rows(k).mean_feasible_f,rows(k).std_feasible_f]=stableMoments(s.best_f(ok));
    end
end
summaries=struct2table(rows);
eventNames=string(runs.Properties.VariableNames);
eventNames=eventNames(startsWith(eventNames,"event_"));
for name=eventNames(:)'
    averages=nan(height(groups),1);
    for k=1:height(groups)
        include=runs.problem_id==groups.problem_id(k)&runs.variant_id==groups.variant_id(k);
        averages(k)=stableMoments(runs.(name)(include));
    end
    summaries.("mean_"+name)=averages;
end
end

function [tests,pairs]=makeComparisons(runs,comparisons,problems,opts)
testRows=repmat(emptyTestRow(),0,1); pairRows=repmat(emptyPairRow(),0,1);
if isempty(comparisons)
    tests=struct2table(testRows); pairs=struct2table(pairRows); return
end
assert(all(ismember({'family_id','a_id','b_id'},comparisons.Properties.VariableNames)),...
    'PADE:ComparisonSchema','comparisons requires family_id, a_id and b_id.');
for c=1:height(comparisons)
    family=string(comparisons.family_id(c)); a=string(comparisons.a_id(c)); b=string(comparisons.b_id(c));
    assert(a~=b,'PADE:SelfComparison','A variant cannot be compared with itself.');
    scope=problems;
    if ismember('problem_id',comparisons.Properties.VariableNames)&&...
            strlength(string(comparisons.problem_id(c)))>0&&string(comparisons.problem_id(c))~="*"
        scope=string(comparisons.problem_id(c));
    elseif ismember('problem_ids',comparisons.Properties.VariableNames)&&~isempty(comparisons.problem_ids{c})
        scope=string(comparisons.problem_ids{c}(:));
    end
    for problem=scope(:)'
        ta=runs(runs.problem_id==problem&runs.variant_id==a,:);
        tb=runs(runs.problem_id==problem&runs.variant_id==b,:);
        [seed,ia,ib]=intersect(ta.seed,tb.seed,'sorted');
        isComplete=numel(seed)==opts.ExpectedRuns&&height(ta)==height(tb)&&height(ta)==numel(seed);
        if ~isempty(opts.ExpectedSeeds), isComplete=isComplete&&isequal(seed,sort(opts.ExpectedSeeds(:))); end
        if ~opts.AllowPartial
            assert(isComplete,'PADE:PairCoverage','Incomplete paired seeds for %s: %s/%s.',problem,a,b);
        end
        ta=ta(ia,:); tb=tb(ib,:);
        if opts.RequireEqualFE&&~isempty(seed)
            assert(all(ta.FE==tb.FE)&&isscalar(unique([ta.FE;tb.FE])),...
                'PADE:UnequalPairFE','Paired FE differ for %s: %s/%s.',problem,a,b);
        end
        r=emptyTestRow(); r.family_id=family; r.problem_id=problem; r.a_id=a; r.b_id=b;
        r.n_pairs=numel(seed); r.complete=isComplete;
        if isempty(seed), testRows(end+1,1)=r; continue; end %#ok<AGROW>
        bothF=ta.feasible&tb.feasible; bothI=~ta.feasible&~tb.feasible;
        signs=zeros(numel(seed),1);
        signs(ta.feasible&~tb.feasible)=1; signs(~ta.feasible&tb.feasible)=-1;
        signs(bothF)=tolerantSign(tb.best_f(bothF)-ta.best_f(bothF),...
            ta.best_f(bothF),tb.best_f(bothF),opts);
        signs(bothI)=tolerantSign(tb.best_cv(bothI)-ta.best_cv(bothI),...
            ta.best_cv(bothI),tb.best_cv(bothI),opts);
        r.wins=sum(signs>0); r.ties=sum(signs==0); r.losses=sum(signs<0);
        r.n_both_feasible=sum(bothF); r.n_a_only_feasible=sum(ta.feasible&~tb.feasible);
        r.n_b_only_feasible=sum(~ta.feasible&tb.feasible); r.n_both_infeasible=sum(bothI);
        r.sign_p=exactSignP(r.wins,r.losses);
        r.sign_effect=(r.wins-r.losses)/max(1,r.wins+r.losses);
        if all(bothF)
            d=tb.best_f-ta.best_f; d(signs==0)=0;
            stat=signedRank(d,opts.ExactMaxN); r.test="paired_signed_rank_objective";
            r.p_raw=stat.p; r.effect=stat.effect; r.effect_type="matched_rank_biserial";
            r.w_plus=stat.wplus; r.w_minus=stat.wminus; r.n_nonzero=stat.n;
            r.method=stat.method;
        elseif all(bothI)
            d=tb.best_cv-ta.best_cv; d(signs==0)=0;
            stat=signedRank(d,opts.ExactMaxN); r.test="paired_signed_rank_CV";
            r.p_raw=stat.p; r.effect=stat.effect; r.effect_type="matched_rank_biserial";
            r.w_plus=stat.wplus; r.w_minus=stat.wminus; r.n_nonzero=stat.n;
            r.method=stat.method;
        else
            r.test="paired_sign_Deb_order"; r.p_raw=r.sign_p;
            r.effect=r.sign_effect; r.effect_type="paired_win_loss_balance";
            r.n_nonzero=r.wins+r.losses; r.method="exact_binomial_two_sided";
        end
        if any(bothF)
            d=tb.best_f(bothF)-ta.best_f(bothF); s=signs(bothF); d(s==0)=0;
            stat=signedRank(d,opts.ExactMaxN);
            r.exploratory_objective_p=stat.p; r.exploratory_objective_effect=stat.effect;
            r.median_objective_improvement=median(tb.best_f(bothF)-ta.best_f(bothF));
        end
        for j=1:numel(seed)
            q=emptyPairRow(); q.family_id=family; q.problem_id=problem; q.a_id=a; q.b_id=b;
            q.seed=seed(j); q.a_f=ta.best_f(j); q.b_f=tb.best_f(j);
            q.a_cv=ta.best_cv(j); q.b_cv=tb.best_cv(j); q.a_FE=ta.FE(j); q.b_FE=tb.FE(j);
            q.a_feasible=ta.feasible(j); q.b_feasible=tb.feasible(j); q.a_win_sign=signs(j);
            q.a_source_file=ta.source_file(j); q.b_source_file=tb.source_file(j);
            pairRows(end+1,1)=q; %#ok<AGROW>
        end
        testRows(end+1,1)=r; %#ok<AGROW>
    end
end
tests=struct2table(testRows); pairs=struct2table(pairRows);
if ~isempty(tests)
    assert(height(unique(tests(:,{'family_id','problem_id','a_id','b_id'})))==height(tests),...
        'PADE:DuplicateTest','Repeated planned comparison in a family.');
end
end

function r=emptyTestRow()
r=struct('family_id',"",'problem_id',"",'a_id',"",'b_id',"",'n_pairs',0,...
    'complete',false,'test',"not_available",'method',"",'p_raw',NaN,...
    'p_holm',NaN,'holm_family_size',0,'reject_holm',false,'decision',"not_available",...
    'wins',0,'ties',0,'losses',0,'n_both_feasible',0,'n_a_only_feasible',0,...
    'n_b_only_feasible',0,'n_both_infeasible',0,'n_nonzero',0,...
    'w_plus',NaN,'w_minus',NaN,'effect',NaN,'effect_type',"",...
    'sign_p',NaN,'sign_effect',NaN,'exploratory_objective_p',NaN,...
    'exploratory_objective_effect',NaN,'median_objective_improvement',NaN);
end

function r=emptyPairRow()
r=struct('family_id',"",'problem_id',"",'a_id',"",'b_id',"",'seed',0,...
    'a_f',NaN,'b_f',NaN,'a_cv',NaN,'b_cv',NaN,'a_FE',NaN,'b_FE',NaN,...
    'a_feasible',false,'b_feasible',false,'a_win_sign',0,...
    'a_source_file',"",'b_source_file',"");
end

function signValue=tolerantSign(d,a,b,opts)
tol=opts.ZeroAbsTolerance+opts.ZeroRelTolerance.*max(abs(a),abs(b));
signValue=sign(d); signValue(abs(d)<=tol)=0;
end

function stat=signedRank(d,exactMaxN)
% The distribution conditions on observed absolute differences. Under a
% symmetric zero-centred null, independent signs are equiprobable.
d=d(:); assert(all(isfinite(d)),'PADE:SignedRankInput','Nonfinite difference.');
d(d==0)=[]; n=numel(d);
stat=struct('n',n,'p',1,'effect',0,'wplus',0,'wminus',0,'method',"all_zero");
if n==0, return; end
[magnitude,index]=sort(abs(d)); ranks=zeros(n,1); start=1;
while start<=n
    stop=start;
    while stop<n&&magnitude(stop+1)==magnitude(start), stop=stop+1; end
    ranks(index(start:stop))=(start+stop)/2;
    start=stop+1;
end
wplus=sum(ranks(d>0)); wminus=sum(ranks(d<0));
stat.wplus=wplus; stat.wminus=wminus; stat.effect=(wplus-wminus)/(wplus+wminus);
if n<=exactMaxN
    % Average ranks are integer or half-integer, so scale by two for exact DP.
    weights=round(2*ranks); distribution=1;
    for k=1:n
        previous=distribution;
        distribution=zeros(1,numel(previous)+weights(k));
        distribution(1:numel(previous))=previous/2;
        shifted=weights(k)+(1:numel(previous));
        distribution(shifted)=distribution(shifted)+previous/2;
    end
    observed=round(2*wplus);
    lower=sum(distribution(1:observed+1)); upper=sum(distribution(observed+1:end));
    stat.p=min(1,2*min(lower,upper)); stat.method="exact_sign_randomisation_DP";
else
    mu=sum(ranks)/2; variance=sum(ranks.^2)/4;
    span=round(2*ranks(1));
    for k=2:n, span=gcd(span,round(2*ranks(k))); end
    continuity=span/4; z=max(0,abs(wplus-mu)-continuity)/sqrt(variance);
    stat.p=min(1,erfc(z/sqrt(2))); stat.method="normal_tie_variance_lattice_corrected";
end
end

function p=exactSignP(wins,losses)
n=wins+losses;
if n==0, p=1; return; end
distribution=1;
for k=1:n, distribution=conv(distribution,[0.5,0.5]); end
p=min(1,2*sum(distribution(1:min(wins,losses)+1)));
end

function tests=applyHolm(tests,alpha)
if isempty(tests), return; end
for family=unique(tests.family_id,'stable')'
    members=find(tests.family_id==family); m=numel(members);
    p=tests.p_raw(members); valid=isfinite(p); p(~valid)=1;
    [sorted,index]=sort(p); adjusted=cummax(min(1,(m-(1:m)'+1).*sorted));
    restored=zeros(m,1); restored(index)=adjusted; restored(~valid)=NaN;
    tests.p_holm(members)=restored; tests.holm_family_size(members)=m;
    tests.reject_holm(members)=isfinite(restored)&restored<=alpha&tests.complete(members);
end
for k=1:height(tests)
    if ~tests.complete(k)
        tests.decision(k)="partial_descriptive";
    elseif ~isfinite(tests.p_raw(k))
        tests.decision(k)="not_available";
    elseif ~tests.reject_holm(k)
        tests.decision(k)="not_significant";
    elseif tests.effect(k)>0
        tests.decision(k)="a_better";
    elseif tests.effect(k)<0
        tests.decision(k)="b_better";
    else
        tests.decision(k)="significant_zero_effect";
    end
end
end

function summary=summarizeFamilies(tests,alpha)
rows=repmat(struct('family_id',"",'a_id',"",'b_id',"",'planned_tests',0,...
    'complete_tests',0,'a_better',0,'not_significant',0,'b_better',0,...
    'unavailable_or_partial',0,'alpha',alpha),0,1);
if ~isempty(tests)
    keys=unique(tests(:,{'family_id','a_id','b_id'}),'rows','stable');
    for k=1:height(keys)
        sub=tests(tests.family_id==keys.family_id(k)&tests.a_id==keys.a_id(k)&tests.b_id==keys.b_id(k),:);
        r=struct('family_id',keys.family_id(k),'a_id',keys.a_id(k),'b_id',keys.b_id(k),...
            'planned_tests',height(sub),'complete_tests',sum(sub.complete),...
            'a_better',sum(sub.decision=="a_better"),...
            'not_significant',sum(sub.decision=="not_significant"),...
            'b_better',sum(sub.decision=="b_better"),...
            'unavailable_or_partial',sum(~sub.complete|~isfinite(sub.p_raw)),'alpha',alpha);
        rows(end+1,1)=r; %#ok<AGROW>
    end
end
summary=struct2table(rows);
end

function traces=summarizeTraces(runs,raw,opts)
rows=repmat(struct('problem_id',"",'variant_id',"",'FE',0,'n_observed',0,...
    'mean_f',NaN,'std_f',NaN,'median_f',NaN,'mean_cv',NaN,'feasible_rate',NaN),0,1);
groups=unique(runs(:,{'problem_id','variant_id'}),'rows','stable');
for k=1:height(groups)
    sub=runs(runs.problem_id==groups.problem_id(k)&runs.variant_id==groups.variant_id(k),:);
    % Never interpolate objectives or invent earlier evaluations. Last
    % observed incumbent is carried forward only after its actual first FE.
    low=min(cellfun(@(r) r.trace_fe(1),raw(sub.raw_index)));
    high=min(sub.FE); grid=unique(round(linspace(low,high,opts.TracePoints)));
    for fe=grid
        f=nan(height(sub),1); cv=f;
        for j=1:height(sub)
            r=raw{sub.raw_index(j)}; index=find(r.trace_fe<=fe,1,'last');
            if ~isempty(index), f(j)=r.trace_f(index); cv(j)=r.trace_cv(index); end
        end
        observed=isfinite(f)&isfinite(cv);
        [fMean,fStd]=stableMoments(f); cvMean=stableMoments(cv);
        q=struct('problem_id',groups.problem_id(k),'variant_id',groups.variant_id(k),...
            'FE',fe,'n_observed',sum(observed),'mean_f',fMean,...
            'std_f',fStd,'median_f',median(f,'omitnan'),...
            'mean_cv',cvMean,...
            'feasible_rate',mean(cv(observed)<=opts.FeasibilityTolerance));
        rows(end+1,1)=q; %#ok<AGROW>
    end
end
traces=struct2table(rows);
end

function summary=summarizeFamilyTotals(tests,alpha)
rows=repmat(struct('family_id',"",'planned_tests',0,'complete_tests',0,...
    'a_better',0,'not_significant',0,'b_better',0,'unavailable_or_partial',0,...
    'alpha',alpha),0,1);
if ~isempty(tests)
    for family=unique(tests.family_id,'stable')'
        sub=tests(tests.family_id==family,:);
        r=struct('family_id',family,'planned_tests',height(sub),...
            'complete_tests',sum(sub.complete),'a_better',sum(sub.decision=="a_better"),...
            'not_significant',sum(sub.decision=="not_significant"),...
            'b_better',sum(sub.decision=="b_better"),...
            'unavailable_or_partial',sum(~sub.complete|~isfinite(sub.p_raw)),'alpha',alpha);
        rows(end+1,1)=r; %#ok<AGROW>
    end
end
summary=struct2table(rows);
end

function writeReadme(outDir,analysis)
fid=fopen(fullfile(outDir,'ANALYSIS_README.md'),'w','n','UTF-8');
assert(fid>=0,'PADE:ReadmeWrite','Cannot write analysis README.'); cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'# PADE supplementary analysis\n\n');
fprintf(fid,'Generated from saved completed runs; no optimiser was run by the analyser.\n\n');
fprintf(fid,'- `raw.mat`: original result structures, indexed by `runs.csv/raw_index`.\n');
fprintf(fid,'- `runs.csv`: one row per source MAT file; no observations removed as outliers.\n');
fprintf(fid,'- `summary.csv`: unconditional objective statistics plus feasible-only statistics, CV, FE and feasible rate.\n');
fprintf(fid,'- `comparisons.csv`: prespecified paired tests and within-family Holm adjustment.\n');
fprintf(fid,'- `paired_observations.csv`: every seed pair, Deb-ordered sign and raw paths.\n');
fprintf(fid,'- `families.csv`: significant wins / no detected difference / significant losses.\n');
fprintf(fid,'- `family_totals.csv`: the same decisions aggregated across variant names within each prespecified family.\n');
fprintf(fid,'- `trace_summary.csv`: last observed incumbents at FE checkpoints; no linear interpolation.\n\n');
fprintf(fid,'A positive effect favours a_id. Paired signed-rank uses b-a on objective if all paired runs are feasible, or on CV if all are infeasible. Mixed-feasibility cases use the exact paired sign test, preserving feasibility priority without mixing units. The both-feasible objective test is exploratory and is not used for the primary Holm decision.\n\n');
fprintf(fid,'Signed-rank assumes symmetric paired differences under its null. Zeros are removed, average ranks are used for ties, and all-zero differences produce p=1 and effect=0. Exact DP conditions on observed absolute ranks (n<=%d); larger n uses tie-aware variance with lattice continuity correction. A nonsignificant test is not evidence of equivalence.\n\n',analysis.options.ExactMaxN);
fprintf(fid,'Feasibility tolerance: %.17g. Difference zero tolerances: absolute %.17g; relative %.17g. Alpha: %.17g. Planned runs per configuration: %d. AllowPartial: %d.\n',...
    analysis.options.FeasibilityTolerance,analysis.options.ZeroAbsTolerance,...
    analysis.options.ZeroRelTolerance,analysis.options.Alpha,...
    analysis.options.ExpectedRuns,analysis.options.AllowPartial);
fprintf(fid,'\nMoments use anchor=x(1), mean=anchor+mean(x-anchor), sample SD=std(x-anchor,0), omitting only NaN where applicable. Identical saved doubles therefore give exactly their saved value and SD=0; raw observations and hypothesis tests are unchanged.\n');
fprintf(fid,'\nRaw run count: %d. Planned problem/pair tests: %d. Complete tests: %d.\n',...
    height(analysis.runs),height(analysis.tests),sum(analysis.tests.complete));
end

function [mu,sd]=stableMoments(x)
% Centring prevents constant non-binary decimals acquiring phantom variance
% from an unshifted mean reduction. NaN omission matches prior summaries.
x=double(x(:)); x=x(~isnan(x));
if isempty(x), mu=NaN; sd=NaN; return; end
anchor=x(1); centred=x-anchor;
mu=anchor+mean(centred); sd=std(centred,0);
end

function writeJson(path,value)
fid=fopen(path,'w','n','UTF-8');
assert(fid>=0,'PADE:JSONWrite','Cannot write JSON.'); cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
