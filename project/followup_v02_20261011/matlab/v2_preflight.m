function v2_preflight()
% Geometric fixture checks only. No call to bs_evaluate or any optimizer.
root=fileparts(fileparts(mfilename('fullpath'))); base=fileparts(root);
addpath(fullfile(base,'matlab'),fullfile(base,'matlab','vendor'));
rng(20261011,'twister'); checks=0;
fixtures={ones(8,2),[(1:8)',(8:-1:1)'],[ones(8,1),(1:8)'], ...
    [0 1;0 1;.2 .8;.2 .8;.5 .5;.8 .2;1 0;1 0]};
for z=1:40
    if mod(z,2), F=[sort(rand(32,1)),sort(rand(32,1),'descend')];
    else, F=round(rand(32,2)*5)/5; end
    fixtures{end+1}=F; %#ok<AGROW>
end
for c=[2.5,3,3.5]
    q=load(fullfile(base,'formal_v01',sprintf('cycle%.1f_MODE-CD-G_seed93101.mat',c)));
    fixtures{end+1}=q.result.F; %#ok<AGROW>
end
for z=1:numel(fixtures)
    F=fixtures{z}; n=size(F,1);
    for K=unique([1,2,3,floor(n/2),n-1,n])
        state=rng; a=v2_pcd(F,K); b=reference_pcd(F,K);
        assert(isequal(sort(a(:)),sort(b(:))),'PCD neighbour update mismatch'); assert(isequal(state,rng));
        assert(numel(a)==K && numel(unique(a))==K);
        for method={'cd','pcd','ear'}
            [id,info]=v2_select(F,zeros(n,1),K,method{1});
            assert(numel(id)==K && issorted(id) && isequal(state,rng));
            if info.ear, assert(info.coverage<=info.bound+1e-10); end
        end
        checks=checks+1;
    end
end
% Strict monotone front: both extremes survive for K>=2.
F=[linspace(0,1,40)',linspace(1,0,40)'.^2];
for K=[2,3,10,39], id=v2_pcd(F,K); assert(ismember(1,id)&&ismember(40,id)); end
% Feasible-first and stable CV ties.
F=rand(8,2); CV=[0;0;.2;.1;.1;.4;.6;.7];
for method={'cd','pcd','ear'}
    id=v2_select(F,CV,4,method{1}); assert(isequal(id,[1;2;4;5]));
end
p=bs_config(); q=load(fullfile(base,'formal_v01','cycle3.5_MODE-CD-G_seed93101.mat'));
X=q.result.X; F=q.result.F; CV=q.result.CV; ids=(1:64)';
for method={'cd','pcd'}
    state=rng; a=v2_archive(X,F,CV,ids,32,method{1});
    assert(isequal(state,rng) && issorted(a) && all(CV(a)==0) && numel(a)<=32);
end
% Known DE path: replay RNG and assert domain without objective calls.
rng(471,'twister'); Y=v2_children(X,X(1:10,:),p); state=rng;
rng(471,'twister'); Z=v2_children(X,X(1:10,:),p);
assert(isequal(Y,Z) && isequal(state,rng));
assert(all(Y(:,1)==fix(Y(:,1)))&&all(Y(:,1)>=1&Y(:,1)<=19));
assert(all(Y(:,2:4)>=p.lower'&Y(:,2:4)<=p.upper','all'));
assert(6*2*10*64*501==3847680);
report=struct('status','PASS','date','2026-10-11','MATLAB',version, ...
    'fixture_fronts',numel(fixtures),'PCD_reference_comparisons',checks, ...
    'new_objective_evaluations',0,'checks',{{'PCD vs full recomputation','selection size and canonical order','feasible first','coverage bound','RNG unchanged by selection/archive','DE repeatability and domain','budget arithmetic'}}, ...
    'scope','Deterministic geometric/code checks; not physical validation or optimizer performance.');
fid=fopen(fullfile(root,'provenance','preflight.json'),'w'); cleaner=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report,PrettyPrint=true)); disp(report);
end

function keep=reference_pcd(F,K)
keep=(1:size(F,1))'; if K==1, keep=ec_cd_subset(F,K); return; end
while numel(keep)>K
    A=F(keep,:); n=size(A,1); cd=zeros(n,1);
    for j=1:2
        [~,o]=sortrows([A(:,j),keep],[1 2]); v=A(o,j); cd(o([1 end]))=inf;
        if n>2 && v(end)>v(1), cd(o(2:end-1))=cd(o(2:end-1))+(v(3:end)-v(1:end-2))/(v(end)-v(1)); end
    end
    lowest=min(cd); tie=find(cd==lowest); keep(tie(end))=[];
end
end
