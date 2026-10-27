function result=MO_PACPO_2PPaPaR_Optimization_P1(variant,seed)
% One frozen engineering search, followed by the declared fine evaluation.
% Example: r=MO_PACPO_2PPaPaR_Optimization_P1('revised',400001);
if nargin<1,variant='revised';end
if nargin<2,seed=400001;end
root=fileparts(mfilename('fullpath'));addpath(root,fullfile(root,'reference'));
p=PACPOP1.problem('PPAR');c=P1Variants.config(variant,seed);
if strcmp(variant,'GDE3'),result=P1GDE3.solve(p,c);else,result=PACPOP1.solve(p,'PACPO',c);end
[f,cv]=PPaPaRModel.evaluate(result.X,PPaPaRModel.config(262144));
keep=cv==0 & ~any(PACPOP1.dominance(f,cv),1)';[~,hv,sp]=PACPOP1.metrics(p,f(keep,:));
result.refined=struct('F',f,'CV',cv,'keep',keep,'HV',hv,'Spacing',sp,'integrationPoints',262144);
end
