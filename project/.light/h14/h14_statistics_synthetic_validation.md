# H14 statistics synthetic validation

Date: 2026-08-31 (Asia/Shanghai)

## Scope

This is deterministic synthetic-fixture validation of analysis logic. It is not H14 algorithm-performance evidence.

## Verified contracts

- Complete 6720-run identity and uniqueness are required.
- Only completed, 10,000-NFE, truth-safe runs with `formalPerformanceRun=true` are accepted.
- The independent unit is the landscape; ten algorithm seeds and L={1,4} are aggregated within landscape.
- H1-H3 use the arithmetic mean landscape effect, landscape bootstrap CI, exact one-sided sign flip of `effect-0.01`, and Holm FWER correction.
- H1/H2 enforce the -0.005 feasible-HV guardrail.
- H4 reaches separate success, failure and inconclusive branches and always sets `equivalenceClaimAllowed=false`.
- A fixed bootstrap seed reproduces identical confidence intervals.
- Missing, duplicate, NaN, preflight or truth-leaking inputs are rejected.
- The one-command analysis entry writes hash-bound JSON/CSV/manifest artifacts and refuses overwrite.

## Result

- `tests/test_mdt_h14_statistics.m`: 8/8 passed.
- H14 combined suite: 26/26 passed.
- Full project regression: 172/172 passed.
- MATLAB Code Analyzer: 140 files, 0 messages.
