# I3-CVGR additive TDD v0.2 independent restore verification

- verification time: `2026-08-31T06:54:59.3908469+08:00`
- accepted candidate SHA-256: `345AFBA8F403A6240977DE2B2EB8B11E09FDF7B29C4C5B54CFA4A19B9CFF5988`
- snapshot manifest SHA-256: `68687981517461111996122B86A2257600DF6F5C5CB6859EF035E5053280139A`
- snapshot archive SHA-256: `CBFBC21E2CD664B870D81C826858853372A2918BFD8137FB4EBE941EF986C98F`
- archive bytes: `107144`

## Empty-directory restore

The archive was extracted into a newly created empty directory under the operating-system temporary directory. The restored root contained 54 files: the manifest plus all 53 manifest-bound files. Every restored path, byte count and SHA-256 matched; no file was missing or extra. The temporary restore directory was removed after verification.

The restored package contains the complete v0.1 plan/test dependency closure, the five-file additive TDD v0.2 amendment, the accepted candidate and supporting authorization provenance. `src/alg1_replan` remained absent.

## Restored red-state check

The six frozen/additive test files were invoked with bytecode and pytest cache writing disabled:

```text
python -m pytest -p no:cacheprovider -q tests\test_graph_contract.py tests\test_donor_contract.py tests\test_fallback_rng_contract.py tests\test_ffe_contract.py tests\test_activation_fallback_contract_v0_2.py tests\test_exact_fallback_contract_v0_2.py
```

Observed result:

- six collection errors;
- all six root causes were `ModuleNotFoundError: No module named 'alg1_replan'`;
- no test passed unexpectedly;
- direct pytest process exit code: `2`;
- formal optimizer runs: `0`;
- objective or constraint evaluations: `0`;
- formal FFE: `0`.

## Recorded discrepancy

The frozen candidate and its red receipt record exit code `1`, while both the independent restored invocation and an exact direct invocation in the live project returned pytest process exit code `2` under Python 3.14.7 / pytest 9.1.1. The collection-error count, error class, missing module and red-state semantics matched exactly.

This is retained as a provenance-metadata discrepancy and is not silently rewritten because the author froze the candidate by hash. It does not change the intended red contract or authorize implementation. The restoration verdict is therefore `STRUCTURAL_PASS / EXPECTED_RED_SEMANTICS_MATCH / PROVENANCE_WARN_EXIT_CODE` rather than an unqualified pass.

## Evidence boundary

This verification establishes archive restorability and the expected unmet-test state only. It is not evidence of implementation correctness, algorithm performance, novelty, superiority, convergence, robustness, physical validation or paper readiness. Production implementation, green-phase tests, optimizer execution, public release and submission remain unauthorized.
