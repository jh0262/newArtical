function benchmark = makeRWMOP19Benchmark()
%MAKERWMOP19BENCHMARK Build the H12 type-aware RCM19 benchmark adapter.
%
% Internal B5S order:
%   [V1,V2,V3,TL1,TL2,B1,B2,N1_code,N2_code,N3_code]
% Published RCM19 order:
%   [N1,N2,N3,V1,V2,V3,TL1,TL2,B1,B2]
% where Nj = Nj_code + 1.

variableSpec = struct( ...
    'continuousLower', [250, 250, 250, 6, 4, 40, 10], ...
    'continuousUpper', [2500, 2500, 2500, 20, 16, 700, 450], ...
    'discreteCardinalities', [3, 3, 3], ...
    'orderedDiscreteCount', 3, ...
    'constraintScales', [6000, 2500, 2500, 2500, 8, 20, 8, 16, 4, 4]);

benchmark = struct();
benchmark.schema = "mdt.public-benchmark.v1.0";
benchmark.id = "RCM19";
benchmark.name = "Multi-product Batch Plant";
benchmark.family = "2021-RW-MOP";
benchmark.sourceProblemIndex = 19;
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
benchmark.internalVariableOrder = ["V1", "V2", "V3", "TL1", "TL2", ...
    "B1", "B2", "N1_code", "N2_code", "N3_code"];
benchmark.externalVariableOrder = ["N1", "N2", "N3", "V1", "V2", ...
    "V3", "TL1", "TL2", "B1", "B2"];
benchmark.discreteDecode = "Nj = Nj_code + 1 for j=1,2,3";
benchmark.objectiveCount = 3;
benchmark.platemoEncoding = [ones(1, 7), 2, 2, 2];
benchmark.idealPoint = [0, 0, 0];
benchmark.nadirPoint = [244351.82, 48572.551, 6000];
benchmark.hvReferencePoint = benchmark.idealPoint + ...
    1.1*(benchmark.nadirPoint-benchmark.idealPoint);
benchmark.objectiveSense = ["min", "min", "min"];
benchmark.constraintSense = "componentwise <= 0";
benchmark.evaluator = @mdt.evaluateRWMOP19;
benchmark.truthAvailable = false;
benchmark.claimBoundary = ...
    "Public mixed-integer process-design adapter; no physical validation.";
end

