classdef MDTPlatEMOPublicProblem < PROBLEM
%MDTPLATEMOPUBLICPROBLEM Typed public benchmark bridge for PlatEMO v4.15.

    properties(SetAccess = protected)
        evaluator
        variableSpec
        declaredEncoding
        declaredObjectiveCount
        declaredIdealPoint
        declaredNadirPoint
    end

    methods
        function obj = MDTPlatEMOPublicProblem(varargin)
            obj@PROBLEM(varargin{:});
        end

        function Setting(obj)
            [evaluatorValue, specValue, encodingValue, objectiveCountValue, ...
                idealValue, nadirValue] = obj.ParameterSet( ...
                [], struct(), [], 2, [], []);
            if ~isa(evaluatorValue, 'function_handle') || ...
                    ~isstruct(specValue) || isempty(encodingValue) || ...
                    ~isscalar(objectiveCountValue) || objectiveCountValue < 2
                error('mdt:InvalidPlatEMOProblemConfiguration', ...
                    'The PlatEMO bridge requires evaluator, variable spec, encoding, and objective count.');
            end
            obj.evaluator = evaluatorValue;
            obj.variableSpec = specValue;
            obj.declaredEncoding = reshape(encodingValue, 1, []);
            obj.declaredObjectiveCount = objectiveCountValue;
            obj.declaredIdealPoint = reshape(idealValue, 1, []);
            obj.declaredNadirPoint = reshape(nadirValue, 1, []);

            obj.M = objectiveCountValue;
            obj.D = numel(specValue.continuousLower) + ...
                numel(specValue.discreteCardinalities);
            if numel(obj.declaredEncoding) ~= obj.D
                error('mdt:InvalidPlatEMOProblemConfiguration', ...
                    'The PlatEMO encoding vector must match the decision dimension.');
            end
            obj.encoding = obj.declaredEncoding;
            obj.lower = [reshape(specValue.continuousLower, 1, []), ...
                zeros(1, numel(specValue.discreteCardinalities))];
            obj.upper = [reshape(specValue.continuousUpper, 1, []), ...
                reshape(specValue.discreteCardinalities, 1, [])-1];
        end

        function Population = Evaluation(obj, varargin)
            PopDec = obj.CalDec(varargin{1});
            [PopObj, PopCon] = obj.evaluator(PopDec);
            if size(PopObj, 2) ~= obj.declaredObjectiveCount || ...
                    size(PopCon, 2) ~= numel(obj.variableSpec.constraintScales) || ...
                    any(~isfinite(PopObj), 'all') || any(~isfinite(PopCon), 'all')
                error('mdt:InvalidPlatEMOPublicEvaluation', ...
                    'The public evaluator returned invalid objective or constraint data.');
            end
            Population = SOLUTION(PopDec, PopObj, PopCon, varargin{2:end});
            obj.FE = obj.FE+length(Population);
        end

        function R = GetOptimum(obj, ~)
            if isempty(obj.declaredNadirPoint)
                R = ones(1, obj.M);
            else
                R = obj.declaredNadirPoint;
            end
        end

        function R = GetPF(~)
            R = [];
        end
    end
end

