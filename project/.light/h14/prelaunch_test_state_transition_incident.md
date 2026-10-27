# H14 prelaunch test state-transition incident

## Classification

- Type: test-harness state mismatch, not an H14 algorithm failure.
- Time: 2026-08-31, after changing the formal authorization from prepared to start-authorized.
- Approved output affected: no; `runs/H14_CONTROLLED/formal-rc2-a` remained absent.

## Cause

The frozen RC2 regression `test_mdt_h14_execution.m` contains pre-authorization assertions. It expects the project authorization to remain `BUDGET_APPROVED_FORMAL_PREPARED` and verifies that a temporary formal call is rejected. Re-running that test after the explicit start authorization made the temporary call executable.

## Containment

- Interrupted the MATLAB test process before launching the approved batch.
- Confirmed no MATLAB process remained.
- Verified the approved output directory was still absent.
- Deleted only the generated temporary output under the resolved system temporary directory; 12,421 files in 1,694 directories, approximately 74 MiB.

## Resolution

The immutable RC2 test was not edited. Its pre-authorization result remains part of RC2 evidence. Post-authorization readiness is verified by the independent authorization validator, binding-hash audit, watchdog self-test, output-path check and resource gate. This preserves the frozen release while preventing the prepared-state test from being misused after the state transition.

## Evidence boundary

The interrupted temporary calculation is not an H14 formal result and must not be analyzed, cited or merged into the approved output.
