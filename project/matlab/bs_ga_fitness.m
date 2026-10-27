function fitness=bs_ga_fitness(F,CV,isSpea)
% Fitness assigned on the environmental candidate union, then retained.
% Infeasible points cannot change rank/density of the feasible subset.
n=size(F,1); valid=find(CV==0); rank=inf(n,1); cd=zeros(n,1);
if ~isempty(valid)
    if isSpea
        rank(valid)=bs_spea_fitness(F(valid,:));
    else
        [rr,~]=NDSort(F(valid,:),inf); rank(valid)=rr';
        for r=unique(rr)
            ix=valid(rr==r); ff=F(ix,:); v=zeros(numel(ix),1);
            for j=1:2
                [s,o]=sort(ff(:,j)); v(o([1,end]))=inf;
                if numel(ix)>2 && s(end)>s(1), v(o(2:end-1))=v(o(2:end-1))+(s(3:end)-s(1:end-2))/(s(end)-s(1)); end
            end
            cd(ix)=v;
        end
    end
end
fitness=[CV>0,CV,rank,-cd];
end
