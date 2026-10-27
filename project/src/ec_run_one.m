function result=ec_run_one(cfg,problemIndex,algorithmIndex,seed,outdir)
% One immutable run attempt. Callback measurement never changes RNG state.
assert(~isfolder(outdir),'EC:ExistingAttempt','Refuse to overwrite %s',outdir);
mkdir(outdir); diary(fullfile(outdir,'stdout.log')); diary on;
closeDiary=onCleanup(@()diary('off'));
root=fileparts(fileparts(mfilename('fullpath')));
meta=struct('status','running','started_at',utcnow(),'problem',cfg.problems(problemIndex).name,'D',cfg.problems(problemIndex).D,'algorithm',cfg.algorithms(algorithmIndex).name,'seed',seed,'initialSeed',100000+problemIndex*1000+seed,'N',cfg.N,'requestedGenerations',cfg.generations,'requestedFE',cfg.N*(cfg.generations+1),'matlab',version,'computer',computer,'mode',cfg.mode,'failure_tree_refs',{{'H-A','H-B','H-C','H-ABC'}},'evaluation_scope','analytic_biobjective_unconstrained_only');
fprintf('START %s %s seed=%d N=%d generations=%d\n',meta.problem,meta.algorithm,seed,cfg.N,cfg.generations);
ec_jsonwrite(fullfile(outdir,'config.json'),cfg);
ec_jsonwrite(fullfile(outdir,'manifest.json'),meta);
codeManifest=fullfile(root,'provenance','code_manifest.json');
if isfile(codeManifest), copyfile(codeManifest,fullfile(outdir,'code_manifest.json')); end
wall=tic;
try
    P=ECProblem('N',cfg.N,'maxFE',meta.requestedFE,'parameter',{meta.problem,meta.D,meta.initialSeed});
    initialX=P.InitialX;
    referenceF=P.GetOptimum(cfg.referenceSamples);
    referenceF=referenceF(ec_nd_indices(referenceF),:);
    referenceLo=min(referenceF,[],1); referenceSpan=max(max(referenceF,[],1)-referenceLo,eps);
    referenceNormalized=(referenceF-referenceLo)./referenceSpan;
    Fronts=nan(cfg.N,2,cfg.generations+1);
    HV=nan(cfg.generations+1,1); IGDplus=HV; OutsideReference=HV;
    seen=false(cfg.generations+1,1);
    settings=cfg.algorithms(algorithmIndex);
    if strcmp(settings.class,'GECMODE')
        A=GECMODE('parameter',{settings},'save',1,'outputFcn',@observe);
    elseif strcmp(settings.class,'MOEAD')
        A=MOEAD('parameter',{2},'save',1,'outputFcn',@observe);
    else
        A=feval(settings.class,'save',1,'outputFcn',@observe);
    end
    rng(seed,'twister'); initialRng=rng;
    A.Solve(P);
    finalRng=rng;
    assert(P.FE==meta.requestedFE && all(seen),'EC:Incomplete','Budget or generation evidence incomplete.');
    finalPop=A.result{end,2}; finalX=finalPop.decs; finalF=finalPop.objs;
    reevaluated=P.CalObj(finalX); % Verification only; excluded from optimization FE.
    assert(max(abs(reevaluated-finalF),[],'all')<1e-10,'EC:Reevaluation','Final objective recomputation failed.');
    Telemetry=[];
    if isa(A,'GECMODE'), Telemetry=A.Telemetry; assert(size(Telemetry,1)==cfg.generations); end
    meta.status='completed'; meta.termination='registered_budget_reached';
    meta.generations=sum(seen)-1; meta.FE=P.FE; meta.ended_at=utcnow();
    meta.algorithmSeconds=A.metric.runtime; meta.wallSeconds=toc(wall);
    meta.finalHV=HV(end); meta.finalIGDplus=IGDplus(end);
    meta.finalOutsideReference=OutsideReference(end);
    meta.finalUniqueObjectives=size(unique(finalF,'rows'),1);
    meta.reevaluation_calls=size(finalX,1);
    result=struct('meta',meta,'initialX',initialX,'finalX',finalX,'finalF',finalF,'Fronts',Fronts,'HV',HV,'IGDplus',IGDplus,'OutsideReference',OutsideReference,'Telemetry',Telemetry,'referenceF',referenceF,'referenceLo',referenceLo,'referenceSpan',referenceSpan,'initialRng',initialRng,'finalRng',finalRng);
    save(fullfile(outdir,'raw.mat'),'-struct','result','-v7');
    curve=table((0:cfg.generations)',(1:cfg.generations+1)'*cfg.N,HV,IGDplus,OutsideReference,'VariableNames',{'Generation','FE','HV','IGDplus','OutsideReference'});
    writetable(curve,fullfile(outdir,'metrics.csv'));
    writematrix(finalX,fullfile(outdir,'final_decisions.csv'));
    writematrix(finalF,fullfile(outdir,'final_objectives.csv'));
    if ~isempty(Telemetry)
        T=array2table(Telemetry,'VariableNames',{'meanF','meanCR','pLocal','localFraction','meanCredit','positiveCredits','earApplied','earFallback','coverRadius','coverBound','guideCount','memoryMeanF','memoryMeanCR'});
        writetable(T,fullfile(outdir,'adaptation.csv'));
    end
    ec_jsonwrite(fullfile(outdir,'guardrails.json'),struct('finiteObjectives',true,'exactPopulation',true,'exactEvaluationBudget',true,'allGenerationsObserved',true,'finalObjectivesRecomputed',true,'noTruePFInVariation',true,'scope','Code audit plus runtime checks; no cross-platform or physical-validation claim.'));
    ec_jsonwrite(fullfile(outdir,'manifest.json'),meta);
    f=fopen(fullfile(outdir,'stderr.log'),'w'); fclose(f);
    fprintf('COMPLETE %s %s seed=%d FE=%d gen=%d wall=%.3f\n',meta.problem,meta.algorithm,seed,P.FE,meta.generations,meta.wallSeconds);
catch err
    meta.status='failed'; meta.ended_at=utcnow(); meta.wallSeconds=toc(wall);
    meta.failureIdentifier=err.identifier; meta.failureMessage=err.message;
    ec_jsonwrite(fullfile(outdir,'manifest.json'),meta);
    f=fopen(fullfile(outdir,'stderr.log'),'w','n','UTF-8'); fprintf(f,'%s',getReport(err,'extended','hyperlinks','off')); fclose(f);
    rethrow(err);
end
    function observe(algorithm,problem)
        generation=problem.FE/cfg.N-1;
        assert(generation==floor(generation) && generation>=0 && generation<=cfg.generations,'EC:Generation','Unexpected evaluation schedule.');
        Pop=algorithm.result{end,2}; F=Pop.objs;
        assert(isequal(size(F),[cfg.N 2]) && all(isfinite(F),'all'),'EC:Population','Invalid population.');
        ix=generation+1; assert(~seen(ix),'EC:Generation','Duplicate generation observation.');
        Fronts(:,:,ix)=F; seen(ix)=true;
        Z=(F-referenceLo)./referenceSpan;
        HV(ix)=ec_hv2(Z,[1.1 1.1]); OutsideReference(ix)=mean(any(Z>=[1.1 1.1],2));
        if mod(generation,cfg.metricInterval)==0 || generation==cfg.generations
            IGDplus(ix)=ec_igdplus(Z,referenceNormalized);
        end
    end
end

function s=utcnow()
s=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end
