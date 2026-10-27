# EarClip MODE多机制与消融研究

Code and reproducibility-resource snapshot prepared on 28 October 2026.

## Research status

The 2080 completed runs and negative comparisons are preserved. RESULTS_zh.md and ACCEPTANCE.json supersede the older README status.

## Restore and verify the saved resources

```bash
python restore_resources.py --download
```

This standard-library-only script verifies SHA-256 hashes and restores bundled files to their original relative paths under `project/`. It refuses to overwrite changed files. Download or clone this branch first. Resource archives are attached to the [paper-specific release](https://github.com/jh0262/newArtical/releases/tag/resources-P05-20261028); `--download` retrieves them and verifies their SHA-256 hashes before restoration.

## Entry points and dependencies

MATLAB: ec_setup; addpath("analysis"); ec_analyze. Python audit scripts and reproduce_results.ps1 are included. The legacy PowerShell wrapper uses a machine-specific MATLAB path.

Run scientific commands from `project/` after restoring resources. Existing source files are byte-identical to their local originals; historical absolute paths may require local configuration. No new optimizer run, training run, physical validation or cross-machine solver validation was performed for this release.

## Contents and provenance

The snapshot contains 18603 original files (1,097,214,353 bytes before compression). `RESOURCE_MANIFEST.json` maps each file to its source path, SHA-256 hash and resource archive. `PUBLICATION_RECORD.json` records the selected directories, actual research state and any large-file omissions. Installed environments, credentials, unrelated paper PDFs, manuscript submission materials and duplicate workspace junctions are excluded. Some branches are research candidates or partial implementations; their availability does not indicate completed experiments or publication readiness.

Existing source notices and third-party terms are retained. This release does not add a blanket open-source license or override third-party licenses. External dependencies remain subject to their upstream terms.
