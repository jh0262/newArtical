function role = resolveH13FormalRole(audit, isFormal)
%RESOLVEH13FORMALROLE Record and validate the H13 performance-run role.

arguments
    audit (1,1) struct
    isFormal (1,1) logical
end

if isfield(audit, 'formalPerformanceRun') && ...
        logical(audit.formalPerformanceRun) ~= isFormal
    error('mdt:H13FormalRoleMismatch', ...
        ['Algorithm audit role conflicts with the H13 batch mode; ' ...
        'refusing to relabel the run.']);
end
role = isFormal;
end
