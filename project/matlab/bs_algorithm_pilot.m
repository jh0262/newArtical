function bs_algorithm_pilot()
p=bs_config(); p.cycle_limit_s=3;
addpath(fullfile(p.root,'matlab','vendor'));
out=fullfile(p.root,'pilot_v02'); if ~isfolder(out), mkdir(out); end
names={'MODE-CD-G','MODE-EAR-G','MODE-CD-S','MODE-EAR-S','MV-NSGA-II','MV-SPEA2'};
summary=[];
for i=1:numel(names)
    result=bs_mode(names{i},92102,64,100,p);
    assert(result.FE==6464 && result.max_coverage_excess<1e-10);
    save(fullfile(out,[names{i},'_seed92102.mat']),'result');
    summary=[summary;table(string(names{i}),result.seconds,result.trace(end,3),result.trace(end,4),result.ear_calls,result.ear_fallbacks, ...
        'VariableNames',{'method','seconds','HV','feasible_fraction','ear_calls','ear_fallbacks'})]; %#ok<AGROW>
end
writetable(summary,fullfile(out,'pilot_summary.csv')); disp(summary);
end
