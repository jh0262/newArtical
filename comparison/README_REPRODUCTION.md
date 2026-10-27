# MO-PACPO compact reproduction package

Use MATLAB R2025b with Statistics and Machine Learning Toolbox. The analysis uses one computational thread; it does not launch an optimizer or a worker pool.

Extract this ZIP into an empty folder, set that folder as the MATLAB working directory, and run:

    reproduce_all

This command recomputes benchmark, principal-axis, direction/trigger, MOCPO and joint-control summaries and statistical families, checks the reference tables, and regenerates Figures 1–9 and S1–S2 in figures/. All outputs remain within the extracted directory. The source-code classes and the scientific statistical formulas are preserved; the four analysis readers are adapted to the compact schema. The entry point recomputes IGD/HV/SP from retained final objective arrays for benchmark and P4/P5 records and recomputes mechanism indicators from saved common-integration objective arrays. Bootstrap indices follow the original fixed seeds. No objective values are fabricated or rounded in the MAT records.

Optional independent verification (Python 3.10+, numpy, scipy, pandas):

    python -X utf8 MO_PACPO_Machines_P1联合对照修订_20261025/scripts/verify_joint.py

## What is retained

All final objective arrays, constraint violations, evaluation IDs, seeds, configurations and histories used by the formal comparison analyses; final physical dimensions for the mechanism; common-integration outputs; required operator and gate traces; all 1478 design candidates; the frozen code and model; and the source data for every main figure. Figures 2, 3, 4, 6, 8 and 9 are regenerated from the retained MATLAB graphics objects containing their full numerical coordinates, with a coordinate-preservation assertion. Figures 7, S1 and S2 are regenerated from recomputed statistical tables and traces. Figures 1 and 5 are schematic vector masters, copied without scientific changes.

The historical MAT records include reused runs and numerical-validation files; file counts are not independent sample counts. Each formal configuration retains 30 independent search seeds. The expected/ directory contains small reference tables, used only for checks after recalculation, never as input to the statistical calculations.

## Data directory map

The following directories are relative to the extracted package root:

- Earlier benchmark and archive verification: `MO_PACPO_P1修正版_20261024/results/` and `validation/`.
- Mechanism principal-axis controls and operator logs: `MO_PACPO_机构消融与P1修订_20261024/data/`.
- Innovation controls (direction, trigger and MOCPO): `MO_PACPO_创新性对照修订_20261025/data/`. `runs.csv` includes per-run ArchiveSize, Pulses and gate counts; `summary.csv` gives pulse/gate summaries; `trajectory_pairs.csv` records trajectory identities.
- Joint-removal controls: `MO_PACPO_Machines_P1联合对照修订_20261025/data/`.
- Candidate dimensions, representative designs and workspace sections: `MO_PACPO_论文同步修订_20261024/data/`.

## Compact schema and full records

The redundant population, normalized benchmark decision coordinates, full pointwise evaluation tapes and per-run duplicate source text are omitted. Each run retains SHA-256 digests of its original complete tape, initialization and archive, allowing equality checks of recorded paired trajectories. The author-side extraction checked each retained final archive against its evaluation IDs before removing the tape. These digests document the extraction; they do not enable a recipient to replay an omitted tape. Full raw records and all earlier versions remain preserved in the authors' original 14.96 GB archive. This compact package independently reproduces the reported analyses and plotted data; complete tape replay uses that separate original archive.

Frozen application entry points are supplied as implementation source. To perform new searches, use a separate directory with newly created result paths; the compact results are analysis records, not optimizer restart states. Historical project READMEs and status files describe their original full-run packages; the instructions in this root README define the compact delivery.

## Historical execution note

The mechanism-ablation batch initially encountered an attachment-path distribution failure before any optimization evaluations. The corrected frozen batch completed successfully. This note was moved from Supplementary Section S2; the original failure record is retained in the full package.


## Publication display revision 26 October 2026

The retired initial scheme (P0 / legacy / MO-PACPO previous) is omitted from the revised manuscript tables and Figures 2, 3 and 6. make_figures applies strip_legacy_presentation to saved graphics before styling and export. All retained numerical values are asserted unchanged; box-chart category positions are compacted. Historical run files, source graphics and reference statistical families remain available for provenance. The reported Holm adjustments retain the original predeclared families; dropping a displayed comparator does not recalculate or relax their correction. No optimization experiment is added. The historical scheme definition is preserved in archived_legacy_definition.txt.


## Review implementation 26 October 2026

The study boundary, optimizer implementations, raw runs and native-output indicators remain unchanged. `reproduce_all` now also invokes `reproduce_review` and checks six additional tables (37 reference tables in total). The new directory `review_analysis/` contains 810 common-front selections and 240 final engineering sets for one decision per run. `ReviewAnalysis.m` calculates indicators, paired statistics and common-reference TOPSIS from these numerical arrays. No optimizer, physical-model evaluation, or new random search is invoked.

`common_front_inputs.mat` contains capacity-100 selected objective vectors, original evaluation IDs, native final vectors, feasible/nondominated counts, source paths and SHA-256 digests. These arrays were extracted from all 25,100 evaluations of each original trajectory, using the frozen protocol. The recipient can recompute reported indicators and statistics from these selected vectors. Complete extraction and alternative truncation require the separately retained full evaluation tapes; the author-side revision directory additionally preserves the untruncated nondominated sets. This distinction matters because the compact selection does not contain discarded evaluations.

`decision_inputs.mat` contains all saved feasible final candidates needed to reconstruct the 23,243-unique-design common reference pool and repeat the 240 independent-run decisions. The input data use existing 262,144-point objectives. `common_decision_basis.json` records shared norms and ideal points. The earlier 1478-candidate Full-only choice and all of its values remain unchanged. The new per-run scores use a separate common reference basis.

`ANALYSIS_PROTOCOL.md` records the saved-record analysis rules before calculation. Six new CSV outputs contain 1149 rows. They extend, rather than replace, the original statistical families. Existing source graphs and all 11 published figures remain unchanged; captions and table numbering are updated in the manuscript. New tables 1, 4 and 8 give mechanism evidence, common-output HV and engineering decisions, respectively. Main Tables 2, 3, 5, 6, 7, 9 and 10 retain the earlier scientific values. Main Table 3 repeats Full values at the same display precision as Table 2.
