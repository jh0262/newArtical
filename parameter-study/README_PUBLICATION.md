# Publication parameter evidence, 27 October 2026

Extract this ZIP into an empty folder. In MATLAB R2025b with Statistics and Machine Learning Toolbox, change to that folder and run:

```matlab
reproduce_publication
```

This entry point recalculates the seven saved-data summary/statistical CSV files, regenerates the seven original figure pairs, and creates `figures/Figure10_Parameter_Activation.png` and `.pdf`. It starts no optimizer. The seven CSV files are `screen_summary`, `screen_statistics`, `confirm_summary`, `confirm_statistics`, `confirm_stability`, `screen_bootstrap`, and `confirm_bootstrap` in `data/`.

Main Table 11 uses the PPAR rows in `confirm_runs.csv`; supplementary Table S14 uses `code/ERStudy.m`; Table S15 uses `confirm_statistics.csv`; Table S16 uses the DTLZ3 rows in `confirm_runs.csv`. Figure 10 uses `screen_runs.csv` through `scripts/make_parameter_figure.m`. Original study instructions and independent verification are retained in the original README and audit directory. The author-side directory retains the complete 596 evaluation tapes; the compact package includes representative complete trajectories and all final-front records used by the analysis.

The defaults remain noise gain 0.05, feedback lower bound 0.02, stagnation window 5, and pulse cap 0.20. Engineering confirmation determines this choice; DTLZ3 is auxiliary. Screening and confirmation are separate seed batches.

The original experiment code, data, and previous audit records are unchanged. This publication extension adds one figure script, a wrapper, and this mapping. `audit/package_contents.json` lists the SHA-256 of every other ZIP entry.
