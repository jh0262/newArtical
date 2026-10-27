function matrix = makeH13RunMatrix(design)
%MAKEH13RUNMATRIX Expand the H13 design into stable paired run identities.

required = {'problems', 'algorithms', 'seeds', 'populationSize', ...
    'expectedRuns', 'matrixRows'};
if ~isstruct(design) || ~isscalar(design) || ...
        ~all(isfield(design, required))
    error('mdt:InvalidH13Design', 'H13 design lacks required fields.');
end

count = numel(design.problems)*numel(design.algorithms)*numel(design.seeds);
matrix = table('Size', [count, 9], 'VariableTypes', ...
    {'string','string','string','double','double','double','double', ...
    'string','string'}, 'VariableNames', ...
    {'runId','pairId','problemId','seed','populationSize', ...
    'nominalBudget','executionBudget','algorithm','matrixRow'});
row = 0;
for problemIndex = 1:numel(design.problems)
    problem = design.problems(problemIndex);
    for seed = design.seeds
        pairId = problem.id+"__seed-"+seed;
        for algorithm = design.algorithms
            row = row+1;
            matrix.runId(row) = problem.id+"__"+algorithm+"__seed-"+seed;
            matrix.pairId(row) = pairId;
            matrix.problemId(row) = problem.id;
            matrix.seed(row) = seed;
            matrix.populationSize(row) = design.populationSize;
            matrix.nominalBudget(row) = problem.nominalBudget;
            matrix.executionBudget(row) = problem.executionBudget;
            matrix.algorithm(row) = algorithm;
            matrix.matrixRow(row) = design.matrixRows(problemIndex);
        end
    end
end
if row ~= design.expectedRuns || numel(unique(matrix.runId)) ~= row
    error('mdt:InvalidH13RunMatrix', ...
        'Expanded H13 matrix has invalid coverage or duplicate run IDs.');
end
end
