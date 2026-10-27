function tests = test_core
tests = functiontests(localfunctions);
end

function testHypervolumeGold(t)
F=[0 1;.5 .5;1 0];
verifyEqual(t,ec_hv2(F,[1.1 1.1]),.46,'AbsTol',1e-12);
verifyEqual(t,ec_hv2(F([1 3],:),[1.1 1.1]),.21,'AbsTol',1e-12);
verifyEqual(t,ec_hv2([F;F;2 2],[1.1 1.1]),.46,'AbsTol',1e-12);
verifyEqual(t,ec_hv2([2 0;0 2],[1.1 1.1]),0,'AbsTol',1e-12);
end

function testIGDPlusGold(t)
verifyEqual(t,ec_igdplus([0 1;1 0],[0 1;.5 .5;1 0]),1/6,'AbsTol',1e-12);
verifyEqual(t,ec_igdplus([-1 -1],[0 0;1 1]),0,'AbsTol',1e-12);
end

function testEarCoverageAndExtremes(t)
rng(114,'twister');
for trial=1:12
    x=sort(rand(40,1)); F=[x,1-sqrt(x)];
    [idx,info]=ec_earclip(F,12);
    cd=ec_cd_subset(F,12);
    z=(F-min(F))./max(max(F)-min(F),eps);
    verifyLessThanOrEqual(t,max(min(pdist2(z,z(idx,:)),[],2)),max(min(pdist2(z,z(cd,:)),[],2))+1e-10);
    verifyEqual(t,numel(unique(idx)),12);
    verifyTrue(t,ismember(1,idx)&&ismember(40,idx));
    verifyTrue(t,isfinite(info.coverage));
end
end

function testEarCollinearDuplicatesAndScaling(t)
F=[linspace(0,1,31)',linspace(1,0,31)'];
[i,~]=ec_earclip(F,7);
[j,~]=ec_earclip(F.*[1000 .002]+[23 -4],7);
verifyEqual(t,sort(i),sort(j));
verifyLessThan(t,max(min(pdist2(F,F(i,:)),[],2)),.3);
[k,~]=ec_earclip(repmat([1 1],10,1),4);
verifyEqual(t,numel(unique(k)),4);
end

function testSelectionDominancePriority(t)
F=[0 1;.5 .5;1 0;2 2;3 3;4 4];
[idx,~]=ec_select(F,3,true);
verifyEqual(t,sort(idx),1:3);
end

function testGuideWeights(t)
F=[0 1;.01 .99;.02 .98;.6 .4;1 0];
w=ec_guide_weights(F);
verifyEqual(t,sum(w),1,'AbsTol',1e-12);
verifyGreaterThan(t,min(w),0);
verifyTrue(t,all(isfinite(ec_guide_weights(ones(5,2)))));
end

function testIndependentCredit(t)
G=[0 1;1 0]; Q=[.5 .5;.5 .5;2 2];
g=ec_credit(Q,G);
verifyEqual(t,g(1),g(2),'AbsTol',1e-12);
verifyGreaterThan(t,g(1),0);
verifyEqual(t,g(3),0,'AbsTol',1e-12);
verifyEqual(t,ec_credit(G,G),zeros(2,1),'AbsTol',1e-12);
end

function testAdaptationBoundsAndNoSuccess(t)
s=ec_state(); original=s;
s=ec_adapt(s,[.2;.8],[.1;.9],[0;0],[1;2],true);
verifyEqual(t,s,original);
s=ec_adapt(s,[.2;.8],[.1;.9],[1;2],[1;2],true);
verifyGreaterThan(t,min(s.MF),0); verifyLessThanOrEqual(t,max(s.MF),1);
verifyGreaterThanOrEqual(t,min(s.MCR),0); verifyLessThanOrEqual(t,max(s.MCR),1);
verifyGreaterThanOrEqual(t,s.pLocal,.1); verifyLessThanOrEqual(t,s.pLocal,.9);
end

function testVariationBoundsAndReproduction(t)
rng(5,'twister'); X=rand(24,5); F=[sum(X,2),sum((X-1).^2,2)];
cfg=struct('A',true,'B',true,'C',true,'adaptive',true,'shuffle',false);
rng(12,'twister'); [Y,meta]=ec_offspring(X,F,X,F,zeros(1,5),ones(1,5),ec_state(),cfg);
rng(12,'twister'); [Z,meta2]=ec_offspring(X,F,X,F,zeros(1,5),ones(1,5),ec_state(),cfg);
verifyEqual(t,Y,Z); verifyEqual(t,meta,meta2);
verifyGreaterThanOrEqual(t,min(Y,[],'all'),0); verifyLessThanOrEqual(t,max(Y,[],'all'),1);
verifyTrue(t,all(any(Y~=X,2))); verifySize(t,Y,size(X));
end
