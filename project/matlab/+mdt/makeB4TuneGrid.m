function grid = makeB4TuneGrid()
%MAKEB4TUNEGRID Balanced 2x2x2 novelty-control grid.

minimums = [0.02, 0.05];
maximums = [0.20, 0.30];
horizons = [3, 10];
grid = repmat(struct('configId', "", 'noveltyFractionMin', 0, ...
    'noveltyFractionMax', 0, 'stagnationHorizon', 0), 1, 8);
cursor = 0;
for minimum = minimums
    for maximum = maximums
        for horizon = horizons
            cursor = cursor+1;
            grid(cursor).configId = "B4-" + compose("%03d", cursor);
            grid(cursor).noveltyFractionMin = minimum;
            grid(cursor).noveltyFractionMax = maximum;
            grid(cursor).stagnationHorizon = horizon;
        end
    end
end
end
