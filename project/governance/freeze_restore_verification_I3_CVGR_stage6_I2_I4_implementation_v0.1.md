# I3-CVGR Stage6 contract-green implementation freeze restore verification v0.1

Status: `STRUCTURAL PASS / 46 CONTRACT TESTS GREEN / ZERO OPTIMIZER RUN / ZERO FORMAL FFE`

## Authorization and identity

- authorization ID: `AUTH-I3-FREEZE-STAGE6-I1-I4-IMPLEMENTATION-20260831T161910+0800`
- accepted candidate SHA-256: `5D6C8F48845FE1C9BD1AB455708E8DEC80EF5BCE3E4E6C1F7128E64FE09BBBAF`
- authorization record SHA-256: `648EEF3C2051C3D04C4FEACE5D0D1D920B7BA5EF6198E45A31D643A667C22C68`
- snapshot source commit: `3d4c9d91359a5b0bb3a21ea43605839c3aca19c7`
- snapshot directory: `governance/frozen/I3_CVGR_stage6_I1_I4_implementation_v0.1_5D6C8F48_snapshot`
- snapshot manifest SHA-256: `6645DD1F7DFDFBFFAD62B7D526B813373A6E9957A427E20B08919C604D881492`
- snapshot ZIP SHA-256: `FAD1E2C42202253B3914CE945F76FBCF0B7DC20CECD997385F439B56F193BD58`
- snapshot ZIP bytes: `433781`
- canonical selected Git-index SHA-256: `EC262D9063D1BA6080DA976259BF937A61168791EE8AA0AE2CCFD1852AF203CA`

## Non-recursive dependency closure

The source commit was enumerated through `git ls-tree -r -l`. Every tracked path outside `governance/frozen/**` was archived from Git object content. Historical immutable snapshots were deliberately excluded from recursive copying and remain separately bound by their three accepted ZIP hashes.

- manifest-bound files: 170;
- manifest-bound bytes: 1,394,530;
- files including `FREEZE_MANIFEST.json`: 171;
- manifest-versus-snapshot missing files: 0;
- manifest-versus-snapshot extra files: 0;
- snapshot hash mismatches: 0;
- snapshot byte-length mismatches: 0.

## Independent empty-directory restoration

A new, unique directory under the operating-system temporary root was created and confirmed empty before extraction. The snapshot ZIP was expanded there, checked against `FREEZE_MANIFEST.json`, used for the authorized tests, checked again for unexpected generated files, and removed only after every check passed.

- restored files: 171;
- restored missing files: 0;
- restored extra files before tests: 0;
- restored SHA-256 mismatches: 0;
- restored byte-length mismatches: 0;
- restored candidate SHA-256 matched: yes;
- restored authorization SHA-256 matched: yes;
- extra files after tests/import checks: 0;
- temporary restore cleanup: success.

## Restored contract checks

Command executed from the restored root:

```text
python -B -m pytest -p no:cacheprovider -q
```

Observed result:

```text
46 passed in 0.20s
```

Direct pytest exit code: `0`.

The second restored-root check parsed every `src/alg1_replan/*.py` file through Python AST, inserted only the restored `src` directory into that single process, and imported all eight implementation modules. Result: `AST_FILES=9`, `IMPORT_CHECK=PASS`, direct exit code `0`. No package installation or environment change occurred.

## Execution accounting and evidence boundary

- optimizer runs: 0;
- benchmark or simulation runs: 0;
- objective or constraint evaluations: 0;
- formal run packages: 0;
- formal FFE: 0;
- dependency installations: 0;
- network or remote Git operations: 0.

Verdict: `STRUCTURAL_PASS_CONTRACT_GREEN_RESTORED`.

This verification proves that the frozen S6-I1 through S6-I4 source/evidence package restores exactly and reproduces its 46 deterministic unit-contract passes in the recorded environment. It does not prove that a complete optimizer or benchmark adapter exists, nor does it establish performance, superiority, convergence, robustness, novelty, physical validity or paper readiness. S6-E0 remains separately unauthorized.
