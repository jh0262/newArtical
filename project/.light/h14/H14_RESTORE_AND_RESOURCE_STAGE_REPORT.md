# H14 independent restore and resource-budget stage

Date: 2026-08-31  
Decision: **RESTORE PASS / FORMAL EXECUTION STILL BLOCKED**

## Independent release restoration

The `H14-Analysis-v0.2.0-rc1` archive was extracted into a newly created empty directory. The package manifest contains 151 files excluding the manifest itself; all 151 restored files matched both the recorded byte count and SHA-256 value.

- Restored H14 tests: **26 passed, 0 failed, 0 incomplete**.
- Formal-mode hard-block test: PASS.
- Restored JUnit SHA-256: `ae8e1dc16154c5fdab1484a6dbfc0562299843bdfe76fbf2d390bead8c5dc75e`.
- Formal H14 performance runs executed: **0**.

The first two MATLAB startup attempts failed before test discovery with `System Error: File system inconsistency`. Boundary testing showed that the sandbox prevented access to MATLAB license, preference, or temporary state: the same startup command succeeded outside that restriction. A separate verification-script error then pointed to the wrong root because MATLAB `run(...)` changed the execution directory; only the external verification script was corrected. The archive and frozen source were not changed.

## Restored preflight

Two independent preflight batches were executed from the restored source, each using the frozen preflight mode (`N=20`, `100 NFE`) rather than the formal design.

| Check | Result |
|---|---:|
| Batch A | 42/42 completed, 0 failed |
| Batch B | 42/42 completed, 0 failed |
| Declared artifact hash failures | 0 |
| Same-seed raw-metric/prediction comparisons | 42/42 exact |
| Batch A resume | 42/42 reused, no overwrite |
| `formalPerformanceRun` | false for all rows |
| Process wall time | 17.182 s and 16.760 s |
| Resume process wall time | 10.968 s |
| Output size | 11,348,172 and 11,348,174 bytes |

These results support source completeness, resume integrity and same-environment reproducibility only. They do not support algorithm ranking.

## Proposed formal resource envelope

The 6720-run matrix contains 67.2 million total NFE. Directly scaling restored preflight storage by the 160-fold run-count multiplier gives 1.691 GiB. Population and trace growth raise the planning expectation to 2–3 GiB; the proposed hard output limit is 5 GiB, with at least 10 GiB free before start.

The local H13 formal batch is retained only as a timing anchor: 450 runs at 20,000 NFE required 646.007 s, but it used different benchmark functions and artifacts. Combining that anchor with the restored H14 preflight gives a deliberately broad 1.5–6 h expected envelope and a 12 h hard wall-time stop.

Required formal monitoring stops are frozen in `h14_formal_resource_budget_v0_1.json`: no progress for 30 min, three consecutive failures or cumulative failures above 0.5%, source/protocol violation, output above 5 GiB, low disk space, or elapsed time above 12 h.

## Remaining authorization gates

1. The author must review and approve the resource/cancellation budget.
2. A separate `h14_formal_authorization.json` must bind the approved RC archive, matrix, analysis code and budget hashes.
3. `makeH14Design().formalPerformanceAuthorized` must remain false until that authorization is created and a new formal-execution freeze is verified.
4. No result analysis or paper claim may begin until all 6720 rows are complete and pass the frozen coverage and integrity checks.
