# Verification — I3-CVGR frozen-plan consistency decision candidate v0.1

Status: `VERIFIED_CANDIDATE_NOT_AUTHORIZED / S6_E0_RED_PHASE_ON_HOLD`

- decision candidate: `governance/frozen_plan_consistency_decision_candidate_I3_CVGR_v0.1.json`
- candidate SHA-256: `8B1539AC32286673B5809772AB4AAF93C8242E1D819BAC414217134BE2D88EC6`
- candidate JSON parse: pass
- critical findings: `governance/frozen_plan_consistency_findings_I3_CVGR_v0.1.json`
- critical findings SHA-256: `A8AEA7A9A2CF29C9721F5E9F8BB30D4EA40DFCCD8324B98429FE41485A510AEC`
- fact bindings: `governance/s6_e0_frozen_plan_fact_bindings_v0.1.json`
- fact bindings SHA-256: `2F42AAECFDE45EDE16EFF01B85EC5C1373D3FAB98F27D9F0ED3799E96407D8BA`
- `fact_consistency.py` status: `FAIL`, direct exit `1`
- exact fact mismatches: `2`
- general five-material consistency scan: `.light/consistency_findings_S6_E0_pre_red_v0.1.json`
- general scan SHA-256: `198E1E15734BFEB4A44B7412D9BB8FE27BA6181028D7F93F17C174AA1F4D9EEA`
- general scan: `WARN`, seven findings; its registry lacked budget/H1 canonical objects, so the exact fact-binding gate supplied the blocking comparison
- frozen-plan archive SHA-256: `6AC43CB831B5965CC5EB408E45C6D790859A74A6E10DFBB1091C13E9DC5E8F45`
- frozen files edited: `0`
- S6-E0 specifications/tests/modules created: `0`
- optimizer/evaluator executions: `0`
- formal run packages: `0`
- formal FFE: `0`

## Conflict 1 — mechanism-stage budget

`PROJECT_PLAN.md`, `preregistration_candidate_v0.1.md` and the failure tree specify `2,000D`; `synthetic_problem_suite_spec_v0.1.md` specifies `10,000D`.

For the fixed 12-task family, `sum(D)=126`, seven variants and 30 seeds:

- `2,000D` gives M = `52,920,000 FFE` and M+C1+F = `270,120,000 FFE`;
- `10,000D` gives M = `264,600,000 FFE` and M+C1+F = `481,800,000 FFE`;
- difference = `211,680,000 FFE`.

The recommended author choice is `2,000D` because it reproduces the already frozen aggregate totals. This is a recommendation, not an automatic resolution.

## Conflict 2 — primary H1 endpoint

`PROJECT_PLAN.md`, the preregistration, experiment matrix and failure tree specify NMI at fixed `25/50/75/100%` checkpoints followed by a problem-level median. The synthetic-suite specification instead requires first-valid-activation NMI and a time-weighted median over later valid graphs. These definitions can return different H1 values and different success/failure branches from identical runs.

The recommended author choice is the fixed-checkpoint median definition because it is repeated in four governing artifacts and is tied directly to the frozen H1 thresholds. This is a recommendation, not an automatic resolution.

## Routing consequence

The earlier S6-E0 red-phase candidate `B344AA5BE00A0E12C6596FF477AC5E29740F9392D15237C3CAC969572906F649` is now held in sequence and must not be accepted or executed as the current gate. It remains immutable provenance. After the author selects both facts, only a versioned additive amendment candidate may be prepared; the S6-E0 red-phase candidate must then be regenerated against the separately frozen amendment.

## Suggested author decision

```text
我确认I3冻结方案一致性裁决候选v0.1，SHA-256为8B1539AC32286673B5809772AB4AAF93C8242E1D819BAC414217134BE2D88EC6；B=SELECT_M_2000D；H=SELECT_H1_FIXED_CHECKPOINT_MEDIAN；A=AUTHORIZE_VERSIONED_PLAN_AMENDMENT_PREPARATION_ONLY；R=HOLD_S6_E0_RED_PHASE_UNTIL_AMENDMENT_FROZEN；G=AUTHORIZE_LOCAL_GIT_COMMITS_NO_REMOTE；E=DO_NOT_AUTHORIZE_OPTIMIZER_OR_EVALUATOR_EXECUTION；F=KEEP_FORMAL_FFE_ZERO
```

The candidate does not authorize itself. Until an exact hash-bound choice is received, neither the plan amendment nor S6-E0 red artifacts may be created.
