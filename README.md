# Archive-Guided Crested Porcupine Optimization for Multiobjective Dimensional Design of a 2PPaPaR Parallel Mechanism

Code and saved-data reproduction resources for MO-PACPO and the 2PPaPaR mechanism study. Scientific records: 27 October 2026. JMST publication display: 1 November 2026.

## Reproduce the reported analyses

MATLAB R2025b and Statistics and Machine Learning Toolbox are required. Run the two entry points from their own directories:

```matlab
cd comparison
reproduce_all
```

```matlab
cd ../parameter-study
reproduce_publication
```

These entry points recalculate statistics and figures from saved results. They do not launch optimization experiments. See `comparison/README_REPRODUCTION.md` and `parameter-study/README_PUBLICATION.md` for the schemas, dependencies, seeds, and output mapping.

## Resources

- `comparison/`: frozen MATLAB source, benchmark and engineering controls, numerical verification, final fronts, histories, common-output comparisons, 1478 pooled design candidates, and Figures 1–9/S1–S2 reproduction.
- `parameter-study/`: parameter-study code, configurations, 596 run summaries, final fronts, histories, statistical outputs, representative complete trajectories, and Figure 10 reproduction.
- `RESOURCE_MANIFEST.json`: current per-file SHA-256 hashes and byte counts for the two resource directories.
- `comparison/CURRENT_FIGURE_TABLE_MAP.csv`: current numbering, exact sources, filters, statistical families, and commands for all 38 figures and tables.
- `historical_manifests/`: the original source manifests, preserved alongside the publication revision.
- `PROVENANCE.json`: hashes of the two previously verified compact source archives.

The engineering model has four design variables and three objectives: workspace, first-order predicted RMS positioning error, and global conditioning index. Main comparisons use 30 independent seeds and 25,100 search evaluations per run. Default settings are noise gain 0.05, feedback lower bound 0.02, stagnation window 5, and pulse cap 0.20.

The source packages retain positive, negative, and nonsignificant outcomes. Complete evaluation tapes remain in the author-side archive described in the package documentation. The published compact data support the stated saved-data analyses. The JMST display revision preserves optimizer/model implementations and numerical records, adds current table mappings and checks, and improves Figure 6 marker distinctions. Original snapshots remain in Git history.

## Authors

Qingbo Lu, Shuangcheng Huang, Mengzhen Huang, Daojun Li, and Li Han. Correspondence: lqb0932@hati.edu.cn.

## Rights and provenance

Original attribution and source notices in the supplied code are retained. No additional blanket license is assigned by this upload. Rights in third-party material remain with their respective owners. The manuscript, cover letter, author administration files, and local account credentials are outside this code/resource snapshot.

## JMST display revision

Current manuscript tables are in `comparison/publication_tables_JMST/`; parameter tables are also available in `parameter-study/publication_tables_JMST/`. Current Table 5 uses the six-contrast joint family. The historical `comparison/publication_tables/Table6.csv` corresponds to current supplementary Table S11 and its separate three-comparison family. Current Table 10 comes from the engineering confirmation records in `parameter-study/`.

`export_jmst_tables` and `export_jmst_parameter_tables` regenerate and check current Tables 5 and 10. Both are called by the respective reproduction entry points. `make_figure6_jmst` exports Figure 6 alone and verifies unchanged coordinates, TOPSIS values, and legend order. `JMST_REVISION.json` records this publication revision and the preserved parent version.
