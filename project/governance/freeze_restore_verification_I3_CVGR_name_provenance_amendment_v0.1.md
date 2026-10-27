# I3 name/provenance amendment v0.1 freeze/restore verification

Verification status: `PASS`

## Bound authorization and prerequisites

- Candidate SHA-256: `FD54D6E7A8A850B4CA7BF03FFF6F2DA551F59FB39164A32EEA62E32370409ACD`
- Authorization: `governance/freeze_authorization_I3_CVGR_name_provenance_amendment_v0.1.json`
- Authorization SHA-256: `77CDAF642229F4C0A5D7C45987DAC37C1AC5844A5E6A007097822A4B791E8C4A`
- Ordered PA prerequisite SHA-256: `E117680193FDB35962E62D346C23DC2388AD3F1A71B7369FD6D485F88E11EE6B`
- Ordered MI prerequisite SHA-256: `8B36F8386B20116E5A7AC632179DD323D3DDB72BFFF600EB51F66996ABBA45FA`
- Scope: NS immutable freeze, new-empty-directory restore and static verification only; runtime authority remains non-operative.

## Frozen package

- Snapshot: `governance/frozen/I3_CVGR_name_provenance_amendment_v0.1_FD54D6E7_snapshot/`
- Snapshot file count: `9` (`8` payload files plus `FREEZE_MANIFEST.json`)
- Manifest SHA-256: `A125C5E203F7FA4B038DDD21240F51D447C0FA0CE9DC11EA2E3E373CBD727717`
- Manifest bytes: `3636`
- Archive: `governance/frozen/I3_CVGR_name_provenance_amendment_v0.1_FD54D6E7_snapshot.zip`
- Archive SHA-256: `62AE01BC701FDD7AE4FDBD77400AD6E9D52BC4C1B02651253A3D03B7B5BE6F76`
- Archive bytes: `13613`
- Deterministic regeneration: `PASS`; a separately generated sorted/fixed-timestamp ZIP produced the same SHA-256 and was removed.

## Empty-directory restoration

- A new directory under the operating-system temporary root was verified empty before extraction.
- Source files: `9`
- Restored files: `9`
- Missing paths: `0`
- Extra paths: `0`
- SHA-256 or byte-count mismatches: `0`
- Restore directory and temporary deterministic-check ZIP were removed after verification.

## Static checks only

- JSON parse: `5/5 PASS`
- YAML parse: `2/2 PASS` using the already-installed parser; no package installation or download occurred.
- Canonical English full name plus abbreviation: `5/5 PASS`
- Chinese name in the four designated localized artifacts: `4/4 PASS`
- Superseded machine expansion marked in the four amendment/lock artifacts: `4/4 PASS`
- Candidate-lock and runtime-authority non-operative checks: `11/11 PASS`
- Active `.light/terminology.md`, method lock and glossary preserved byte-identically: `3/3 PASS`
- Tests collected or executed: `0`
- Production or analysis files edited: `0`
- Optimizer/evaluator/benchmark/objective/constraint calls: `0`
- Formal FFE: `0`

The first local checker pass incorrectly required the Chinese name in the upstream English-only decision JSON and therefore reported `4/5` for that over-broad check. No frozen or source artifact was changed. The contract-aware rerun required the English name and abbreviation in all five identity-bearing artifacts and the Chinese name only in the four designated localized amendment/lock artifacts; all checks passed.

## Frozen effect and continuing holds

The canonical name is frozen as `Co-Violation Graph Recombination SHADE (CVGR-SHADE)` and the Chinese name as `共违反图重组 SHADE`. `Constraint-Violation Graph Representation SHADE` is frozen only as the superseded machine expansion.

The candidate consistency locks remain `PROPOSED_NOT_FROZEN_NOT_ACTIVE` within the historical candidate payload, and the runtime-authority manifest remains `PROPOSED_NOT_FROZEN_NOT_OPERATIVE`. This freeze does not edit or activate the current `.light` terminology, method-lock or glossary files. It also does not release S6-E0, change implementation, execute an optimizer/evaluator, establish objective novelty, or support performance, robustness or paper-readiness conclusions.

NV, BM, SA and final operative runtime authority remain outside this acceptance and on HOLD.
