# Problem structure governs solver choice in preliminary catalogue-constrained ball-screw multiobjective design

Code and reproducibility-resource snapshot prepared on 28 October 2026.

## Research status

Analytical catalogue screening and computational solver comparisons; no new physical validation is asserted.

## Restore and verify the saved resources

```bash
python restore_resources.py
```

This standard-library-only script verifies SHA-256 hashes and restores bundled files to their original relative paths under `project/`. It refuses to overwrite changed files. Download or clone this branch before running it; GitHub's file preview does not unpack the resource archives.

## Entry points and dependencies

Python: inspect 05_experiments/test_model.py and reanalyze_results.py. The legacy reproduce.ps1 also builds a manuscript and uses machine-specific paths; run the analysis components separately.

Run scientific commands from `project/` after restoring resources. Existing source files are byte-identical to their local originals; historical absolute paths may require local configuration. No new optimizer run, training run, physical validation or cross-machine solver validation was performed for this release.

## Contents and provenance

The snapshot contains 106 original files (18,832,594 bytes before compression). `RESOURCE_MANIFEST.json` maps each file to its source path, SHA-256 hash and resource archive. `PUBLICATION_RECORD.json` records the selected directories, actual research state and any large-file omissions. Installed environments, credentials, unrelated paper PDFs, manuscript submission materials and duplicate workspace junctions are excluded. Some branches are research candidates or partial implementations; their availability does not indicate completed experiments or publication readiness.

Existing source notices and third-party terms are retained. This release does not add a blanket open-source license or override third-party licenses. External dependencies remain subject to their upstream terms.
