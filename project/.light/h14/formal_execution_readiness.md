# H14 formal execution readiness

## Decision

**NOT_READY / FORMAL RUNS BLOCKED**

This decision applies to the 6720-run performance matrix only. The completed 42-run preflight is software evidence and must not be used for algorithm ranking or manuscript claims.

## Closed execution gates

- Formal matrix exported: 6720 runs, 2240 paired algorithm-seed units, 224 landscape units, 14 execution cells.
- Matrix SHA256: `f7159f89317cf02a018d67809d98b8a8d10fea1dc1af8a8145e68fa8f7175945`.
- H14 tests: 26/26 passed, including H4 success/failure/inconclusive and analysis artifact tests.
- Full MATLAB regression: 172/172 passed; JUnit SHA256 `6e372e99b5f4233a799f54247fb4db71b79d2b7604aa87496f784f2afcef964d`.
- MATLAB Code Analyzer: 140 files, 0 messages.
- Persistent preflight: two independent batches, each 42/42 completed, 0 failed.
- Artifact integrity: 42/42 manifests passed `run_artifact_check.py`.
- Same-environment repeat: 42/42 pairs were exact for `raw_metrics` and `predictions`.
- Resume: 42/42 completed attempts were reused without overwrite.
- Resume rejects a completed bundle when any declared artifact hash changes.
- The runner rejects formal mode before creating an output directory when authorization is absent.
- H4 is closed as a secondary Q=2 harm boundary with distinct success/failure/inconclusive branches and no equivalence claim.
- `computeH14Statistics` implements landscape aggregation, 20,000-replicate bootstrap, exact one-sided sign flip, Holm adjustment and HV guardrails.
- `runH14ResultAnalysis` provides a one-command, hash-bound analysis bundle and refuses overwrite.

## Formal blockers

1. The H14 v0.2 plan/analysis package is a hash-bound freeze candidate, not an independently restored authoritative release.
2. `.light/h14/h14_formal_authorization.json` does not exist and `makeH14Design().formalPerformanceAuthorized` remains false by design.
3. A formal compute/time/storage budget, cancellation rule and output location have not been approved.
4. An independent empty-directory restoration must reproduce the H14 tests and source hashes before formal authorization.

## Required next authorized stage

Package the v0.2 candidate, restore it into an independent empty directory, rerun the frozen H14 tests, review the 6720-run compute/storage budget and then request a separate hash-bound formal authorization. Only after that authorization may `mdt.runH14ControlledBatch(outputDir,"formal")` be enabled.
