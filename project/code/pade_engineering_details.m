function report = pade_engineering_details(rawDir, outDir, opts)
%PADE_ENGINEERING_DETAILS Recheck saved engineering designs, without search.
% REPORT = PADE_ENGINEERING_DETAILS(RAWDIR, OUTDIR) reads completed WB/CB/PV
% results, selects the best run in each variant by strict Deb ordering, and
% independently recomputes objectives and every supplied residual. No solver
% is called and no candidate is generated. The frozen problem library is
% used only for a second deterministic cross-check of saved designs.
%
% Outputs (UTF-8; CSV numbers use %.17g):
%   engineering_best.csv/json: one strict-Deb best design per variant.
%   engineering_runs.csv: all saved engineering terminal designs.
%   engineering_residuals.csv: one individual inequality per saved design.
%   engineering_summary.csv: feasible-only cost statistics and coverage.
% The JSON also includes explicit decimal round-trip strings for x/f/CV/g.
% FULL, PARENT and CLASSIC rows are identified by the role column.
%
% This is postprocessing: these deterministic re-evaluations do not alter
% any saved search FE, optimizer state, result, configuration or source file.
arguments
    rawDir (1,1) string
    outDir (1,1) string
    opts.ExpectedSeeds (1,:) double {mustBeInteger,mustBePositive} = 1001:1030
    opts.ComparisonRelativeTolerance (1,1) double {mustBeNonnegative} = 1e-12
end
assert(isfolder(rawDir),'PADE:EngineeringRaw','Raw directory does not exist.');
assert(rawDir~=outDir,'PADE:EngineeringOutput','Keep output separate from raw files.');
assert(numel(unique(opts.ExpectedSeeds))==numel(opts.ExpectedSeeds),...
    'PADE:EngineeringSeeds','Expected seeds must be unique.');
problems=pade_problems();
problemIds=["WB","CB","PV"];
entries=repmat(emptyEntry(),0,1);
bestEntries=repmat(emptyEntry(),0,1);
summaries=repmat(emptySummary(),0,1);

