# H14 append-only deviations

## DEV-H14-ANALYSIS-001 — post-results validator correction

- Detected: 2026-09-01 after the complete formal bundle passed integrity audit and before any H1–H4 contrast result was produced.
- Trigger: frozen `computeH14Statistics` rejected 475 finite `normalizedFeasibleHv` values above 1; maximum observed value was 1.03948027150719.
- Root cause: `computeNormalizedFeasibleHV` normalizes objective coordinates and computes dominated hypervolume against normalized reference point `(1.1,1.1)`. Its mathematically admissible value range is `[0,1.21]`, not `[0,1]`.
- Classification: post-results technical implementation correction; not an exclusion, metric replacement, threshold change, model choice, subgroup choice or hypothesis amendment.
- Containment: the original RC1 analysis functions remain unchanged; no formal result row is edited, clipped, deleted or re-run.
- Authorized repair scope from user instruction `继续`: create separately named v0.2.1 analysis functions, add a RED→GREEN regression test, retain the original estimator, 20,000 bootstrap replicates, seed 2026083102, exact sign-flip test, Holm family, 0.01 practical threshold and −0.005 HV guardrail.
- Confirmatory boundary: the local plan was hash-frozen before results but was never externally registered. The correction may execute the frozen estimand, but its post-results timing must be disclosed in any manuscript or review package.
- Prohibited actions: clipping HV to 1, rescaling the result table, changing the −0.005 guardrail, deleting the 475 rows, or inspecting/selecting H1–H4 outcomes to choose a different analysis.
