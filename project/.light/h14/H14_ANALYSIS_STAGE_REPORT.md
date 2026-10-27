# H14 analysis-development stage report

Date: 2026-08-31  
Stage status: **COMPLETED WITH FORMAL EXECUTION BLOCKED**

## 1. Scope completed

This stage converted the H14 proposal into a hash-bound, testable analysis path without launching the 6720-run formal experiment.

1. H1-H3 remain the confirmatory family. Their independent unit is the landscape (`n = 16`), after averaging the 10 paired algorithm seeds and `L = {1,4}` within each landscape.
2. The preregistered primary method uses 20,000 fixed-seed landscape bootstrap resamples, an exact one-sided `2^16` sign-flip test of `effect - 0.01`, and Holm FWER control over H1-H3.
3. H4 is frozen as a secondary Q=2 harm-detection boundary. It is outside the Holm family and cannot support an equivalence or superiority claim.
4. H1/H2 include the terminal normalized feasible-HV guardrail.
5. The result-analysis implementation rejects incomplete or duplicated formal coverage, preflight rows, truth leakage, incomplete NFE, and non-finite metrics.

## 2. Implementation and verification evidence

- New analysis functions: `computeH14Statistics.m`, `runH14ResultAnalysis.m`, and `h14FormalPerformanceFlag.m`.
- Controlled-batch output now records `truthUsedByAlgorithm` and `formalPerformanceRun`.
- TDD evidence records the expected red failures before implementation and the subsequent green suite.
- H14 combined tests: **26/26 PASS**.
- Full MATLAB regression: **172/172 PASS**.
- MATLAB Code Analyzer: **140 files, 0 messages**.
- Current-source preflight: two independent batches, each **42/42 complete**, with **42/42 valid manifests**, **42/42 same-seed exact pairs**, and **42/42 resume verification**.
- Formal performance runs executed in this stage: **0**.

## 3. Gate interpretation

- Failure-tree gate: PASS.
- Target-chain gate: PASS.
- Research-plan gate: PASS.
- Research-package gate: WARN only because the heuristic linter counts the H4 confidence-interval boundary as a fourth multiplicity test. The frozen protocol does not test H4; the actual confirmatory family is H1-H3 (`K = 3`).
- Execution-contract gate: ALLOW_WITH_LIMITATIONS for preflight only. Resource telemetry, cache evidence, and higher reproducibility levels remain unresolved.

## 4. Evidence boundary

The freeze candidate is a review candidate, not an authoritative release. Synthetic validation establishes implementation behavior only; it does not establish H1-H4 scientific results, algorithm superiority, equivalence, or engineering validity.

Formal execution remains hard-blocked because:

1. the candidate has not been restored and verified from an independent empty directory;
2. formal authorization is absent and the formal design flag remains false;
3. compute, storage, elapsed-time, cancellation, and output-retention limits are not yet author-approved.

## 5. Recommended next stage

Create a self-contained H14 analysis release candidate, restore it into an empty directory, rerun the frozen tests and a non-claim preflight there, and produce a resource/cancellation budget for the 6720 formal runs. Only after those checks and explicit author authorization may formal execution begin.
