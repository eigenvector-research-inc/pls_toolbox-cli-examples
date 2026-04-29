# Standard Model Structure Fields

The underlying structure (accessible via `.content` or `.detail`) contains these key fields.

## Top-Level Fields

| Field | Description |
|-------|-------------|
| `.modeltype` | Keyword defining model type |
| `.datasource` | Info about source data (subset of DSO fields, no raw data). Size 1xJ for J blocks. |
| `.date` | String date of model creation |
| `.time` | Vector `[year month day hour minute second]` |
| `.loads` | Cell array (DxJ) of factors. D=modes, J=blocks. |
| `.pred` | Predictions cell array |
| `.tsqs` | Cell array (DxJ) of Hotelling's T2 values |
| `.ssqresiduals` | Cell array (DxJ) of sum-squared residuals |
| `.description` | Cell array of description strings |
| `.detail` | Struct with model-specific details (see below) |

## `.loads` Field Layout

| Model Type | `.loads` contains |
|------------|-------------------|
| PCA, MCR | `{X-Scores; X-Loadings}` (2x1) |
| PLS, PCR | `{X-Scores, Y-Scores; X-Loadings, Y-Loadings}` (2x2) |
| PARAFAC | `{Mode1-Loadings; Mode2-Loadings; Mode3-Loadings; ...}` (Dx1) |

Each cell is an MxK matrix (M = mode size, K = number of components/factors).

```matlab
model.loads{1,1}        % X-block scores (PCA/PLS)
model.loads{2,1}        % X-block loadings (PCA/PLS)
model.loads{1,1}(:,1)   % Scores for first component only
model.loads{2,1}(:,1)   % Loadings for first component only
```

## Reconstructing Data from Model

```matlab
data_reconstructed = model.loads{1} * model.loads{2}';       % Full reconstruction
partial_recon = model.loads{1}(:,1:n) * model.loads{2}(:,1:n)';  % First n components
```

## `.detail` Sub-Fields

| Field | Description |
|-------|-------------|
| `.detail.data` | Original data cells (X-block often empty to save memory; Y-block usually stored) |
| `.detail.res` | Residuals (y_pred - y_obs). X-block often empty. |
| `.detail.ssq` | Variance captured table. PCA: `[PC# eigenvalue %var cum%var]`. PLS: `[LV# Xvar cumXvar Yvar cumYvar]`. |
| `.detail.rmsec` | RMSEC vector (one per component) |
| `.detail.rmsecv` | RMSECV vector (one per component). NaN for uncalculated. |
| `.detail.means` | Cell of mean vectors per block |
| `.detail.stds` | Cell of std vectors per block |
| `.detail.reslim` | Cell: 95% confidence limit for Q residuals (`.ssqresiduals{1}`) |
| `.detail.tsqlim` | Cell: 95% confidence limit for T2 (`.tsqs{1}`) |
| `.detail.reseig` | Residual eigenvalues (PCA only) |
| `.detail.cv` | Cross-validation method used |
| `.detail.split` | Number of CV splits |
| `.detail.iter` | Number of CV iterations (random mode) |
| `.detail.includ` | Cell (DxJ): included sample/variable indices |
| `.detail.label` | Cell (DxJ): labels. `{mode, block}`. 3rd index = set number. |
| `.detail.labelname` | Cell (DxJ): label set names |
| `.detail.axisscale` | Cell (DxJ): axis scales |
| `.detail.axisscalename` | Cell (DxJ): axis scale names |
| `.detail.title` | Cell (DxJ): mode titles |
| `.detail.titlename` | Cell (DxJ): title names |
| `.detail.class` | Cell (DxJ): class assignments. `{mode, block, set}` |
| `.detail.classname` | Cell (DxJ): class set names |
| `.detail.preprocessing` | Cell of calibrated preprocessing structs (one per block). Read-only after calibration. To SET preprocessing before calibration, use `model.options.preprocessing`. |
| `.detail.options` | Options struct used for model building. Before calibration, use `model.options` to get/set. |
| `.detail.history` | Cell array log of datetime + changes |

IMPORTANT: In model `.detail`, the second index is the **block number** (1=X, 2=Y), NOT the set number as in DSOs. The third index (when present) is the set number.

```matlab
model.detail.label{1,1}       % Mode 1 labels, X-block
model.detail.label{1,2}       % Mode 1 labels, Y-block
model.detail.class{2,1}       % Mode 2 classes, X-block
model.detail.axisscale{2,1}   % Mode 2 axis scales, X-block (e.g., wavenumbers)
```

## `.classification` Sub-Fields (Classification Models Only)

| Field | Size | Description |
|-------|------|-------------|
| `.classification.probability` | nsamples x nclasses | Probability of each sample in each class |
| `.classification.mostprobable` | nsamples x 1 | Most probable class assignment |
| `.classification.inclass` | nsamples x 1 | Strict assignment (prob > threshold in exactly one class; 0 otherwise) |
| `.classification.inclasses` | nsamples x nclasses | Binary: 1 where prob > threshold |
| `.classification.classnums` | 1 x nclasses | Unique non-zero class numbers (sorted) |
| `.classification.classids` | 1 x nclasses cell | Class ID strings corresponding to classnums |

Cross-validation classification: `model.detail.cvclassification` (same structure, based on CV predictions).
