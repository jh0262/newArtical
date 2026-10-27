# I3 mechanism-integrity amendment decision candidate v0.1 — verification

Verified on 2026-08-31 without running an optimizer, benchmark, objective, constraint or evaluator.

## Bound artifacts

| Path | Bytes | SHA-256 |
|---|---:|---|
| `governance/s6_i1_i4_mathematical_contract_gap_audit_I3_CVGR_v0.1.json` | 16275 | `674F1CEBA11FE2693B96B4BE88B30397B38EA4455AA162B52C108351CF93B6E4` |
| `governance/s6_i1_i4_mathematical_contract_gap_audit_I3_CVGR_v0.1.md` | 4891 | `27649FB40695A86150C2A8F193FC7E6B0C245E9BBFF85B3BCAD6E2C70A9BB311` |
| `governance/mechanism_integrity_amendment_decision_candidate_I3_CVGR_v0.1.json` | 9828 | `0F7872BB7375A7DCE0016A915328698BC719FEB5A660910D53C441576CE20457` |

## Static evidence

- Frozen manifest SHA-256: `6645DD1F7DFDFBFFAD62B7D526B813373A6E9957A427E20B08919C604D881492`.
- Live production-source hash comparison: `9/9 matched`.
- Live test-file hash comparison: `11/11 matched`.
- `pytest --collect-only -q`: `46 tests collected`, exit code 0, tests executed 0.
- Evaluator-free pure-function probes reproduced the full-W Jaccard, fixed-node NMI, eligible-pool quantile, stable-ID, inactive-only target and rewire-identity counterexamples.
- The rejected-trial probe exercised only validation over a supplied pre-evaluated record and raised the recorded zero-improvement error.
- `light-experiment-coding review_gate`: 9 source files, 0 static anti-pattern findings, verdict pass. This pass does not cover the mathematical findings in the audit.
- Both new JSON files parsed successfully and `git diff --check` returned no whitespace errors before staging.
- `light-memory-pm` audit returned WARN with error=0; its only finding is the pre-existing Stage 2 `PLANNED` placeholder without checkpoint hash/timestamp.

## Scope boundary

The candidate is `PROPOSED_NOT_AUTHORIZED`. It does not alter or invalidate the historical frozen bytes; it records why that package cannot yet be treated as mathematically execution-ready. No source or test file was changed, no dependency was installed, and formal optimizer runs, evaluator calls, run packages and FFE remain zero.
