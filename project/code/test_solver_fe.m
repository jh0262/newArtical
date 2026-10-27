function report = test_solver_fe(qaDir)
%TEST_SOLVER_FE Small deterministic implementation checks, not performance.
%   REPORT = TEST_SOLVER_FE(QADIR) writes solver_checks.json and .mat in QA.
%   No data are written to the formal experiment raw directory. Diagnostic
%   gate overrides below exist only to exercise otherwise rare branches.
arguments
    qaDir (1,1) string = ""
end
if strlength(qaDir)==0
    qaDir=fullfile(fileparts(fileparts(mfilename('fullpath'))),'qa');
end
if ~isfolder(qaDir), mkdir(qaDir); end
originalStream=RandStream.getGlobalStream;
restore=onCleanup(@() RandStream.setGlobalStream(originalStream)); %#ok<NASGU>
problems=pade_problems(); continuous=pade_variants(false); discrete=pade_variants(true);
parent=selectVariant(continuous,'G0P0J0'); full=selectVariant(continuous,'G2P1J0');
fullDiscrete=selectVariant(discrete,'G2P1J1'); classic=selectVariant(continuous,'CLASSIC_DE');
base=pade_defaults(1); base.N=8; base.maxFE=121; base.capture_proposals=true;
diagnosticRuns=cell(0,1);
names=["configuration_contract","quiet_continuous_identity","quiet_discrete_identity",...
    "F07_noise_stream","exact_FE_partial_generation","pulse_FE_accounting",...
    "discrete_grid_bounds_below_one","Deb_trace_monotonicity",...
    "diagnostic_stop_status","all_26_midpoints","engineering_fixed_vectors"];
actions={@configurationContract,@quietContinuous,@quietDiscrete,@noiseCheck,...
    @partialGeneration,@pulseBudget,@gridBounds,@debTrace,@diagnosticStop,...
    @midpoints,@engineeringVectors};
checks=repmat(struct('id',"",'passed',false,'detail',struct(),...
    'error_identifier',"",'error_message',""),numel(names),1);
for k=1:numel(names)
    checks(k).id=names(k);
    try
        checks(k).detail=actions{k}(); checks(k).passed=true;
    catch exception
        checks(k).error_identifier=string(exception.identifier);
        checks(k).error_message=string(exception.message);
    end
end
report=struct('scope','IMPLEMENTATION DIAGNOSTICS ONLY; NOT PERFORMANCE EXPERIMENTS',...
    'passed',all([checks.passed]),'n_checks',numel(checks),...
    'n_passed',sum([checks.passed]),'checks',checks,...
    'diagnostic_run_count',numel(diagnosticRuns),...
    'note','The pulse test deliberately overrides gates to exercise FE accounting.');
