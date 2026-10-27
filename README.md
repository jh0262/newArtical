# MO-PACPO code and reproducibility resources

This page provides the code and saved-data reproduction resources for:

**Archive-Guided Crested Porcupine Optimization for Multiobjective Dimensional Design of a 2PPaPaR Parallel Mechanism**

## Paper branch

[Open the MO-PACPO branch](https://github.com/jh0262/newArtical/tree/Archive-Guided-Crested-Porcupine-Optimization-for-Multiobjective-Dimensional-Design-of-a-2PPaPaR-Parallel-Mechanism)

Verified commit: `f3d2e4c34ab89197d3d438964f39552c2c2937b3`.

The branch contains 11,823 tracked files, including the original MATLAB source, compact saved experimental records, figure/statistical reproduction scripts, a per-file SHA-256 manifest, and source-archive provenance.

## Reproduce the analyses

Use MATLAB R2025b with Statistics and Machine Learning Toolbox. After downloading or cloning the paper branch, run each entry point in its directory:

```matlab
cd comparison
reproduce_all
```

```matlab
cd ../parameter-study
reproduce_publication
```

These commands recalculate the reported analyses from saved results. Details and data boundaries are documented in the branch README, `comparison/README_REPRODUCTION.md`, and `parameter-study/README_PUBLICATION.md`.

The original files and numerical results are preserved. Upload verification was completed on 28 October 2026.
