function decision = evaluateH14ExecutionGuard(state, limits)
%EVALUATEH14EXECUTIONGUARD Apply the approved H14 stop boundaries.

arguments
    state (1,1) struct
    limits (1,1) struct
end
requiredState = ["elapsedWallSeconds", "outputBytes", "freeBytes", ...
    "minutesSinceProgress", "consecutiveFailedRuns", ...
    "attemptedRuns", "failedRuns", "protocolViolation"];
requiredLimits = ["hardWallSeconds", "hardOutputBytes", ...
    "minimumFreeBytes", "stallMinutes", ...
    "maxConsecutiveFailures", "maxFailureFraction"];
requireFields(state, requiredState, 'mdt:H14InvalidGuardState');
requireFields(limits, requiredLimits, 'mdt:H14InvalidGuardLimits');

decision = struct('stop', false, 'reasonId', "CONTINUE", ...
    'message', "Approved execution envelope remains satisfied.");
if logical(state.protocolViolation)
    decision = stopDecision("STOP-H14-PROTOCOL", ...
        "A frozen scientific or artifact-integrity contract failed.");
elseif state.elapsedWallSeconds > limits.hardWallSeconds
    decision = stopDecision("STOP-H14-TIME", ...
        "The approved hard wall-time limit was exceeded.");
elseif state.outputBytes > limits.hardOutputBytes || ...
        state.freeBytes < limits.minimumFreeBytes
    decision = stopDecision("STOP-H14-STORAGE", ...
        "The approved output or free-space limit was crossed.");
elseif state.minutesSinceProgress > limits.stallMinutes
    decision = stopDecision("STOP-H14-STALL", ...
        "No progress was observed inside the approved stall window.");
elseif state.consecutiveFailedRuns >= limits.maxConsecutiveFailures
    decision = stopDecision("STOP-H14-FAILURE", ...
        "The consecutive-failure limit was reached.");
elseif state.attemptedRuns > 0 && ...
        state.failedRuns/state.attemptedRuns > limits.maxFailureFraction
    decision = stopDecision("STOP-H14-FAILURE", ...
        "The cumulative failure-fraction limit was exceeded.");
end
end

function requireFields(value, names, identifier)
if ~all(isfield(value, cellstr(names)))
    error(identifier, 'Required H14 execution-guard fields are missing.');
end
end

function decision = stopDecision(reasonId, message)
decision = struct('stop', true, 'reasonId', reasonId, ...
    'message', message);
end
