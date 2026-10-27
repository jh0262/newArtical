function result = pade_solve_fe(prob, variant, opts, seed)
%PADE_SOLVE_FE PADE-FE v4 and its shared-parent ablations, exact FE stopping.
% Geometry: 0 original coordinates, 1 eigenvector crossover, 2 + spectral scale.
% All objective calls, including initialization and pulse proposals, cost 1 FE.
arguments
    prob (1,1) struct
    variant (1,1) struct
    opts (1,1) struct
    seed (1,1) double
end
tRun = tic;
N = opts.N; D = prob.D; budget = opts.maxFE;
assert(N >= 4 && budget >= N && budget == floor(budget));
lb = reshape(prob.lb,1,[]); ub = reshape(prob.ub,1,[]);
initStream = RandStream('mt19937ar','Seed',seed);
baseStream = RandStream('mt19937ar','Seed',seed+1000000);
rotStream = RandStream('mt19937ar','Seed',seed+2000000);
pulseStream = RandStream('mt19937ar','Seed',seed+3000000);
jitterStream = RandStream('mt19937ar','Seed',seed+4000000);
archiveStream = RandStream('mt19937ar','Seed',seed+5000000);
noiseStream = RandStream('mt19937ar','Seed',seed+6000000);
previousStream = RandStream.getGlobalStream;
restoreStream = onCleanup(@() RandStream.setGlobalStream(previousStream)); %#ok<NASGU>
RandStream.setGlobalStream(noiseStream);
quiet = isfield(opts,'force_quiet') && opts.force_quiet;
capture = isfield(opts,'capture_proposals') && opts.capture_proposals;
stopGen = Inf;
if isfield(opts,'stop_after_generations'), stopGen=opts.stop_after_generations; end
pop = lb + rand(initStream,N,D).*(ub-lb);
pop = gridProject(pop);
initialPop = pop;
fitness = zeros(N,1); cv = fitness;
FE=0; bestF=Inf; bestCV=Inf; bestX=nan(1,D);
checkpoints=unique(round(linspace(N,budget,min(501,budget-N+1))))';
traceF=nan(numel(checkpoints),1); traceCV=traceF; traceIndex=1;
improvements=zeros(min(4096,budget),3); nImprove=0;
proposals=zeros(0,D+2);
events=struct('init_FE',0,'trial_FE',0,'pulse_FE',0,'rot_trials',0,...
    'rot_success',0,'pulse_triggers',0,'pulse_trials',0,'pulse_success',0,...
    'pulse_best',0,'jitter_trials',0,'jitter_effective',0,...
    'jitter_candidates',0,'jitter_success',0,'invalid_evals',0);
for i=1:N
    [fitness(i),cv(i)]=evaluate(pop(i,:),0);
end
initialF=fitness; initialCV=cv;
needGeometry = variant.geometry>0 || variant.pulse;
if needGeometry
    c0=cov(pop)+1e-12*eye(D);
    H0=0.5*sum(log(max(svd(c0),1e-25)))+0.5*D*log(2*pi*exp(1));
else
    H0=NaN;