for problemId=problemIds
    prob=problems(strcmp({problems.id},problemId));
    assert(isscalar(prob),'PADE:EngineeringProblem','Problem definition is not unique.');
    expectedVariants=pade_variants(~isempty(prob.discrete_idx));
    variantIds=string({expectedVariants.id});
    files=dir(fullfile(rawDir,problemId,'*.mat'));
    assert(~isempty(files),'PADE:EngineeringMissing','No saved runs for %s.',problemId);
    firstEntry=numel(entries)+1;
    for fileIndex=1:numel(files)
        source=string(fullfile(files(fileIndex).folder,files(fileIndex).name));
        data=load(source,'result');
        assert(isfield(data,'result')&&isscalar(data.result),...
            'PADE:EngineeringSchema','Saved file has no scalar result: %s',source);
        r=data.result;
        required={'problem_id','variant_id','seed','status','FE','budget_FE',...
            'best_x','best_f','best_cv'};
        assert(all(isfield(r,required)),'PADE:EngineeringSchema',...
            'Required fields missing: %s',source);
        assert(string(r.problem_id)==problemId&&any(string(r.variant_id)==variantIds),...
            'PADE:EngineeringIdentity','Unexpected problem or variant: %s',source);
        assert(string(r.status)=="complete"&&r.FE==100040&&r.budget_FE==100040,...
            'PADE:EngineeringBudget','Expected a completed 100040-FE run: %s',source);
        validateattributes(r.best_x,{'numeric'},{'real','finite','vector','numel',prob.D});
        validateattributes(r.best_f,{'numeric'},{'real','finite','scalar'});
        validateattributes(r.best_cv,{'numeric'},{'real','finite','scalar','nonnegative'});
        x=reshape(double(r.best_x),1,[]);
        [f,cv,g,meta,physical]=independentModel(problemId,x);
        [libraryF,libraryCV]=prob.eval(x);
        closeScalar(f,r.best_f,opts.ComparisonRelativeTolerance,'saved objective',source);
        closeScalar(cv,r.best_cv,opts.ComparisonRelativeTolerance,'saved CV',source);
        closeScalar(f,libraryF,opts.ComparisonRelativeTolerance,'library objective',source);
        closeScalar(cv,libraryCV,opts.ComparisonRelativeTolerance,'library CV',source);
        % No feasibility tolerance: arithmetic comparison tolerance above is
        % only for re-evaluation consistency, never for deciding feasibility.
        assert((cv==0)==(r.best_cv==0)&&(cv==0)==all(g<=0),...
            'PADE:EngineeringFeasibility','Strict feasibility classification differs: %s',source);
        assert((cv==0)==(libraryCV==0),...
            'PADE:EngineeringFeasibility','Library strict feasibility differs: %s',source);
        boundsOK=all(x>=prob.lb & x<=prob.ub);
        gridMultiples=x(prob.discrete_idx)./prob.discrete_step;
        gridOK=all(gridMultiples==round(gridMultiples));
        assert(boundsOK&&gridOK,'PADE:EngineeringDesign','Box or grid violation: %s',source);
        e=emptyEntry();
        e.problem_id=problemId; e.problem_name=string(prob.name);
        e.variant_id=string(r.variant_id); e.role=roleFor(problemId,e.variant_id);
        e.seed=double(r.seed); e.FE=double(r.FE); e.source_file=source;
        e.best_f=double(r.best_f); e.best_cv=double(r.best_cv);
        e.f_recomputed=f; e.cv_recomputed=cv; e.strict_feasible=(cv==0);
        e.x=x; e.x_names=meta.x_names; e.x_units=meta.x_units;
        e.objective_unit=meta.objective_unit;
        e.g=g; e.g_names=meta.g_names; e.g_units=meta.g_units;
        e.g_definitions=meta.g_definitions; e.g_satisfied=(g<=0);
        e.lower_bound=prob.lb; e.upper_bound=prob.ub;
        e.lower_margin=x-prob.lb; e.upper_margin=prob.ub-x;
        e.discrete_indices=prob.discrete_idx; e.discrete_steps=prob.discrete_step;
        e.grid_multiples=gridMultiples; e.bounds_ok=boundsOK; e.grid_ok=gridOK;
        e.physical_quantities=physical;
        e.f_absolute_difference=abs(f-r.best_f);
        e.cv_absolute_difference=abs(cv-r.best_cv);
        e.exact_f_match=(f==r.best_f); e.exact_cv_match=(cv==r.best_cv);
        e.config_hash=optionalString(r,'config_hash');
        e.code_hash=optionalString(r,'code_hash');
        e.problem_hash=optionalString(r,'problem_hash');
        e.n_runs=NaN; e.n_feasible=NaN;
        e.decimal_roundtrip=struct('x',decimalStrings(x),'f',sprintf('%.17g',f),...
            'cv',sprintf('%.17g',cv),'g',decimalStrings(g));
        entries(end+1,1)=e; %#ok<AGROW>
    end
    problemRange=firstEntry:numel(entries);
    for variantId=variantIds
        matching=problemRange(string({entries(problemRange).variant_id})==variantId);
        seeds=[entries(matching).seed];
        assert(numel(matching)==numel(opts.ExpectedSeeds)&&...
            isequal(sort(seeds),sort(opts.ExpectedSeeds)),...
            'PADE:EngineeringCoverage','Incomplete or duplicate seeds for %s/%s.',problemId,variantId);
        [~,seedOrder]=sort(seeds);
        matching=matching(seedOrder);
        bestIndex=matching(1);
        for index=matching(2:end)
            if debBetter(entries(index),entries(bestIndex)), bestIndex=index; end
        end
        selected=entries(bestIndex);
        selected.n_runs=numel(matching);
        selected.n_feasible=sum([entries(matching).strict_feasible]);
        bestEntries(end+1,1)=selected; %#ok<AGROW>
        s=emptySummary();
        s.problem_id=problemId; s.variant_id=variantId; s.role=selected.role;
        s.n_runs=numel(matching); s.n_feasible=selected.n_feasible;
        s.feasible_rate=s.n_feasible/s.n_runs;
        feasible=matching([entries(matching).strict_feasible]);
        costs=[entries(feasible).f_recomputed];
        if ~isempty(costs)
            anchor=costs(1); centeredCosts=costs-anchor;
            s.best_feasible_f=min(costs); s.mean_feasible_f=anchor+mean(centeredCosts);
            s.std_feasible_f=std(centeredCosts); s.worst_feasible_f=max(costs);
            s.median_feasible_f=median(costs);
        end
        s.best_deb_seed=selected.seed; s.best_deb_f=selected.best_f;
        s.best_deb_cv=selected.best_cv;
        s.min_FE=min([entries(matching).FE]); s.max_FE=max([entries(matching).FE]);
        s.objective_unit=selected.objective_unit;
        summaries(end+1,1)=s; %#ok<AGROW>
    end
