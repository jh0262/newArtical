function ec_preflight()
root=ec_setup(); cfg=ec_config('smoke'); cfg.generations=5;
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
base=fullfile(root,'verification',['preflight_' stamp]);
for pi=1:numel(cfg.problems)
    r=ec_run_one(cfg,pi,8,99004,fullfile(base,cfg.problems(pi).name));
    assert(all(isfinite(r.referenceF),'all') && all(r.referenceSpan>0));
end
cfg.generations=500;
for ai=[8 10 11 12]
    ec_run_one(cfg,1,ai,99005,fullfile(base,['long_' cfg.algorithms(ai).name]));
end
% F/CR sampling, selection metrics and source imports are statically checked.
files=dir(fullfile(root,'src','*.m')); issues=struct('file',{},'message',{},'line',{});
for k=1:numel(files)
    problems=checkcode(fullfile(files(k).folder,files(k).name),'-id');
    for j=1:numel(problems)
        issues(end+1)=struct('file',files(k).name,'message',problems(j).message,'line',problems(j).line); %#ok<AGROW>
    end
end
ec_jsonwrite(fullfile(root,'provenance','code_analyzer.json'),issues);
ec_jsonwrite(fullfile(root,'provenance','study_config.json'),ec_config('formal'));
ec_jsonwrite(fullfile(root,'provenance','preflight_completed.json'),struct('status','passed','directory',base,'timestamp',char(datetime('now','TimeZone','UTC')),'scope','8 problems, 4 algorithms with 500 generations, 13-algorithm short integration and independent candidate reproduction; verification seeds excluded from formal inference'));
end