end
Hcrit=H0-opts.betaCrit*D;
archive=zeros(N,D); archiveCount=0;
muF=0.5; muCR=0.5; pRot=0.20;
W=0; prevF=bestF; prevCV=bestCV;
generation=0; completeGenerations=0;
generationLog=zeros(ceil((budget-N)/N)+1,12); nLog=0;
while FE<budget && generation<stopGen
    generation=generation+1;
    if better(bestF,bestCV,prevF,prevCV)
        W=0; prevF=bestF; prevCV=bestCV;
    else
        W=W+1;
    end
    % Exact feasibility priority, objective within feasible group, CV otherwise.
    infeasible=cv>0; secondary=fitness; secondary(infeasible)=cv(infeasible);
    [~,order]=sortrows([double(infeasible),secondary,(1:N)'],[1 2 3]);
    rho=NaN; H=NaN; V=[]; eigvals=[]; scales=[];
    if needGeometry
        mu=max(4,floor(N*0.5));
        elite=pop(order(1:mu),:);
        weights=log(mu+0.5)-log((1:mu)'); weights=weights/sum(weights);
        centered=elite-weights'*elite;
        sample=centered'*(centered.*weights);
        alpha=D/(N+D);
        C=(1-alpha)*sample+alpha*diag(diag(sample))+1e-12*eye(D);
        [V,L]=eig(C); [eigvals,indices]=sort(diag(L),'descend'); V=V(:,indices);
        maxEig=max(eigvals(1),1e-12);
        rho=norm(C-diag(diag(C)),'fro')/(norm(C,'fro')+1e-14);
        H=0.5*sum(log(max(eigvals,1e-25)))+0.5*D*log(2*pi*exp(1));
        scales=(sqrt(max(eigvals,0))/sqrt(maxEig)).^opts.gamma;
    end
    beforeTrial=events.trial_FE; beforePulse=events.pulse_FE;
    beforeRot=events.rot_trials; beforeJitter=events.jitter_trials;
    % Gates use actual consumed FE, not a nominal generation clock.
    canPulse=variant.pulse && ~quiet && FE/budget>opts.warmupRatio ...
        && FE/budget<opts.pulseEndRatio && H<=Hcrit && W>=opts.stagnationLimit;
    if canPulse
        mask=eigvals<1e-4*maxEig;
        if any(mask)
            events.pulse_triggers=events.pulse_triggers+1;
            targets=order(end-max(1,round(0.2*N))+1:end);
            vn=V(:,mask);
            for k=1:numel(targets)
                if FE>=budget || FE/budget>=opts.pulseEndRatio, break; end
                i=targets(k);
                candidate=bestX+(vn*(0.15*sqrt(maxEig)*randn(pulseStream,sum(mask),1)))';
                % Pulse-grid jump belongs to P; J controls trial jitter only.
                for j=1:numel(prob.discrete_idx)
                    dim=prob.discrete_idx(j); step=prob.discrete_step(j);
                    direction=2*(rand(pulseStream)>0.5)-1;
                    candidate(dim)=candidate(dim)+direction*step;
                end
                candidate=gridProject(min(max(candidate,lb),ub));
                oldBestF=bestF; oldBestCV=bestCV;
                [fNew,cvNew]=evaluate(candidate,2);
                events.pulse_trials=events.pulse_trials+1;
                if better(fNew,cvNew,fitness(i),cv(i))
                    pop(i,:)=candidate; fitness(i)=fNew; cv(i)=cvNew;
                    events.pulse_success=events.pulse_success+1;
                end
                if better(bestF,bestCV,oldBestF,oldBestCV)
                    events.pulse_best=events.pulse_best+1;
                end
            end
            W=max(0,W-5);
        end
    end
    newPop=pop; newFitness=fitness; newCV=cv;
    successF=zeros(N,1); successCR=successF; nSuccess=0;
    nRot=0; rotSuccess=0; processed=0;
    for i=1:N
        if FE>=budget, break; end
        processed=i;
        if variant.classic
            F=0.5; CR=0.9;
            r1=randi(baseStream,N); while r1==i, r1=randi(baseStream,N); end
            r2=randi(baseStream,N); while r2==i || r2==r1, r2=randi(baseStream,N); end
            r3=randi(baseStream,N); while r3==i || r3==r1 || r3==r2, r3=randi(baseStream,N); end
            mutant=pop(r1,:)+F*(pop(r2,:)-pop(r3,:));
            useRot=false;
        else
            F=muF+0.1*tan(pi*(rand(baseStream)-0.5));
            while F<=0, F=muF+0.1*tan(pi*(rand(baseStream)-0.5)); end
            F=min(F,1); CR=min(max(muCR+0.1*randn(baseStream),0),1);
            pCount=max(2,round(opts.pBestRate*N));
            pbest=pop(order(randi(baseStream,pCount)),:);
            r1=randi(baseStream,N); while r1==i, r1=randi(baseStream,N); end
            r2=randi(baseStream,N+archiveCount);
            while r2==i || r2==r1, r2=randi(baseStream,N+archiveCount); end
            if r2<=N, xr2=pop(r2,:); else, xr2=archive(r2-N,:); end
            difference=pbest-pop(i,:)+pop(r1,:)-xr2;
            useRot=variant.geometry>0 && ~quiet && FE/budget>opts.warmupRatio ...
                && rho>0.20 && rand(rotStream)<pRot;
            mutant=pop(i,:)+F*difference;
        end
        mask=rand(baseStream,1,D)<=CR;
        mask(randi(baseStream,D))=true;
        if useRot
            z=pop(i,:)*V;
            if variant.geometry==2, ds=scales'; else, ds=ones(1,D); end
            mutantZ=z+F*(difference*V).*ds;
            trialZ=z; trialZ(mask)=mutantZ(mask); trial=trialZ*V';
            nRot=nRot+1; events.rot_trials=events.rot_trials+1;
        else
            trial=pop(i,:); trial(mask)=mutant(mask);
        end
        low=trial<lb; high=trial>ub;
        trial(low)=(lb(low)+pop(i,low))/2;
        trial(high)=(ub(high)+pop(i,high))/2;
        trial=gridProject(trial);
        jittered=false;
        pJitter=0.25*min(1,W/max(1,opts.stagnationLimit));
        if variant.jitter && ~quiet && pJitter>0.02
            for j=1:numel(prob.discrete_idx)
                dim=prob.discrete_idx(j);
                if rand(jitterStream)<pJitter
                    events.jitter_trials=events.jitter_trials+1;
                    old=trial(dim); direction=2*(rand(jitterStream)>0.5)-1;
                    trial(dim)=min(max(old+direction*prob.discrete_step(j),lb(dim)),ub(dim));
                    events.jitter_effective=events.jitter_effective+(trial(dim)~=old);
                    jittered=true;
                end
            end
        end
        trial=gridProject(trial);
        events.jitter_candidates=events.jitter_candidates+jittered;
        [fNew,cvNew]=evaluate(trial,1);
        if better(fNew,cvNew,fitness(i),cv(i))
            newPop(i,:)=trial; newFitness(i)=fNew; newCV(i)=cvNew;
            nSuccess=nSuccess+1; successF(nSuccess)=F; successCR(nSuccess)=CR;
            if useRot, rotSuccess=rotSuccess+1; events.rot_success=events.rot_success+1; end
            if jittered, events.jitter_success=events.jitter_success+1; end
            if ~variant.classic
                if archiveCount<N
                    archiveCount=archiveCount+1; archive(archiveCount,:)=pop(i,:);
                else
                    archive(randi(archiveStream,N),:)=pop(i,:);
                end
            end
        end
    end
    pop=newPop; fitness=newFitness; cv=newCV;
    if ~variant.classic && nSuccess>0
        sf=successF(1:nSuccess); scr=successCR(1:nSuccess);
        muF=0.9*muF+0.1*sum(sf.^2)/sum(sf); muCR=0.9*muCR+0.1*mean(scr);
    end
    if nRot>0, pRot=min(max(0.9*pRot+0.1*rotSuccess/nRot,0.05),0.85); end
    completeGenerations=completeGenerations+(processed==N);
    nLog=nLog+1;
    generationLog(nLog,:)=[generation,FE,H,rho,W,pRot,events.trial_FE-beforeTrial,...
        events.pulse_FE-beforePulse,events.rot_trials-beforeRot,...
        events.jitter_trials-beforeJitter,bestF,bestCV];
end
valid=~isnan(traceF);
traceFE=checkpoints(valid); traceF=traceF(valid); traceCV=traceCV(valid);
if isempty(traceFE) || traceFE(end)~=FE
    traceFE(end+1,1)=FE; traceF(end+1,1)=bestF; traceCV(end+1,1)=bestCV;
end
assert(events.init_FE+events.trial_FE+events.pulse_FE==FE);
if isinf(stopGen), assert(FE==budget); end
status='complete'; if FE<budget, status='diagnostic_stop'; end
result=struct('problem_id',prob.id,'variant_id',variant.id,'seed',seed,...
    'FE',FE,'budget_FE',budget,'best_f',bestF,'best_cv',bestCV,'best_x',bestX,...
    'trace_fe',traceFE,'trace_f',traceF,'trace_cv',traceCV,...
    'improvement_log',improvements(1:nImprove,:),'events',events,...
    'generation_log',generationLog(1:nLog,:),'complete_generations',completeGenerations,...
    'initial_pop',initialPop,'initial_f',initialF,'initial_cv',initialCV,...
    'final_pop',pop,'final_f',fitness,'final_cv',cv,...
    'mu_F',muF,'mu_CR',muCR,'P_rot',pRot,'H0',H0,...
    'status',status,'pulseFE',events.pulse_FE,'run_seconds',toc(tRun),'rng_scheme','mt19937ar-separated-7-streams',...
    'algorithm_version','PADE-FE-v4.0','options',opts,'variant',variant);
if capture, result.proposals=proposals; end
for name={'config_hash','code_hash','problem_hash'}
    if isfield(opts,name{1}), result.(name{1})=opts.(name{1}); end
end

    function x=gridProject(x)
        for kk=1:numel(prob.discrete_idx)
            dim=prob.discrete_idx(kk); step=prob.discrete_step(kk);
            x(:,dim)=min(max(round(x(:,dim)/step)*step,lb(dim)),ub(dim));
        end
    end
    function [f,c]=evaluate(x,kind)
        assert(FE<budget,'pade:BudgetExceeded','Objective call after budget exhausted.');
        assert(all(x>=lb-1e-12 & x<=ub+1e-12),'pade:Bounds','Candidate outside bounds.');
        [f,c]=prob.eval(x);
        assert(isscalar(f)&&isscalar(c)&&isreal(f)&&isreal(c),'pade:EvaluationShape','Invalid output shape.');
        FE=FE+1;
        if ~isfinite(f) || ~isfinite(c) || c<0
            events.invalid_evals=events.invalid_evals+1; f=Inf; c=Inf;
        end
        if kind==0, events.init_FE=events.init_FE+1;
        elseif kind==1, events.trial_FE=events.trial_FE+1;
        else, events.pulse_FE=events.pulse_FE+1; end
        if better(f,c,bestF,bestCV)
            bestF=f; bestCV=c; bestX=x;
            nImprove=nImprove+1;
            improvements(nImprove,:)=[FE,f,c];
        end
        if traceIndex<=numel(checkpoints) && FE==checkpoints(traceIndex)
            traceF(traceIndex)=bestF; traceCV(traceIndex)=bestCV; traceIndex=traceIndex+1;
        end
        if capture, proposals(end+1,:)=[FE,kind,x]; end %#ok<AGROW>
    end
end

function tf=better(f1,c1,f2,c2)
if c1==0 && c2==0, tf=f1<f2;
elseif c1==0, tf=true;
elseif c2==0, tf=false;
else, tf=c1<c2;
end
end
