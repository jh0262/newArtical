# I3-CVGR Stage6 I2-I4 red baseline v0.1 independent restore verification

Status: `STRUCTURAL_PASS / CORE_GREEN / EXPECTED_RED / ZERO FORMAL FFE`

- verification time: `2026-08-31T14:42:55.0264014+08:00`
- authorization ID: `AUTH-I3-FREEZE-STAGE6-I2-I4-RED-20260831T144255+0800`
- accepted candidate SHA-256: `0144EE7F892CB3957532D32A432A0F81C2352E599F35A66861680090B07D6921`
- snapshot source commit: `5430a09064c4e764711bdfb9931c4d8ffe45af46`
- snapshot manifest SHA-256: `7FF2C2BA2C9B7F218FD2E9AF3F2AD647BF578974A39415D34ABEE0366881B6A8`
- snapshot archive SHA-256: `981B210CFF1E967CBD8C78E5132105551DBC2747B7533C865F4881DD9F469878`
- snapshot archive bytes: `739545`

## Empty-directory restore

The archive was extracted into a newly created empty directory under the operating-system temporary directory. The manifest bound 246 files. All 246 restored paths, byte counts and SHA-256 values matched. The only additional file was `FREEZE_MANIFEST.json`, as designed; there were no missing or unexpected files before or after test execution. The temporary restore directory was removed after verification.

The snapshot is a complete local-Git dependency closure at the recorded source commit. It contains the accepted red candidate, its 11 bound artifacts, the S6-I1 production core and evidence, the earlier frozen baselines, project governance and all tracked test/configuration dependencies. It contains no S6-I2, S6-I3 or S6-I4 production module.

## Restored contract checks

The six frozen S6-I1 files were invoked with bytecode and pytest cache writing disabled:

```text
python -B -m pytest -p no:cacheprovider -q tests/test_graph_contract.py tests/test_donor_contract.py tests/test_fallback_rng_contract.py tests/test_ffe_contract.py tests/test_activation_fallback_contract_v0_2.py tests/test_exact_fallback_contract_v0_2.py
```

Observed result: `29 passed in 0.18s`; direct pytest process exit code `0`.

The four newly frozen I2-I4 red-contract files were then invoked:

```text
python -B -m pytest -p no:cacheprovider -q tests/test_violation_selection_contract_v0_1.py tests/test_parent_shade_kernel_contract_v0_1.py tests/test_online_cvgr_state_contract_v0_1.py tests/test_experiment_dry_run_contract_v0_1.py
```

Observed result: four collection errors in `0.16s`; direct pytest process exit code `2`. The four root causes were exactly the deliberately absent modules:

- `alg1_replan.selection`;
- `alg1_replan.shade_kernel`;
- `alg1_replan.online_state`;
- `alg1_replan.experiment_contracts`.

There were no unexpected passes and no unrelated collection failures.

## Execution and evidence boundary

- optimizer runs: 0;
- benchmark or simulation runs: 0;
- objective or constraint evaluations: 0;
- formal FFE: 0;
- network downloads or dependency installations: 0.

This verification proves structural restorability, unchanged S6-I1 contract behavior and the intended unmet I2-I4 production-API state. It does not prove a future implementation, optimizer performance, novelty, superiority, convergence, robustness, physical validity or paper readiness.
