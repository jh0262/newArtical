# Current JMST figure and table map — 1 November 2026

`CURRENT_FIGURE_TABLE_MAP.csv` maps all 10 main tables, 16 supplementary tables, and 12 figures to source files, row filters, integration settings, statistical families, and reproduction commands. Paths begin with `comparison/` or `parameter-study/` and are relative to the repository root. When using an individual ZIP, its directory corresponds to the matching prefix.

`publication_tables_JMST/` contains the current manuscript display tables. These are formatted reference snapshots; the mapped numerical records supply their scientific values. The historical `publication_tables/` remains unchanged. Current Table 5 uses the six-contrast joint family, while current Table S11 retains the earlier three-comparison family. At 262,144 points, Full−noLock has primary adjusted p=0.055029 in Table 5 and p=0.027514 in Table S11. Each belongs to its stated family.

Run `export_jmst_tables` in `comparison/` to rebuild and check current Table 5. Run `export_jmst_parameter_tables` in `parameter-study/` to rebuild and check current Table 10 from 90 engineering confirmation records. Both helpers are included in the respective full saved-data reproduction entry points. Generated display checks are written to `publication_tables_JMST/recomputed/`. The primary statistical calculations remain in the original analysis scripts.

Figure 6 uses six marker shapes, a larger legend, and the unchanged saved coordinates and TOPSIS values. Run `make_figure6_jmst` to export the current PNG and vector PDF and a coordinate-preservation record. Historical Figure 6 source data remain in `figure_sources/Fig6.fig`.

The revision changes publication navigation and figure styling. Frozen model and optimizer implementations, raw runs, objective values, seeds, evaluation budgets, reference statistics, and historical figures remain preserved.
