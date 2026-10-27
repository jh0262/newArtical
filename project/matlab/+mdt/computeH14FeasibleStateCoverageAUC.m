function [value, audit] = computeH14FeasibleStateCoverageAUC(result, oracle)
%COMPUTEH14FEASIBLESTATECOVERAGEAUC Compute the H14 primary endpoint.

if ~isstruct(result) || ~isfield(result, 'trace') || ...
        ~isfield(result, 'traceColumns') || ~isfield(result, 'audit')
    error('mdt:H14InvalidResult', 'A complete black-box result is required.');
end
if ~isstruct(oracle) || ~isfield(oracle, 'allowedStateCount') || ...
        ~isfield(oracle, 'truthRole') || ...
        string(oracle.truthRole) ~= "metrics_and_preflight_only"
    error('mdt:H14InvalidOracle', 'A metrics-only H14 oracle is required.');
end
if result.audit.truthUsed || result.audit.truthUsedBySelection || ...
        result.audit.truthUsedByGeneration
    error('mdt:H14TruthFirewallViolation', ...
        'Algorithm-side truth use invalidates the H14 primary endpoint.');
end
columns = string(result.traceColumns);
nfeColumn = find(columns == "nfe", 1);
newStateColumn = find(columns == "newFeasibleDiscreteStates", 1);
if isempty(nfeColumn) || isempty(newStateColumn)
    error('mdt:H14TraceContractMissing', ...
        'Trace must contain nfe and newFeasibleDiscreteStates.');
end
nfe = result.trace(:, nfeColumn);
newStates = result.trace(:, newStateColumn);
if any(diff(nfe) <= 0) || any(newStates < 0) || ...
        any(newStates ~= floor(newStates))
    error('mdt:H14InvalidCoverageTrace', ...
        'NFE must increase and newly feasible state counts be nonnegative integers.');
end
coverage = min(cumsum(newStates)/oracle.allowedStateCount, 1);
budget = nfe(end);
value = trapz([0; nfe]/budget, [0; coverage]);

audit = struct();
audit.schema = "mdt.h14-fsca-auc-audit.v1.0";
audit.nfe = nfe;
audit.coverage = coverage;
audit.allowedStateCount = oracle.allowedStateCount;
audit.finalCoverage = coverage(end);
audit.truthUsedByAlgorithm = false;
audit.truthUsedByMetrics = true;
audit.integration = "trapezoidal_with_origin";
end
