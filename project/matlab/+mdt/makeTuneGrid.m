function grid = makeTuneGrid()
%MAKETUNEGRID Return the frozen equal-budget TUNE-01 parameter grids.

b0F = [0.30, 0.45, 0.60, 0.75, 0.90, 1.05];
b0CR = [0.20, 0.45, 0.70, 0.95];
b1F = [0.30, 0.50, 0.70, 0.90];
b1CR = [0.20, 0.50, 0.80];
b1FCategory = [0.25, 0.75];

grid = struct();
grid.schema = "mdt.tune-grid.v0.1";
grid.B0 = makeGrid("B0", b0F, b0CR, 0.50);
grid.B1 = makeGrid("B1", b1F, b1CR, b1FCategory);
end

function rows = makeGrid(algorithm, fValues, crValues, categoryValues)
count = numel(fValues)*numel(crValues)*numel(categoryValues);
rows = repmat(struct('configId', "", 'algorithm', algorithm, ...
    'F', 0, 'CR', 0, 'FCategory', 0), count, 1);
index = 0;
for f = fValues
    for cr = crValues
        for fCategory = categoryValues
            index = index + 1;
            rows(index).configId = algorithm + "-" + compose("%03d", index);
            rows(index).F = f;
            rows(index).CR = cr;
            rows(index).FCategory = fCategory;
        end
    end
end
end

