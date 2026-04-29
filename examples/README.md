# PLS_Toolbox CLI Examples — Modeling Scripts

This directory contains eleven instructional MATLAB scripts that demonstrate the **object-oriented (OO) EVRIModel workflow** for the most common chemometric modeling tasks. Each script is self-contained and runnable top to bottom.

The scripts are designed to be **read like a tutorial** and **adapted as templates**. Every place where you would swap in your own data, preprocessing, or hyperparameters is marked with a `% >>> USER:` comment.

---

## What's in here

### Single-model walkthroughs

| Script | Model | Dataset | What you learn |
|--------|-------|---------|----------------|
| `pca_example.m` | PCA | `wine` + `arch` | The OO workflow on an unsupervised model; scores, loadings, T2/Q diagnostics; projecting new data |
| `pls_example.m` | PLS-1 | `plsdata` | Cross-validated LV selection; RMSEC vs RMSECV vs RMSEP |
| `pcr_example.m` | PCR | `plsdata` | Latent-variable regression that ignores Y when picking components, and why that matters |
| `ridge_optimized_example.m` | Ridge (L2) | `plsdata` | Explicit cross-validated lambda grid search; the 1-SE rule; coefficient-shrinkage path |
| `elasticnet_optimized_example.m` | Elastic Net (L1+L2) | `plsdata` | Explicit 2-D grid search; RMSECV heatmap; coefficient sparsity profile |
| `svmr_example.m` | SVM-R (RBF) | `plsdata` | Built-in CV grid search over cost / gamma / epsilon; why SVMs are scale-sensitive |
| `lda_example.m` | LDA | `arch` | Stratified split; confusion matrix; predicting truly unknown samples |
| `plsda_example.m` | PLSDA | `arch` | Cross-validated LV selection from the misclassification curve; class probability output |
| `svmda_example.m` | SVMDA (RBF) | `arch` | Multi-class one-vs-one SVM with built-in CV grid |

### Cross-model comparisons

| Script | What it does |
|--------|--------------|
| `regression_comparison_example.m` | Trains Ridge, Elastic Net, PCR, PLS, and SVMR on the **same** plsdata cal/test split and reports RMSEP, R², bias side by side |
| `classification_comparison_example.m` | Trains LDA, PLSDA, and SVMDA on the **same** arch cal/test split and reports classification error and per-class metrics |

---

## Datasets used

Both datasets ship with PLS_Toolbox in `toolbox/dems/`:

- **`arch`** — X-ray fluorescence (XRF) measurements on 10 elements for 75 archaeological samples. Samples come from 4 quarries (classes 1..4) plus a set of "unknowns" (class 0). Used by every classifier example and by `pca_example.m`'s second block.
- **`plsdata`** — 300×20 calibration block (`xblock1`, `yblock1`) and an independent validation block (`xblock2`, `yblock2`). Highly collinear predictors with a near-linear response — ideal for showing where regularized and latent-variable methods earn their keep. Used by every regression example.
- **`wine`** — A small EVRI demo dataset (wine/beer/liquor consumption by country) used as Block A in `pca_example.m`. Tiny enough that the PCA mechanics can be followed sample by sample.

---

## Recommended reading order

If this is your first exposure to the OO PLS_Toolbox workflow, work through the scripts in this order:

1. **`pca_example.m`** — start here. PCA is the simplest model and the script introduces every piece of the workflow you will see in the others: DataSet Objects, the `evrimodel(...)` constructor, the options-struct round-trip for preprocessing, `.calibrate`, `.apply`, and the score/loading/T2/Q vocabulary.
2. **`pls_example.m`** then **`pcr_example.m`** — latent-variable regression. PLS first because it is more commonly the right tool, then PCR for contrast.
3. **`ridge_optimized_example.m`** then **`elasticnet_optimized_example.m`** — regularized regression with explicit cross-validated grid search. The lambda loop you see here is the same pattern you would reuse for any hyperparameter.
4. **`svmr_example.m`** — nonlinear regression. By this point you will recognize the OO workflow and can focus on the SVM-specific options.
5. **`lda_example.m`**, **`plsda_example.m`**, **`svmda_example.m`** — the three classifiers, evaluated against the same `arch` split so you can compare methods fairly.
6. **`regression_comparison_example.m`** then **`classification_comparison_example.m`** — bring it all together. These are the scripts to copy when you need to benchmark methods on your own data.

---

## Prerequisites

- MATLAB R2020b or later (base only — **no MathWorks toolboxes are required**)
- PLS_Toolbox v9.0 or later, on the MATLAB path:

```matlab
addpath(genpath('<your_path>/pls_toolbox'));
```

Each script also calls `rng(0, 'twister')` at the top so cross-validation splits and SVM training are reproducible run to run.

---

## How to adapt these examples to your own data

Every script uses a consistent `% >>> USER:` marker above each line you are likely to change. There are roughly four kinds of edits you will almost always make:

1. **Data load** — replace `load arch` or `load plsdata` with whatever loads your DataSet Objects. If you have plain numeric matrices, wrap them with `dataset(your_matrix)`. See the `pls-toolbox-dataset` skill in this repository for DSO field details.
2. **Preprocessing** — the scripts default to `'autoscale'` on X and `'mean center'` on Y. For spectral data you may want `'snv'`, `'derivative'`, or a multi-step pipeline. See the `pls-toolbox-preprocessing` skill.
3. **Calibration / test split** — every regression script uses the built-in `xblock1` / `xblock2` split from `plsdata`. The classification scripts use a stratified 80/20 split of the labelled `arch` samples. Replace these with your own indices or your own pre-split DSOs.
4. **Hyperparameter ranges** — `lambdaGrid`, `ridgeGrid`, `lassoGrid`, `cost`, `gamma`, `epsilon`, `maxLV`. Defaults are tuned to run quickly on the demo data; widen or refine for production work. If a chosen optimum lands at a grid boundary, **always** widen that range and re-run.

A useful workflow when starting on a new dataset:
1. Run `pca_example.m` adapted to your data — confirm that PCA shows reasonable structure (no clusters of obvious outliers, sensible variance capture).
2. Pick a model from this directory whose problem framing matches yours and run it as a single-model walkthrough, paying attention to the cross-validation curve.
3. Use the relevant comparison script (regression or classification) to benchmark several methods at once before committing to one.

---

## Anatomy of a script

Every script in this directory follows the same skeleton:

```
Header banner             — Title, dataset, model, what you learn,
                            prerequisites, "how to adapt" pointer
clear / clc / close all   — Fresh workspace
rng(0, 'twister')         — Reproducible randomness
Plot styling defaults     — Same look across the whole series

Step 1 — Load and inspect data
Step 2 — Define preprocessing
Step 3 — Build the model (OO)
Step 4 — Cross-validate or grid-search
Step 5 — Apply to held-out data
Step 6 — Plots
Step 7 — fprintf summary block
Local helpers             — asvector, regression_metrics, etc.
```

The `fprintf` summary block prints a clean run-time digest so you can read what happened without opening any plot windows.

---

## Where the OO patterns come from

Each script consciously follows the canonical OO patterns documented in the four PLS_Toolbox skills shipped in this repository:

- `skills/pls-toolbox-dataset/` — DSO fields and conventions
- `skills/pls-toolbox-preprocessing/` — `preprocess('default', ...)` and multi-step pipelines
- `skills/pls-toolbox-model-object/` — EVRIModel properties and methods
- `skills/pls-toolbox-model-builder/` — End-to-end OO workflow

When in doubt, those references are the authoritative source.
