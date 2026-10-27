function P1AreaValidate()
root=fileparts(mfilename('fullpath'));t=linspace(0,1,200)';
fronts={[(0:199)',(199:-1:0)'],[t,1-t+1e-10*sin(17*t)],[t,1-sqrt(t)]};
p=PACPOP1.problem('ZDT3');fronts{4}=p.pf(round(linspace(1,size(p.pf,1),200)),:);
names=["linear","near_linear","convex","disconnected"];rows={};selected=cell(4,2);
for k=1:4
    f=sortrows(fronts{k},[1,2]);fronts{k}=f;originalGap=max(vecnorm(diff(f),2,2));
    for j=1:2
        modes=["onepass","progressive"];ix=PACPOP1.areaPrune(f,100,char(modes(j)));q=sortrows(f(ix,:),1);selected{k,j}=q;
        assert(size(q,1)==100 && size(unique(q,'rows'),1)==100);
        assert(ismember(f(1,:),q,'rows')&&ismember(f(end,:),q,'rows'));
        rows{end+1}=table(names(k),modes(j),max(vecnorm(diff(q),2,2)),max(vecnorm(diff(q),2,2))/originalGap,'VariableNames',{'Front','Mode','MaximumGap','GapRatio'}); %#ok<AGROW>
    end
end
results=vertcat(rows{:});writetable(results,fullfile(root,'validation','area_geometry.csv'));save(fullfile(root,'validation','area_geometry.mat'),'fronts','selected','results');
assert(abs(results.GapRatio(1)-101)<1e-12&&results.GapRatio(2)<=4+1e-12);
end
