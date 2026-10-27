# Saved-record analyses specified before calculation

2026-10-26. Scope: the existing eight benchmarks and four-variable, three-objective 2PPaPaR dimensional problem. No optimizer search, no model or mechanism change, no recovery of P0 as a displayed baseline.

## Common evaluated-front diagnostic

Use all 25,100 saved objective evaluations in each of 30 paired trajectories for Full (DL), MOCPO-F and MOCPO-R on each problem. Filter finite feasible records (CV = 0), remove duplicate objective vectors, and retain the nondominated set. Truncate to at most 100 by a deterministic one-pass crowding-distance ranking; endpoints receive infinite distance and lexicographic objective order resolves ties. Apply this identical post-processing to all configurations. Recompute IGD and normalized HV using the frozen P4 reference fronts, scales and reference points. Recompute native-output metrics at the same density for comparison. In the engineering diagnostic, use saved 32,768-point search objectives; keep the existing 262,144-point final-output study as a separate result.

This is post hoc retention analysis of unchanged trajectories, not a rerun with a new online archive. Preserve all results. Paired signed-rank tests use the frozen approximate P4 implementation; Holm correction uses the 16 benchmark comparisons per metric and the two engineering comparisons for HV separately. Report unadjusted paired bootstrap 95% mean-difference intervals and adjusted p values separately. No added tuning or favorable selection of truncation rules.

## Common engineering decision

Use saved 262,144-point final feasible nondominated sets for Full, NSGA-II, MOEA/D-SBX, MOPSO-CD, adapted GDE3, joint, MOCPO-F and MOCPO-R, 30 runs each. Normalize objectives with the manuscript's fixed origin and scales, then use column Euclidean norms and ideal/nadir from the union of unique feasible final dimension vectors across all these methods and seeds. Freeze this common reference pool for every per-run selection. Equal objective weights; ties resolved by lexicographic dimensions. Select one design per run. Report medians and interquartile ranges of volume, first-order predicted RMS position error, GCI and common TOPSIS score. These are descriptive engineering comparisons, not an added significance claim. Preserve the earlier Full-only pooled representative design and identify its separate 753,000-evaluation provenance.

## Trajectory diagnosis and verification

Summarize existing Full engineering gate and diagnostic traces, including feasible evaluation fraction, stagnation eligibility and observed archive variance/step magnitude. This characterizes MO-PACPO's trajectories; it is not an empirical diagnosis of original CPO. Validate the new nondominance routine against brute-force dominance on small tied/random cases; check native metrics against saved values. Save source hashes, selected fronts and IDs, common decision inputs, scripts and tables. Reproduce derived tables from exported compact numerical records. Preserve all original data and documents.
