function registry = makeH12PublicBenchmarkSet()
%MAKEH12PUBLICBENCHMARKSET Return the frozen H12 public problem registry.

included = [
    rmfield(mdt.makeRWMOP6Benchmark(), 'evaluator')
    rmfield(mdt.makeRWMOP19Benchmark(), 'evaluator')
    rmfield(mdt.makeRWMOP25Benchmark(), 'evaluator')];
included(1).evaluator = @mdt.evaluateRWMOP6;
included(2).evaluator = @mdt.evaluateRWMOP19;
included(3).evaluator = @mdt.evaluateRWMOP25;

excluded = struct( ...
    'id', {"RCM01", "RCM15", "RCM29"}, ...
    'reason', { ...
    "paper equation (4) and official code use different variables", ...
    "published specification table contains decimal-transcription risk", ...
    "paper equation (71) and official code define f1 differently"});

registry = struct();
registry.schema = "mdt.h12-public-benchmark-registry.v1.0";
registry.included = included;
registry.excluded = excluded;
registry.continuousTopologyReferences = ...
    ["LIRCMOP12", "DASCMOP6", "MW12"];
registry.continuousReferenceBoundary = ...
    "Original continuous problems are references only; any discretization requires a derived name and separate freeze.";
end

