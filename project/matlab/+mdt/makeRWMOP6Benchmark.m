function benchmark = makeRWMOP6Benchmark()
%MAKERWMOP6BENCHMARK Build the H11 type-aware RCM06 benchmark adapter.
%
% Internal B5S order:
%   [x1, x2, x4, x5, x6, x7, x3_code]
% Published RCM06 order:
%   [x1, x2, x3_integer, x4, x5, x6, x7]
% where x3_integer = x3_code + 17.

variableSpec = struct( ...
    'continuousLower', [2.6, 0.7, 7.3, 7.3, 2.9, 5.0], ...
    'continuousUpper', [3.6, 0.8, 8.3, 8.3, 3.9, 5.5], ...
    'discreteCardinalities', 12, ...
    'orderedDiscreteCount', 1, ...
    'constraintScales', [1/27, 1/397.5, 1/1.93, 1/1.93, ...
        40, 12, 5, 1.9, 1.9, 1300, 850]);

benchmark = struct();
benchmark.schema = "mdt.public-benchmark.v1.0";
benchmark.id = "RCM06";
benchmark.name = "Speed Reducer Design";
benchmark.family = "2021-RW-MOP";
benchmark.sourceProblemIndex = 6;
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
benchmark.internalVariableOrder = ...
    ["x1", "x2", "x4", "x5", "x6", "x7", "x3_code"];
benchmark.externalVariableOrder = ...
    ["x1", "x2", "x3_integer", "x4", "x5", "x6", "x7"];
benchmark.discreteDecode = "x3_integer = x3_code + 17";
benchmark.objectiveCount = 2;
benchmark.platemoEncoding = [ones(1, 6), 2];
benchmark.idealPoint = [0, 0];
benchmark.nadirPoint = [5969.8221, 1300];
benchmark.hvReferencePoint = benchmark.idealPoint + ...
    1.1*(benchmark.nadirPoint-benchmark.idealPoint);
benchmark.objectiveSense = ["min", "min"];
benchmark.constraintSense = "componentwise <= 0";
benchmark.evaluator = @mdt.evaluateRWMOP6;
benchmark.truthAvailable = false;
benchmark.claimBoundary = ...
    "Public mixed-integer engineering adapter; not a disconnected-topology superiority result.";
end
