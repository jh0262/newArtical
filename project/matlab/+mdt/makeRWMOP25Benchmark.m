function benchmark = makeRWMOP25Benchmark()
%MAKERWMOP25BENCHMARK Build the H12 type-aware RCM25 benchmark adapter.

variableSpec = struct( ...
    'continuousLower', 0, ...
    'continuousUpper', 1.6, ...
    'discreteCardinalities', 2, ...
    'orderedDiscreteCount', 0, ...
    'constraintScales', [1.25, 1.6]);

benchmark = struct();
benchmark.schema = "mdt.public-benchmark.v1.0";
benchmark.id = "RCM25";
benchmark.name = "Process Synthesis Problem";
benchmark.family = "2021-RW-MOP";
benchmark.sourceProblemIndex = 25;
benchmark.sourceDoi = "10.1016/j.swevo.2021.100961";
benchmark.sourceRepository = ...
    "https://github.com/P-N-Suganthan/2021-RW-MOP";
benchmark.sourceCommit = ...
    "1e2e7d74f535a43a9101cf54f8a808fb16475826";
benchmark.sourceArchiveSha256 = ...
    "2F07B01AC161CFAAD1F13C4987D9B0E4C4EB668070AF6EE79CEC2EE26F1F182F";
benchmark.sourceEvaluatorSha256 = ...
    "B9E257256FEACD7B5679C968118CAB0CCF6211E7400BC892B00E54EC8A124481";
benchmark.sourceParameterSha256 = ...
    "380FF215311AE5713526BD1F59E03E78F09FEF287A38E1B39951C248B16A5547";
benchmark.variableSpec = variableSpec;
benchmark.internalVariableOrder = ["x1", "x2_binary"];
benchmark.externalVariableOrder = ["x1", "x2_binary"];
benchmark.discreteDecode = "x2_binary = x2_code in {0,1}";
benchmark.objectiveCount = 2;
benchmark.platemoEncoding = [1, 4];
benchmark.idealPoint = [2, -2.56];
benchmark.nadirPoint = [3.2, -1.25];
benchmark.hvReferencePoint = benchmark.idealPoint + ...
    1.1*(benchmark.nadirPoint-benchmark.idealPoint);
benchmark.objectiveSense = ["min", "min"];
benchmark.constraintSense = "componentwise <= 0";
benchmark.evaluator = @mdt.evaluateRWMOP25;
benchmark.truthAvailable = false;
benchmark.claimBoundary = ...
    "Public binary process-synthesis adapter; no physical validation.";
end

