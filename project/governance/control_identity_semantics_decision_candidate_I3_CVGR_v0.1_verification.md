# I3-CVGR control identity and semantics decision candidate v0.1 verification

Status: `READY_FOR_AUTHOR_DECISION / NOT AUTHORIZED / ZERO FORMAL FFE`

## Bound identities

- Candidate: `governance/control_identity_semantics_decision_candidate_I3_CVGR_v0.1.json`
- Candidate SHA-256: `ACFC5953C4E30061D023F8F8F69BB0B5135B338F974350D3A05F07BA5A695FFB`
- Candidate bytes: `10173`
- Bound audit: `governance/control_identity_semantics_audit_I3_CVGR_v0.1.json`
- Bound audit SHA-256: `B0448FCA07A71AC6A58DF98EEB1BFF9C58A4A106196E35C22C23990E24010B4C`
- Bound live commit before candidate preparation: `7a41adc8062fe49bf683a6cd17120c5afdc687a9`

## Static verification

1. Both JSON files parse successfully: `2/2 PASS`.
2. The candidate-bound audit hash and byte count match the live audit: `PASS`.
3. Original plan, M/H amendment, NV amendment and consolidated preparation-authority hashes match the live files: `4/4 PASS`.
4. The evidence inventory binds eight live artifacts with explicit locators and does not edit any of them: `8/8 PASS`.
5. The semantic audit distinguishes component-ID renaming from node-to-community membership shuffling and does not register either as canonical: `PASS`.
6. All four author options remain explicit; only the canonical-successor option is marked recommended: `PASS`.
7. The recommended option preserves historical `LABEL_PERM`, proposes future `RANDOM_LABEL`, and keeps BM-R1 independent: `PASS`.
8. Static resource arithmetic was recomputed from the frozen internal dimension sums (`M sum(D)=126`, `C1 sum(D)=159`): `PASS`.
9. Recommended envelope: `5,760` core packages / `325,380,000` maximum core FFE; distinct M-only envelope: `6,120` / `332,940,000`; distinct M+C1 envelope: `6,600` / `380,640,000`: `PASS`.
10. Expected-red tests executed: `0`; green tests executed: `0`; optimizer/evaluator calls: `0`; formal run packages: `0`; formal FFE: `0`.

## Interpretation boundary

The candidate proposes an author decision; it does not make one. The recommendation treats `RANDOM_LABEL` as an operationally clarified successor rather than a silent alias because a pure component-ID rename is permutation-equivariant and may be a behavioral no-op. This is a mathematical/static design judgment, not performance evidence and not proof that a future control implementation is correct.

If the author confirms the candidate hash and requested decisions, only a versioned amendment, semantic fixtures, additive expected-red/static source and a later separate freeze candidate may be prepared. Expected-red execution, production/analysis implementation, BM-R1 selection by inference, dependency installation, SA, S6-E0, optimizer/evaluator execution and formal FFE remain prohibited.

## Verdict

`READY_FOR_EXACT_HASH_BOUND_AUTHOR_DECISION`
