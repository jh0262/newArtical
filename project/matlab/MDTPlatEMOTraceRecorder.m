classdef MDTPlatEMOTraceRecorder < handle
    %MDTPLATEMOTRACERECORDER Capture public baseline checkpoint diagnostics.

    properties (SetAccess = private)
        rows (:,2) double = zeros(0, 2)
    end

    methods
        function capture(obj, algorithmState, problemState)
            populations = algorithmState.result;
            occupied = find(~cellfun(@isempty, populations(:, 2)), 1, 'last');
            if isempty(occupied)
                return;
            end
            population = populations{occupied, 2};
            constraints = population.cons;
            feasibleRate = mean(all(constraints <= 0, 2));
            obj.rows(end+1, :) = [problemState.FE, feasibleRate];
        end
    end
end
