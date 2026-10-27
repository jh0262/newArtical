function counterfactuals()
% Saved-objective replay only. Never calls the physical model or optimizer.
root=fileparts(mfilename('fullpath')); base=fileparts(root);
addpath(fullfile(root,'matlab'),fullfile(base,'matlab'),fullfile(base,'matlab','vendor'));
out=fullfile(root,'analysis'); if ~isfolder(out), mkdir(out); end
files=dir(fullfile(root,'raw','*.mat')); assert(numel(files)==120); summary=[]; maximumError=0; beforeRNG=rng;
p=bs_config(); batch=tic;
for k=1:numel(files)
    s=load(fullfile(files(k).folder,files(k).name)); r=s.result; X=r.history_X; F=r.history_F; CV=r.history_CV;
    history=find(CV(1:64)==0); history=sort(history(ec_nd_indices(F(history,:))));
    D=zeros(500,12); counts=zeros(3,1);
    for g=1:500
        parent=double(r.population_ids(g,:))'; actual=double(r.population_ids(g+1,:))'; child=(64*g+1:64*(g+1))'; U=sort([parent;child]);
        h0=bs_hv(F(parent(CV(parent)==0),:),p); hu=bs_hv(F(U(CV(U)==0),:),p);
        hactual=bs_hv(F(actual(CV(actual)==0),:),p); gain=hu-h0; loss=hu-hactual;
        assert(gain>=-1e-12 && loss>=-1e-12); assert(abs(hactual-h0-gain+loss)<1e-12);
        h=zeros(1,3); methods={'cd','pcd','ear'};
        for j=1:3
            id=v2_select(F(U,:),CV(U),64,methods{j}); selected=U(id); h(j)=bs_hv(F(selected(CV(selected)==0),:),p);
            if strcmp(r.population_method,methods{j}), assert(isequal(selected,actual),'V2:Replay','Population replay mismatch'); end
            counts(j)=counts(j)+1;
        end
        previousA=double(r.archive_ids(g,:))'; previousA=previousA(previousA>0);
        expectedA=v2_archive(X,F,CV,[previousA;child(CV(child)==0)],64,r.archive_method);
        actualA=double(r.archive_ids(g+1,:))'; actualA=actualA(actualA>0); assert(isequal(expectedA,actualA),'V2:Replay','Guide replay mismatch');
        history=sort([history;child(CV(child)==0)]); history=sort(history(ec_nd_indices(F(history,:))));
        hhistory=bs_hv(F(history,:),p); assert(hhistory>=hactual-1e-12);
        D(g,:)=[g,64*(g+1),h0,hu,hactual,gain,loss,h,hhistory,numel(history)];
        maximumError=max(maximumError,abs(hactual-r.trace(g+1,3)));
    end
    historyHV=bs_hv(F(history,:),p); retained=history;
    if numel(history)>64, retained=history(v2_pcd(F(history,:),64)); end
    commonHV=bs_hv(F(retained,:),p);
    expectedWhole=ec_nd_indices(F(CV==0,:)); feasible=find(CV==0); assert(abs(bs_hv(F(feasible(expectedWhole),:),p)-historyHV)<1e-12);
    tableD=array2table(D,'VariableNames',{'generation','FE','parent_HV','union_HV','selected_HV','generation_gain','selection_loss','CD_HV','PCD_HV','EAR_HV','history_HV','history_ND_size'});
    writetable(tableD,fullfile(out,replace(files(k).name,'.mat','_replay.csv')));
    writematrix([retained,X(retained,:),F(retained,:),CV(retained)],fullfile(out,replace(files(k).name,'.mat','_history64.csv')));
    summary=[summary;table(r.cycle_limit_s,string(r.label),r.seed,r.trace(end,3),historyHV,numel(history),commonHV, ...
        sum(D(:,6)),sum(D(:,7)),mean(D(:,9)-D(:,8)),mean(D(:,10)-D(:,9)),max(D(:,12)), ...
        'VariableNames',{'cycle_limit_s','method','seed','final_HV','history_HV','history_ND_size','common_PCD64_HV','sum_generation_gain','sum_selection_loss','mean_PCD_minus_CD_same_pool','mean_EAR_minus_PCD_same_pool','max_history_ND_size'})]; %#ok<AGROW>
    if mod(k,10)==0, fprintf('Replay %d/120; %.1f s\n',k,toc(batch)); end
end
assert(isequal(beforeRNG,rng)); writetable(summary,fullfile(out,'retention_summary.csv'));
audit=struct('status','PASS','runs',120,'generations_replayed',60000,'selectors_replayed',180000,'archives_replayed',60000, ...
    'maximum_HV_trace_error',maximumError,'new_objective_evaluations',0,'RNG_unchanged',true,'seconds',toc(batch), ...
    'scope','Offline selection and archive replay on recorded objectives; no feedback into original search.');
fid=fopen(fullfile(out,'replay_audit.json'),'w');fprintf(fid,'%s',jsonencode(audit,PrettyPrint=true));fclose(fid);disp(audit);
end
