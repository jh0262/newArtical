function ec_reproduce500()
root=ec_setup(); ec_assert_frozen(root);
c=ec_config('smoke'); c.generations=500;
base=fullfile(root,'verification',['reproduce500_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
a=ec_run_one(c,1,8,99006,fullfile(base,'run_a'));
b=ec_run_one(c,1,8,99006,fullfile(base,'run_b'));
assert(isequal(a.initialX,b.initialX) && isequal(a.Fronts,b.Fronts) && isequal(a.finalX,b.finalX) && isequal(a.Telemetry,b.Telemetry) && isequal(a.HV,b.HV));
ec_jsonwrite(fullfile(root,'provenance','reproduction500.json'),struct('status','PASS','scope','Two independent 500-generation G111 runs on ZDT1, same MATLAB and host; bitwise equality of decisions, every-generation fronts, HV and adaptation telemetry','directory',base,'seed',99006,'FE_each',50100,'completed_at',char(datetime('now','TimeZone','UTC'))));
disp('INDEPENDENT_500_GENERATION_REPRODUCTION_PASS');
end
