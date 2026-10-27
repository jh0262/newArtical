function matrix = makeH14RunMatrix(design)
%MAKEH14RUNMATRIX Expand H14 factorial cells into stable paired run IDs.

required = {'algorithms', 'mainCardinalities', 'mainLayouts', ...
    'componentsPerState', 'boundaryCardinality', 'landscapeSeeds', ...
    'algorithmSeeds', 'populationSize', 'budget', 'expectedFormalRuns'};
if ~isstruct(design) || ~isscalar(design) || ...
        ~all(isfield(design, required))
    error('mdt:InvalidH14Design', 'H14 design lacks required fields.');
end
cells = makeCells(design);
count = height(cells)*numel(design.landscapeSeeds)* ...
    numel(design.algorithmSeeds)*numel(design.algorithms);
matrix = table('Size', [count, 13], 'VariableTypes', ...
    {'string','string','string','string','double','string','double', ...
    'double','double','double','double','string','logical'}, ...
    'VariableNames', {'runId','pairId','landscapeUnitId', ...
    'executionRow','Q','stateLayout','componentsPerState', ...
    'landscapeSeed','algorithmSeed','populationSize','budget', ...
    'algorithm','isBoundary'});
row = 0;
for cellIndex = 1:height(cells)
    cellItem = cells(cellIndex, :);
    for landscapeSeed = design.landscapeSeeds
        landscapeUnitId = cellItem.executionRow+ ...
            "__land-"+landscapeSeed;
        for algorithmSeed = design.algorithmSeeds
            pairId = landscapeUnitId+"__algseed-"+algorithmSeed;
            for algorithm = design.algorithms
                row = row+1;
                matrix.runId(row) = pairId+"__"+algorithm;
                matrix.pairId(row) = pairId;
                matrix.landscapeUnitId(row) = landscapeUnitId;
                matrix.executionRow(row) = cellItem.executionRow;
                matrix.Q(row) = cellItem.Q;
                matrix.stateLayout(row) = cellItem.stateLayout;
                matrix.componentsPerState(row) = ...
                    cellItem.componentsPerState;
                matrix.landscapeSeed(row) = landscapeSeed;
                matrix.algorithmSeed(row) = algorithmSeed;
                matrix.populationSize(row) = design.populationSize;
                matrix.budget(row) = design.budget;
                matrix.algorithm(row) = algorithm;
                matrix.isBoundary(row) = cellItem.isBoundary;
            end
        end
    end
end
if row ~= count || row ~= design.expectedFormalRuns || ...
        numel(unique(matrix.runId)) ~= row
    error('mdt:InvalidH14RunMatrix', ...
        'Expanded H14 matrix has invalid coverage or duplicate run IDs.');
end
end

function cells = makeCells(design)
count = numel(design.mainCardinalities)*numel(design.mainLayouts)* ...
    numel(design.componentsPerState)+numel(design.componentsPerState);
cells = table('Size', [count, 5], 'VariableTypes', ...
    {'string','double','string','double','logical'}, ...
    'VariableNames', {'executionRow','Q','stateLayout', ...
    'componentsPerState','isBoundary'});
row = 0;
for Q = design.mainCardinalities
    for layout = design.mainLayouts
        for L = design.componentsPerState
            row = row+1;
            cells.executionRow(row) = "H14-Q"+Q+"-"+ ...
                upper(layout)+"-L"+L;
            cells.Q(row) = Q;
            cells.stateLayout(row) = layout;
            cells.componentsPerState(row) = L;
            cells.isBoundary(row) = false;
        end
    end
end
for L = design.componentsPerState
    row = row+1;
    cells.executionRow(row) = "H14-Q2-BOUNDARY-L"+L;
    cells.Q(row) = design.boundaryCardinality;
    cells.stateLayout(row) = "boundary";
    cells.componentsPerState(row) = L;
    cells.isBoundary(row) = true;
end
end
