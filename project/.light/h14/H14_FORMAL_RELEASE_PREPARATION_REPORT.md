# H14 formal-release preparation after budget approval

Date: 2026-08-31  
Decision: **BUDGET APPROVED / RELEASE PREPARED / EXECUTION NOT STARTED**

## Approval interpretation

The user message `批准` approves `h14_formal_resource_budget_v0_1.json` and authorizes preparation, testing, packaging and independent restoration of a formal-execution release candidate. It does not authorize starting the 6720-run batch. This boundary is machine-readable in `h14_budget_approval.json` and `h14_formal_authorization.json`.

## Implemented gates

1. `validateH14FormalAuthorization` verifies project-relative paths and SHA-256 values for the approved budget, matrix, RC1 archive, design, runner, analysis code and guard code.
2. The prepared authorization has status `BUDGET_APPROVED_FORMAL_PREPARED` and `execution_start_authorized=false`.
3. `runH14ControlledBatch(...,"formal")` raises `mdt:H14FormalStartNotAuthorized` before creating an output directory.
4. `evaluateH14ExecutionGuard` implements the approved time, storage, free-space, stall, consecutive-failure, cumulative-failure and protocol-stop decisions as a pure tested contract.
5. The scientific design is unchanged: 6720 rows, fixed seeds, N=100, 10,000 NFE, H1-H3 primary family, H4 secondary harm boundary and the frozen analysis code.

## Verification

- Authorization/guard targeted tests: 17/17 passed.
- H14 tests: 30/30 passed.
- Full regression: 176/176 passed.
- Code Analyzer: 142 files, 0 messages.
- Formal performance runs executed after approval: 0.

## Remaining start gate

A later explicit instruction to start the formal experiment is required. At that time a new authorization status `AUTHORIZED_FORMAL_START` with `execution_start_authorized=true` must bind the independently restored RC2 archive. The actual launch must use an external watchdog for the 30-minute no-progress rule; the MATLAB guard contract covers the same decision boundary but cannot reliably interrupt a MATLAB call while that call is blocked inside a single solver run.
