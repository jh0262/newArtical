function recompute_exact
base=fileparts(mfilename('fullpath'));
for stage=[4,5]
 if stage==4,name='MO_PACPO_创新性对照修订_20261025';else,name='MO_PACPO_Machines_P1联合对照修订_20261025';end
 R=fullfile(base,name,'data');a=load(fullfile(R,'analysis.mat'));runs=a.runs;rows={};
 if stage==5
  t=a.statistics;
  for i=1:height(t)
   q=t(i,:);v=@(m)values(runs,q,m);parts=split(q.Contrast,'_');
   if q.Contrast=="Interaction",d=(v("Full")-v("noNoise"))-(v("noLock")-v("joint"));else,d=v(parts(1))-v(parts(2));end
   [p,n]=exact(d);rows{end+1}=table(q.Problem,q.Metric,q.IntegrationPoints,q.Contrast,n,p,q.RawP,q.HolmP,'VariableNames',{'Problem','Metric','IntegrationPoints','Contrast','NonzeroPairs','ExactP','ApproxP','ApproxHolmP'});
  end
  out=vertcat(rows{:});group=findgroups(out.Problem,out.Metric,out.IntegrationPoints);
 else
  for kind=["Factorial","MOCPO"]
   if kind=="Factorial",t=a.factor;else,t=a.external;end
   for i=1:height(t)
    q=t(i,:);v=@(m)values(runs,q,m);
    if kind=="Factorial"
     comparison=q.Contrast;
     switch comparison
      case "DirectionDouble",d=v("DL")-v("DR");
      case "DirectionSingle",d=v("SL")-v("SR");
      case "TriggerLow",d=v("DL")-v("SL");
      case "TriggerRandom",d=v("DR")-v("SR");
      case "Interaction",d=(v("DL")-v("DR"))-(v("SL")-v("SR"));
     end
    else,comparison=q.Comparator;d=v("DL")-v(comparison);end
    [p,n]=exact(d);rows{end+1}=table(kind,q.Problem,q.Metric,q.IntegrationPoints,comparison,n,q.RawP,p,q.HolmP,'VariableNames',{'Kind','Problem','Metric','IntegrationPoints','Comparison','NonzeroPairs','ApproxP','ExactP','ApproxHolmP'});
   end
  end
  out=vertcat(rows{:});problemFamily=out.Problem;problemFamily(out.Kind=="MOCPO"&out.Problem~="PPAR")="AllBenchmarks";group=findgroups(out.Kind,problemFamily,out.Metric,out.IntegrationPoints);
 end
 out.ExactHolmP=nan(height(out),1);
 for g=unique(group)',idx=find(group==g);p=out.ExactP(idx);bad=~isfinite(p);p(bad)=1;[ps,ord]=sort(p);q=min(1,cummax(ps.*(numel(p):-1:1)'));h=zeros(size(q));h(ord)=q;h(bad)=NaN;out.ExactHolmP(idx)=h;end
 out.DecisionChanged=repmat("False",height(out),1);out.DecisionChanged((out.ExactHolmP<.05)~=(out.ApproxHolmP<.05))="True";
 if stage==4,file='signedrank_exact_sensitivity.csv';else,file='joint_exact_sensitivity.csv';end
 writetable(out,fullfile(R,file));
end
end
function a=values(r,q,m)
t=sortrows(r(r.Problem==q.Problem&r.Variant==m&r.IntegrationPoints==q.IntegrationPoints,:),'Seed');assert(height(t)==30);a=t.(q.Metric);
end
function [p,n]=exact(d)
d=d(isfinite(d));d=d(d~=0);n=numel(d);if n==0,p=1;return;end
w=round(2*tiedrank(abs(d)));counts=1;
for i=1:n,c=zeros(1,numel(counts)+w(i));c(1:numel(counts))=counts;c(w(i)+(1:numel(counts)))=c(w(i)+(1:numel(counts)))+counts;counts=c;end
obs=sum(w(d>0));p=min(1,2*min(sum(counts(1:obs+1)),sum(counts(obs+1:end)))/2^n);
end