save(fullfile(qaDir,'solver_checks.mat'),'report','diagnosticRuns','-v7.3');
fid=fopen(fullfile(qaDir,'solver_checks.json'),'w','n','UTF-8');
assert(fid>=0,'pade:CheckWrite','Cannot write diagnostic JSON.');
fileCleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(report,'PrettyPrint',true));
assert(report.passed,'pade:SolverChecksFailed',...
    '%d of %d checks failed; see QA/solver_checks.json.',numel(checks)-report.n_passed,numel(checks));

    function detail=configurationContract()
        assert(numel(problems)==26&&numel(continuous)==7&&numel(discrete)==13);
        assert(numel(unique(string({problems.id})))==26);
        a=pade_defaults(1); b=pade_defaults(14); c=pade_defaults(24);
        assert(a.N==30&&a.maxFE==30030&&b.N==30&&b.maxFE==15030);
        assert(c.N==40&&c.maxFE==100040);
        assert(parent.geometry==0&&~parent.pulse&&~parent.jitter&&~parent.classic);
        detail=struct('problems',26,'continuous_variants',7,'mixed_variants',13,...
            'defaults_checked',[a.maxFE,b.maxFE,c.maxFE]);
    end

    function detail=quietContinuous()
        prob=toyProblem('QUIET_CONT',3,[-2 -2 -2],[2 2 2],[],[],@coupledObjective);
        opts=base; a=run(prob,parent,opts,37); opts.force_quiet=true;
        b=run(prob,full,opts,37); fields=assertIdentity(a,b);
        detail=struct('seed',37,'FE',a.FE,'exact_equal_fields',fields,...
            'proposals_compared',height(a.proposals));
    end

    function detail=quietDiscrete()
        prob=gridProblem(); opts=base;
        a=run(prob,parent,opts,53); opts.force_quiet=true;
        b=run(prob,fullDiscrete,opts,53); fields=assertIdentity(a,b);
        assert(b.events.rot_trials==0&&b.events.pulse_trials==0&&b.events.jitter_trials==0);
        detail=struct('seed',53,'FE',a.FE,'exact_equal_fields',fields,...
            'lower_bound',prob.lb,'grid_step',prob.discrete_step);
    end

    function detail=noiseCheck()
        prob=problems(7); opts=base;
        state=RandStream.getGlobalStream; before=state.State;
        a=run(prob,parent,opts,71); after=state.State;
        assert(isequal(before,after),'pade:GlobalRNG','Solver changed caller global RNG state.');
        b=run(prob,full,opts,71); c=run(prob,classic,opts,71);
        assert(isequal(a.initial_pop,b.initial_pop)&&isequal(a.initial_pop,c.initial_pop));
        assert(isequal(a.initial_f,b.initial_f)&&isequal(a.initial_f,c.initial_f));
        noise=RandStream('mt19937ar','Seed',71+6000000);
        expected=zeros(opts.N,1);
        for j=1:opts.N
            expected(j)=sum((1:prob.D).*(a.initial_pop(j,:).^4))+rand(noise);
        end
        assert(isequal(a.initial_f,expected),'pade:NoiseRNG','F07 FE-indexed noise mismatch.');
        detail=struct('seed',71,'initial_evaluations_compared',opts.N,...
            'caller_global_state_preserved',true,'FE_index_noise_exact',true);
    end

    function detail=partialGeneration()
        prob=toyProblem('EXACT_FE',3,[-2 -2 -2],[2 2 2],[],[],@coupledObjective);
        r=run(prob,parent,base,83);
        assert(r.FE==121&&r.events.init_FE==8&&r.events.trial_FE==113&&r.events.pulse_FE==0);
        assert(r.complete_generations==14&&height(r.generation_log)==15);
        assert(r.generation_log(end,7)==1&&height(r.proposals)==121);
        assert(isequal(r.proposals(:,1),(1:121)'));
        assert(string(r.status)=="complete");
        detail=struct('FE',r.FE,'init_FE',8,'trial_FE',113,...
            'complete_generations',14,'last_generation_trials',1);
    end

    function detail=pulseBudget()
        prob=toyProblem('PULSE_BRANCH',2,[0 0],[1 1e-10],[],[],@constantObjective);
        opts=base; opts.warmupRatio=0; opts.stagnationLimit=1;
        opts.betaCrit=-1e6; % DIAGNOSTIC ONLY: make the entropy gate pass.
        r=run(prob,full,opts,97);
        assert(r.events.pulse_trials>0&&r.events.pulse_FE==r.events.pulse_trials);
        assert(r.events.init_FE+r.events.trial_FE+r.events.pulse_FE==121&&r.FE==121);
        assert(r.events.trial_FE<113&&height(r.proposals)==121);
        pulseRows=r.proposals(r.proposals(:,2)==2,:);
        assert(height(pulseRows)==r.events.pulse_FE);
        assert(all(pulseRows(:,1)<=ceil(opts.pulseEndRatio*opts.maxFE)));
        detail=struct('FE',r.FE,'init_FE',r.events.init_FE,'trial_FE',r.events.trial_FE,...
            'pulse_FE',r.events.pulse_FE,'pulse_triggers',r.events.pulse_triggers,...
            'diagnostic_gate_override',true);
    end

    function detail=gridBounds()
        prob=gridProblem(); opts=base; opts.stagnationLimit=1; opts.warmupRatio=0;
        r=run(prob,fullDiscrete,opts,109); x=r.proposals(:,3:end);
        assert(all(all(x>=prob.lb-1e-12&x<=prob.ub+1e-12)));
        for dimIndex=1:numel(prob.discrete_idx)
            dim=prob.discrete_idx(dimIndex); step=prob.discrete_step(dimIndex);
            scaled=x(:,dim)/step;
            assert(all(abs(scaled-round(scaled))<1e-12),'pade:Grid','Non-grid proposal.');
        end
        assert(r.events.jitter_trials>0,'pade:JitterNotExercised','Diagnostic seed did not exercise jitter.');
        assert(all(all(r.initial_pop>=prob.lb&r.initial_pop<=prob.ub)));
        detail=struct('proposals_checked',height(x),'bounds', [prob.lb;prob.ub],...
            'discrete_idx',prob.discrete_idx,'steps',prob.discrete_step,...
            'jitter_trials',r.events.jitter_trials,'jitter_effective',r.events.jitter_effective);
    end

    function detail=debTrace()
        prob=toyProblem('DEB_TRACE',2,[-2 -2],[2 2],[],[],@constrainedObjective);
        r=run(prob,full,base,127);
        assertDebMonotone(r.trace_f,r.trace_cv,false);
        assertDebMonotone(r.improvement_log(:,2),r.improvement_log(:,3),true);
        assert(all(diff(r.trace_fe)>0)&&r.trace_fe(end)==r.FE);
        assert(r.trace_f(end)==r.best_f&&r.trace_cv(end)==r.best_cv);
        detail=struct('trace_points',numel(r.trace_fe),...
            'strict_improvements',height(r.improvement_log),'terminal_cv',r.best_cv);
    end

    function detail=diagnosticStop()
        prob=toyProblem('EARLY_STOP',3,[-2 -2 -2],[2 2 2],[],[],@coupledObjective);
        opts=base; opts.stop_after_generations=2; r=run(prob,parent,opts,131);
        assert(r.FE==24&&r.FE<r.budget_FE&&r.complete_generations==2);
        assert(string(r.status)=="diagnostic_stop",'pade:StopStatus',...
            'An early stopped diagnostic must not be labelled complete.');
        assert(r.trace_fe(end)==r.FE&&r.trace_f(end)==r.best_f&&r.trace_cv(end)==r.best_cv);
        detail=struct('FE',r.FE,'budget_FE',r.budget_FE,'status',r.status);
    end

    function detail=midpoints()
        values=repmat(struct('problem_id',"",'D',0,'f',0,'cv',0),26,1);
        for index=1:26
            p=problems(index); x=(p.lb+p.ub)/2;
            for j=1:numel(p.discrete_idx)
                dim=p.discrete_idx(j); step=p.discrete_step(j);
                x(dim)=min(max(round(x(dim)/step)*step,p.lb(dim)),p.ub(dim));
            end
            RandStream.setGlobalStream(RandStream('mt19937ar','Seed',1700+index));
            [f,c]=p.eval(x);
            RandStream.setGlobalStream(RandStream('mt19937ar','Seed',1700+index));
            [fc,cc]=p.eval(x');
            assert(isscalar(f)&&isscalar(c)&&isfinite(f)&&isfinite(c)&&c>=0);
            assert(isequal(f,fc)&&isequal(c,cc),'pade:VectorOrientation','Row/column evaluation mismatch.');
            values(index)=struct('problem_id',string(p.id),'D',p.D,'f',f,'cv',c);
        end
        detail=struct('points_checked',26,'row_column_equal',true,'values',values);
    end

    function detail=engineeringVectors()
        vectors={ [0.205730 3.470489 9.036624 0.205730],...
            [6.016016 5.309174 4.494330 3.501475 2.152665],...
            [0.8125 0.4375 42.0984455958549 176.6365958424394] };
        % Fixed arithmetic references independently calculated in Python.
        referenceF=[1.7248556738155942,1.339956384,6059.714335048431];
        referenceCV=[0,0,1.862645149230957e-9];
        values=repmat(struct('problem_id',"",'x',[],'f',0,'cv',0,...
            'expected_f',0,'expected_cv',0,'strictly_feasible',false),3,1);
        for j=1:3
            p=problems(23+j); [f,c]=p.eval(vectors{j});
            assert(abs(f-referenceF(j))<=1e-11*max(1,abs(referenceF(j))));
            assert(abs(c-referenceCV(j))<=1e-7,...
                'pade:KnownVectorCV','Fixed vector CV differs from independent arithmetic.');
            values(j)=struct('problem_id',string(p.id),'x',vectors{j},'f',f,'cv',c,...
                'expected_f',referenceF(j),'expected_cv',referenceCV(j),'strictly_feasible',c==0);
        end
        % Analytic CB stationarity solution, moved 1e-12 into feasibility.
        coefficients=[61 37 19 7 1]; root=coefficients.^0.25;
        x=root*sum(root)^(1/3)*(1+1e-12); [f,c]=problems(25).eval(x);
        assert(c==0&&abs(f-1.339956360599)<1e-10);
        detail=struct('rounded_display_vectors',values,...
            'CB_analytic_interior_x',x,'CB_analytic_f',f,'CB_analytic_cv',c,...
            'note','Rounded coordinates can change objective and strict feasibility; this is arithmetic verification.');
    end

    function r=run(prob,variant,opts,seed)
        r=pade_solve_fe(prob,variant,opts,seed);
        diagnosticRuns{end+1,1}=struct('diagnostic_only',true,'result',r);
    end
end

function variant=selectVariant(variants,id)
selected=strcmp({variants.id},id); assert(sum(selected)==1); variant=variants(selected);
end

function fields=assertIdentity(a,b)
fields=["FE","best_f","best_cv","best_x","initial_pop","initial_f",...
    "initial_cv","final_pop","final_f","final_cv","trace_fe","trace_f",...
    "trace_cv","improvement_log","proposals","mu_F","mu_CR","P_rot",...
    "complete_generations","events"];
for name=fields
    assert(isequaln(a.(name),b.(name)),'pade:QuietIdentity',...
        'Force-quiet full variant differs from shared parent in %s.',name);
end
% H and rho differ because one branch computes unused geometry; FE, gates,
% adaptation, incumbent and the actual proposals must nevertheless agree.
assert(isequaln(a.generation_log(:,[1 2 5:12]),b.generation_log(:,[1 2 5:12])));
end

function assertDebMonotone(f,cv,strict)
for k=2:numel(f)
    oldF=f(k-1); oldCV=cv(k-1); newF=f(k); newCV=cv(k);
    if oldCV==0&&newCV==0
        if strict, valid=newF<oldF; else, valid=newF<=oldF; end
    elseif newCV==0
        valid=true;
    elseif oldCV==0
        valid=false;
    elseif strict
        valid=newCV<oldCV;
    else
        valid=newCV<=oldCV;
    end
    assert(valid,'pade:DebMonotonicity','Incumbent worsened under feasibility priority.');
end
end

function prob=toyProblem(id,D,lb,ub,discreteIdx,steps,objective)
prob=struct('id',id,'name','IMPLEMENTATION DIAGNOSTIC ONLY','D',D,...
    'lb',lb,'ub',ub,'discrete_idx',discreteIdx,'discrete_step',steps,'eval',objective);
end

function prob=gridProblem()
prob=toyProblem('GRID_BELOW_ONE',4,[0.0625 0.0625 -2 -2],...
    [0.3125 0.5 2 2],[1 2],[0.0625 0.0625],@constantObjective);
end

function [f,cv]=coupledObjective(x)
f=(x(1)+0.4*x(2))^2+2*(x(2)-0.3*x(3))^2+0.5*x(3)^2; cv=0;
end

function [f,cv]=constantObjective(~)
f=1; cv=0;
end

function [f,cv]=constrainedObjective(x)
f=sum(x.^2); cv=max(0,0.25-x(1));
end