end

expectedGroups=2*7+13;
assert(numel(bestEntries)==expectedGroups&&...
    numel(entries)==expectedGroups*numel(opts.ExpectedSeeds),...
    'PADE:EngineeringCoverage','Engineering coverage is inconsistent.');
if ~isfolder(outDir), mkdir(outDir); end
writeDesignCSV(fullfile(outDir,'engineering_best.csv'),bestEntries);
writeDesignCSV(fullfile(outDir,'engineering_runs.csv'),entries);
writeResidualCSV(fullfile(outDir,'engineering_residuals.csv'),entries);
writeSummaryCSV(fullfile(outDir,'engineering_summary.csv'),summaries);
report=struct('schema_version','pade-engineering-details-1.0',...
    'created_at',char(datetime('now','TimeZone','UTC','Format',"yyyy-MM-dd'T'HH:mm:ss'Z'")),...
    'raw_directory',char(rawDir),'output_directory',char(outDir),...
    'expected_seeds',opts.ExpectedSeeds,'n_runs',numel(entries),...
    'n_best_designs',numel(bestEntries),'strict_feasibility_tolerance',0,...
    'comparison_relative_tolerance',opts.ComparisonRelativeTolerance,...
    'max_objective_recheck_difference',max([entries.f_absolute_difference]),...
    'max_cv_recheck_difference',max([entries.cv_absolute_difference]),...
    'all_strict_classifications_match',true,'all_bounds_and_grids_pass',true,...
    'independent_model_rechecks',numel(entries),'library_model_rechecks',numel(entries),...
    'search_FE_added',0,'selection_rule','strict Deb; exact ties retain lowest seed',...
    'numeric_precision','CSV %.17g; JSON numeric plus decimal_roundtrip strings',...
    'unit_note',['Cost units and the CB size/mass units follow the supplied numerical ',...
      'benchmark; no unprovided SI conversion or real manufacturing currency is asserted.'],...
    'best_designs',bestEntries,'summaries',summaries);
writeJSON(fullfile(outDir,'engineering_best.json'),report);
end

function e=emptyEntry()
e=struct('problem_id',"",'problem_name',"",'variant_id',"",'role',"",...
    'seed',NaN,'FE',NaN,'source_file',"",'best_f',NaN,'best_cv',NaN,...
    'f_recomputed',NaN,'cv_recomputed',NaN,'strict_feasible',false,...
    'x',[],'x_names',strings(0,1),'x_units',strings(0,1),'objective_unit',"",...
    'g',[],'g_names',strings(0,1),'g_units',strings(0,1),...
    'g_definitions',strings(0,1),'g_satisfied',false(0,1),...
    'lower_bound',[],'upper_bound',[],'lower_margin',[],'upper_margin',[],...
    'discrete_indices',[],'discrete_steps',[],'grid_multiples',[],...
    'bounds_ok',false,'grid_ok',false,'physical_quantities',struct(),...
    'f_absolute_difference',NaN,'cv_absolute_difference',NaN,...
    'exact_f_match',false,'exact_cv_match',false,...
    'config_hash',"",'code_hash',"",'problem_hash',"",...
    'n_runs',NaN,'n_feasible',NaN,'decimal_roundtrip',struct());
end

function s=emptySummary()
s=struct('problem_id',"",'variant_id',"",'role',"",'n_runs',0,'n_feasible',0,...
    'feasible_rate',NaN,'best_feasible_f',NaN,'mean_feasible_f',NaN,...
    'std_feasible_f',NaN,'worst_feasible_f',NaN,'median_feasible_f',NaN,...
    'best_deb_seed',NaN,'best_deb_f',NaN,'best_deb_cv',NaN,...
    'min_FE',NaN,'max_FE',NaN,'objective_unit',"");
end

function role=roleFor(problemId,variantId)
fullId="G2P1J0";
if problemId=="PV", fullId="G2P1J1"; end
if variantId==fullId, role="full";
elseif variantId=="G0P0J0", role="parent";
elseif variantId=="CLASSIC_DE", role="classic";
else, role="ablation";
end
end

