function summary = runH12PublicComparisonSmoke()
%RUNH12PUBLICCOMPARISONSMOKE Run the authorized 3-by-5 interface matrix.

registry = mdt.makeH12PublicBenchmarkSet();
internalAlgorithms = ["B1", "B5S", "N2"];
officialAlgorithms = ["NSGAII", "CCMO"];
seed = 12025;
N = 12;
budget = 36;
archiveCapacity = 24;

runs = repmat(struct( ...
    'benchmark', "", 'algorithm', "", 'status', "", ...
    'evaluatorCalls', NaN, 'finiteOutputs', false, ...
    'finalFeasibleRate', NaN, 'finalArchiveSize', NaN, ...
    'message', ""), 1, numel(registry.included)*5);
index = 0;

for problemIndex = 1:numel(registry.included)
    benchmark = registry.included(problemIndex);
    dimension = numel(benchmark.variableSpec.continuousLower) + ...
        numel(benchmark.variableSpec.discreteCardinalities);
    op = struct('F', 0.3, 'CR', 0.5, 'FCategory', 0.75, ...
        'noveltyFractionMin', 0.05, 'noveltyFractionMax', 0.30, ...
        'stagnationHorizon', 10, 'crossoverProbability', 0.9, ...
        'mutationProbability', 1/dimension, 'etaC', 20, 'etaM', 20);

    for algorithm = [internalAlgorithms, officialAlgorithms]
        index = index+1;
        runs(index).benchmark = benchmark.id;
        runs(index).algorithm = algorithm;
        try
            if ismember(algorithm, internalAlgorithms)
                result = mdt.runBlackBoxComparator(algorithm, ...
                    benchmark.evaluator, benchmark.variableSpec, op, ...
                    seed, N, budget, archiveCapacity);
            else
                result = mdt.runPlatEMOBaseline(algorithm, benchmark, ...
                    seed, N, budget);
            end
            runs(index).evaluatorCalls = result.audit.evaluatorCalls;
            runs(index).finiteOutputs = ...
                all(isfinite(result.finalPopulation.obj), 'all') && ...
                all(isfinite(result.finalPopulation.con), 'all');
            runs(index).finalFeasibleRate = ...
                mean(all(result.finalPopulation.con <= 0, 2));
            runs(index).finalArchiveSize = size(result.finalArchive.X, 1);
            if runs(index).evaluatorCalls == budget && runs(index).finiteOutputs
                runs(index).status = "passed";
            else
                runs(index).status = "failed";
                runs(index).message = "budget or finite-output contract failed";
            end
        catch errorRecord
            runs(index).status = "failed";
            runs(index).message = string(errorRecord.identifier) + ": " + ...
                string(errorRecord.message);
        end
    end
end

passed = [runs.status] == "passed";
summary = struct();
summary.schema = "mdt.h12-public-comparison-smoke.v1.0";
summary.scope = "execution smoke only; no public performance comparison";
summary.seed = seed;
summary.populationSize = N;
summary.evaluationBudget = budget;
summary.runs = runs;
summary.totalCombinations = numel(runs);
summary.completedCombinations = nnz(passed);
summary.formalPerformanceRuns = 0;
summary.allPassed = all(passed);
end