function tf=debBetter(a,b)
if a.best_cv==0&&b.best_cv==0, tf=a.best_f<b.best_f;
elseif a.best_cv==0, tf=true;
elseif b.best_cv==0, tf=false;
else, tf=a.best_cv<b.best_cv;
end
end

function value=optionalString(s,name)
value="";
if isfield(s,name), value=string(s.(name)); end
assert(isscalar(value),'PADE:EngineeringMetadata','Metadata must be scalar.');
end

function closeScalar(a,b,tol,label,source)
assert(isfinite(a)&&isfinite(b)&&abs(a-b)<=tol*max([1,abs(a),abs(b)]),...
    'PADE:EngineeringRecheck','%s differs on re-evaluation: %s',label,source);
end

function values=decimalStrings(x)
values=arrayfun(@(v) string(sprintf('%.17g',v)),x);
end

function [f,cv,g,meta,physical]=independentModel(problemId,x)
% Residuals are reimplemented independently of the private library functions.
switch problemId
    case "WB"
        h=x(1); ell=x(2); t=x(3); b=x(4);
        P=6000.0; L=14.0; E=30e6; G=12e6;
        moment=P*(L+ell/2.0);
        radius=sqrt(ell^2/4.0+((h+t)/2.0)^2);
        polar=2.0*(sqrt(2.0)*h*ell*(ell^2/12.0+((h+t)/2.0)^2));
        tau1=P/(sqrt(2.0)*h*ell);
        tau2=moment*radius/polar;
        tau=sqrt(tau1^2+2.0*tau1*tau2*(ell/(2.0*radius))+tau2^2);
        sigma=6.0*P*L/(b*t^2);
        delta=4.0*P*L^3/(E*t^3*b);
        critical=(4.013*E*sqrt(t^2*b^6/36.0)/L^2)*...
            (1.0-t/(2.0*L)*sqrt(E/(4.0*G)));
        f=1.10471*h^2*ell+0.04811*t*b*(14.0+ell);
        g=[tau-13600.0,sigma-30000.0,h-b,...
            0.10471*h^2+0.04811*t*b*(14.0+ell)-5.0,...
            0.125-h,delta-0.25,P-critical];
        meta=struct('x_names',["h","l","t","b"],...
            'x_units',["in","in","in","in"],...
            'objective_unit',"benchmark cost unit",...
            'g_names',["g1_shear","g2_bending","g3_h_le_b","g4_cost",...
              "g5_weld_min","g6_deflection","g7_buckling"],...
            'g_units',["psi","psi","in","benchmark cost residual","in","in","lbf"],...
            'g_definitions',["tau-13600","sigma-30000","h-b",...
              "0.10471*h^2+0.04811*t*b*(14+l)-5","0.125-h","delta-0.25","6000-Pc"]);
        physical=struct('moment_lbf_in',moment,'weld_radius_in',radius,...
            'J_in4',polar,'tau_psi',tau,'sigma_psi',sigma,...
            'deflection_in',delta,'critical_load_lbf',critical);
    case "CB"
        f=0.0624*sum(x);
        g=61.0/x(1)^3+37.0/x(2)^3+19.0/x(3)^3+7.0/x(4)^3+1.0/x(5)^3-1.0;
        meta=struct('x_names',["x1","x2","x3","x4","x5"],...
            'x_units',repmat("benchmark size unit",1,5),...
            'objective_unit',"normalized mass index",'g_names',"g1_deflection",...
            'g_units',"dimensionless",...
            'g_definitions',"61/x1^3+37/x2^3+19/x3^3+7/x4^3+1/x5^3-1");
        coefficients=[61,37,19,7,1];
        analyticSum=sum(coefficients.^0.25);
        physical=struct('normalized_deflection',g+1,...
            'analytic_objective',0.0624*analyticSum^(4/3),...
            'analytic_design',analyticSum^(1/3)*coefficients.^0.25);
    case "PV"
        ts=x(1); th=x(2); radius=x(3); ell=x(4);
        f=0.6224*ts*radius*ell+1.7781*th*radius^2+...
            3.1661*ts^2*ell+19.84*ts^2*radius;
        g=[0.0193*radius-ts,0.0095*radius-th,...
            -pi*radius^2*ell-(4.0/3.0)*pi*radius^3+1296000.0,ell-240.0];
        meta=struct('x_names',["Ts","Th","R","L"],...
            'x_units',["in","in","in","in"],...
            'objective_unit',"benchmark cost unit",...
            'g_names',["g1_shell","g2_head","g3_volume","g4_length"],...
            'g_units',["in","in","in^3","in"],...
            'g_definitions',["0.0193*R-Ts","0.0095*R-Th",...
              "1296000-pi*R^2*L-(4/3)*pi*R^3","L-240"]);
        physical=struct('volume_in3',pi*radius^2*ell+(4.0/3.0)*pi*radius^3,...
            'shell_grid_index',ts/0.0625,'head_grid_index',th/0.0625);
    otherwise
        error('PADE:EngineeringProblem','Unknown engineering problem.');
end
g=reshape(g,1,[]);
cv=0;
for residual=g, cv=cv+max(0.0,residual); end
assert(isfinite(f)&&all(isfinite(g)),'PADE:EngineeringModel','Nonfinite re-evaluation.');
end

function writeDesignCSV(path,entries)
headers={'problem_id','variant_id','role','seed','FE','n_runs','n_feasible',...
    'best_f','best_cv','f_recomputed','cv_recomputed','strict_feasible',...
    'objective_unit','x_names','x_units','x1','x2','x3','x4','x5',...
    'g1','g2','g3','g4','g5','g6','g7','g_units','bounds_ok','grid_ok',...
    'f_abs_recheck_difference','cv_abs_recheck_difference','source_file'};
rows=cell(numel(entries),numel(headers));
for k=1:numel(entries)
    e=entries(k); x=nan(1,5); x(1:numel(e.x))=e.x;
    g=nan(1,7); g(1:numel(e.g))=e.g;
    rows(k,:)=[{e.problem_id,e.variant_id,e.role,e.seed,e.FE,e.n_runs,e.n_feasible,...
        e.best_f,e.best_cv,e.f_recomputed,e.cv_recomputed,e.strict_feasible,...
        e.objective_unit,strjoin(e.x_names,';'),strjoin(e.x_units,';')},...
        num2cell(x),num2cell(g),{strjoin(e.g_units,';'),e.bounds_ok,e.grid_ok,...
        e.f_absolute_difference,e.cv_absolute_difference,e.source_file}];
end
writeCSV(path,headers,rows);
end

function writeResidualCSV(path,entries)
headers={'problem_id','variant_id','role','seed','constraint_index',...
    'constraint_name','definition','residual','unit','satisfied_strict',...
    'positive_violation','source_file'};
n=sum(arrayfun(@(e) numel(e.g),entries)); rows=cell(n,numel(headers)); cursor=0;
for k=1:numel(entries)
    e=entries(k);
    for j=1:numel(e.g)
        cursor=cursor+1;
        rows(cursor,:)={e.problem_id,e.variant_id,e.role,e.seed,j,e.g_names(j),...
            e.g_definitions(j),e.g(j),e.g_units(j),e.g(j)<=0,max(0,e.g(j)),e.source_file};
    end
end
writeCSV(path,headers,rows);
end

function writeSummaryCSV(path,summaries)
headers=fieldnames(emptySummary())'; rows=cell(numel(summaries),numel(headers));
for k=1:numel(summaries)
    for j=1:numel(headers), rows{k,j}=summaries(k).(headers{j}); end
end
writeCSV(path,headers,rows);
end

function writeCSV(path,headers,rows)
temp=string(path)+".part";
fid=fopen(temp,'w','n','UTF-8');
assert(fid>=0,'PADE:EngineeringWrite','Cannot write %s.',temp);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',strjoin(cellfun(@csvCell,headers,'UniformOutput',false),','));
for k=1:size(rows,1)
    values=cellfun(@csvCell,rows(k,:),'UniformOutput',false);
    fprintf(fid,'%s\n',strjoin(values,','));
end
clear cleanup
movefile(temp,path,'f');
end

function value=csvCell(x)
if isnumeric(x)||islogical(x)
    assert(isscalar(x),'PADE:EngineeringCSV','CSV numeric value must be scalar.');
    if isnan(x), value=''; else, value=sprintf('%.17g',double(x)); end
else
    value=char(string(x)); value=strrep(value,'"','""'); value=['"',value,'"'];
end
end

function writeJSON(path,payload)
temp=string(path)+".part";
fid=fopen(temp,'w','n','UTF-8');
assert(fid>=0,'PADE:EngineeringWrite','Cannot write %s.',temp);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(payload,'PrettyPrint',true));
clear cleanup
movefile(temp,path,'f');
end
