---
name: pls-toolbox-model-object
description: Reference for PLS_Toolbox EVRIModel Objects in MATLAB. Use when the user is working with Eigenvector PLS_Toolbox model objects, model calibration, prediction, cross-validation, or multivariate model analysis (PCA, PLS, PCR, MCR, PLSDA, etc.) in MATLAB. Provides model states, properties, methods, standard model structure fields, and usage patterns.
---

# PLS_Toolbox EVRIModel Object Reference

EVRIModel Objects are the standard model container in Eigenvector's PLS_Toolbox and Solo. They wrap the Standard Model Structure and provide dot-notation access to properties and methods for building, calibrating, applying, and reviewing multivariate models from the MATLAB command line, scripts, and functions.

Documentation: https://wiki.eigenvector.com/index.php?title=EVRIModel_Objects

To get help on a model: `model.help` (opens help for the specific model type)

## Model States

EVRIModel objects exist in three distinct states:

1. **Empty (Uncalibrated)** - Created with `evrimodel()`, populated with data and settings, then calibrated.
2. **Calibrated** - Contains all results and parameters; can be applied to new data; can generate plots.
3. **Applied (Prediction)** - Result of applying a calibrated model to new data; contains prediction results. Cannot be applied to further data (use `.parent` to get the original model).

## Supported Model Types

The following model types are supported by EVRIModel objects. Each type has different available properties (scores, loadings, T2, Q, predictions, regression vectors, classification info).

### Decomposition Models
- **PCA** - Principal Component Analysis
- **MCR** - Multivariate Curve Resolution
- **UMAP** - Uniform Manifold Approximation and Projection
- **TSNE** - t-Distributed Stochastic Neighbor Embedding

### Regression Models
- **MLR** - Multiple Linear Regression
- **PLS** (PLS-1 / PLS-2) - Partial Least Squares
- **PCR** - Principal Component Regression
- **CLS** - Classical Least Squares
- **ANN** - Artificial Neural Network (regression)
- **ANNDL** - Deep Learning Neural Network (regression)
- **SVM-R** - Support Vector Machine (regression)

### Classification Models
- **PLSDA** - PLS Discriminant Analysis
- **SVMDA** - SVM Discriminant Analysis
- **ANNDA** - ANN Discriminant Analysis
- **SIMCA** - Soft Independent Modeling of Class Analogy
- **ANNDLDA** - Deep Learning Discriminant Analysis
- **XGBoostDA** - XGBoost Discriminant Analysis
- **LREGDA** - Logistic Regression Discriminant Analysis

### Property Availability by Model Type

Not all properties are available for all model types. Use this table to determine which fields are accessible.

| Property | PCA | MCR | UMAP | TSNE | MLR | PLS | PCR | CLS | ANN | ANNDL | SVM-R | PLSDA | SVMDA | ANNDA | SIMCA | ANNDLDA | XGBoostDA | LREGDA |
|----------|-----|-----|------|------|-----|-----|-----|-----|-----|-------|-------|-------|-------|-------|-------|---------|-----------|--------|
| `.scores` / `.loads{1}` | Y | Y | Y* | Y* | - | Y | Y | Y | - | - | - | Y | - | - | - | - | - | - |
| `.loadings` / `.loads{2}` | Y | Y | - | - | - | Y | Y | Y | - | - | - | Y | - | - | - | - | - | - |
| `.pred{2}` | - | - | - | - | Y | Y | Y | Y | Y | Y | Y | Y | Y | Y | - | Y | Y | Y |
| `.ssqresiduals{1}` (Q) | Y | Y | Y | Y | - | Y | Y | Y | - | - | - | Y | - | - | - | - | - | - |
| `.tsqs{1}` (T2) | Y | Y | - | - | Y | Y | Y | Y | - | - | - | Y | - | - | - | - | - | - |
| `.q` (reduced Q) | Y | Y | Y | Y | - | Y | Y | Y | - | - | - | Y | - | - | ** | - | - | - |
| `.t2` (reduced T2) | Y | Y | - | - | Y | Y | Y | Y | - | - | - | Y | - | - | ** | - | - | - |
| `.reslim` (Q limit) | Y | Y | - | - | - | Y | Y | Y | - | - | - | Y | - | - | - | - | - | - |
| `.tsqlim` (T2 limit) | Y | Y | - | - | - | Y | Y | - | - | - | - | Y | - | - | - | - | - | - |
| `.reg` | - | - | - | - | Y | Y | Y | - | - | - | - | Y | - | - | - | - | - | - |
| `.classification` | - | - | - | - | - | - | - | - | - | - | - | Y | Y | Y | Y | Y | Y | Y |

`Y` = available, `-` = not available

`*` UMAP/TSNE scores are also accessible via `model.detail.umap.embeddings` and `model.detail.tsne.embeddings` respectively.

`**` SIMCA uses `model.rq` and `model.rtsq` instead (one column per submodel).

### UMAP and TSNE Scores Access

```matlab
% Standard shortcut
scores = model.scores;

% Model-specific alternative access
umap_embeddings = model.detail.umap.embeddings;
tsne_embeddings = model.detail.tsne.embeddings;
```

### SIMCA-Specific Properties

SIMCA models have per-submodel diagnostics instead of the standard `.q` and `.t2`:

```matlab
model.rq       % Reduced Q residuals (one column per submodel)
model.rtsq     % Reduced T2 values (one column per submodel)
```

### PLS-2 Regression Vectors

For PLS-2 models (multiple Y variables), `.reg` returns a cell array. Access individual regression vectors by column:

```matlab
reg_y1 = model.reg(:,1);   % Regression vector for first Y variable
reg_y2 = model.reg(:,2);   % Regression vector for second Y variable
```

### Classification Model Predictions

For classification models (PLSDA, SVMDA, ANNDA, SIMCA, ANNDLDA, XGBoostDA, LREGDA), `model.pred{2}` contains one column for each class group modeled.

## Creating and Calibrating a Model

See the `pls-toolbox-preprocessing` skill for building preprocessing structures.

**Setting preprocessing on an uncalibrated model:**

Preprocessing is assigned via `model.options.preprocessing`, which is a cell array with one entry per data block (block 1 = x-block, block 2 = y-block). You must get the options struct first, modify it, then assign it back:

```matlab
model = evrimodel('pca');       % Create empty PCA model
model.x = data;                 % Assign x-block data (DSO or matrix)
model.ncomp = 3;                % Set number of components

% Set preprocessing via options
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');  % X-block preprocessing
model.options = opts;

model = model.calibrate;        % Build the model

% With cross-validation
model = model.crossvalidate;                    % Default CV settings
model = model.crossvalidate(cvi, ncomp);        % Custom CV splits and ncomp
```

IMPORTANT: Not all model types support direct calibration via `evrimodel`. Check `.cancalibrate` first. If it returns 0, you must use the function named in `.modeltype` directly (e.g., `model = pca(data, ncomp)`).

### Checking what inputs a model accepts

```matlab
model.inputs          % Cell array of settable property names
model.validmodeltypes % Cell array of all valid model type keywords
```

## Dot-Notation Access

All properties and methods use standard MATLAB dot notation:

```matlab
model.modeltype       % Get model type keyword (e.g., 'PCA', 'PLS')
model.plotscores      % Call a method (no args)
model.apply(newdata)  % Call a method (with args)
```

## Displaying Model Contents

```matlab
model                 % Type name at command line to see summary
model.disp            % Explicit display
model.info            % Returns cell array of text description
```

At the MATLAB command window, the display has toggleable sections:
- **Desc.** (Description) - text summary of model type, build info, results
- **Contents** - raw field information (similar to old PLS_Toolbox structure format)

## Uncalibrated Model Properties

### Read-Only Status Properties

| Property | Returns | Description |
|----------|---------|-------------|
| `.cancalibrate` | 0 or 1 | 1 if model can be calibrated via `.calibrate`, 0 if must use function directly |
| `.inputs` | cell array | Property names that can be set before calibrating |
| `.validmodeltypes` | cell array | Valid model type keywords for assignment to `.modeltype` |

### Modifiable Properties

| Property | Type | Description |
|----------|------|-------------|
| `.modeltype` | string | Model type keyword (e.g., `'pca'`, `'pls'`, `'mcr'`, `'plsda'`). Must be from `.validmodeltypes`. |
| `.display` | `'on'` / `'off'` | Command-line output during calibrate/apply |
| `.plots` | `'final'` / `'none'` | Plot generation after calibrate/apply |
| `.options` | struct | Model-specific options. Get the struct, modify it, then assign it back. Contains `.preprocessing` cell for setting preprocessing before calibration. (e.g., `opts = model.options; opts.confidencelimit = 0.99; opts.preprocessing{1} = pp; model.options = opts;`) |

### Setting data and meta-parameters

The settable properties depend on model type. Use `.inputs` to see available properties. Example properties for common types:

```matlab
% PCA
model.x = data;           % X-block data
model.ncomp = 5;           % Number of components

% PLS / PCR
model.x = xdata;           % X-block
model.y = ydata;           % Y-block
model.ncomp = 3;           % Number of latent variables

% LWR
model.x = xdata;
model.y = ydata;
model.ncomp = 3;
model.npts = 50;           % Number of local points
```

## Uncalibrated Model Methods

| Method | Description |
|--------|-------------|
| `.calibrate` | Build model from current data and settings. Returns model object. |
| `.crossvalidate(cvi, ncomp)` | Build and cross-validate. `cvi` = CV splitting (default: venetian blinds). `ncomp` = number of components (default: max). |

IMPORTANT: In MATLAB, when no output is captured, the model is stored back into the same variable. In Solo Scripting, you must capture the output: `m = m.calibrate;`

## Calibrated Model Properties

Check calibration state with `.iscalibrated` (returns 1 when calibrated).

### Shortcut Properties (data extraction)

These are convenience accessors into the Standard Model Structure fields:

| Property | Returns | Equivalent field |
|----------|---------|-----------------|
| `.scores` | X-block scores matrix | `.loads{1,1}` |
| `.loadings` | X-block loadings matrix | `.loads{2,1}` |
| `.ncomp` | Number of components used | - |
| `.prediction` | Model-type-dependent prediction result (see below) | varies |
| `.predictionlabel` | Labels for columns of `.prediction` | - |
| `.t2` | Hotelling's T2 for x-block | `.tsqs{1}` |
| `.q` | X-block sum-squared residuals | `.ssqresiduals{1}` |
| `.reslim` | 95% confidence limit for Q residuals | `.detail.reslim{1}` |
| `.tsqlim` | 95% confidence limit for T2 | `.detail.tsqlim{1}` |
| `.reg` | Regression vector (MLR, PCR, PLS, PLSDA only; cell for PLS-2) | - |
| `.x` | Original x-block data (when stored) | - |
| `.y` | Original y-block data (when stored) | - |
| `.xhat` | Reconstructed x-block (see `datahat`) | - |
| `.yhat` | Estimated y-block | - |
| `.datasource` | Info about source data (cell; `{1}` for X-block, `{2}` for Y-block) | - |
| `.description` | Cell array of description strings about the model | - |
| `.uniqueid` | Unique model identifier string (author + date/time) | - |
| `.iscalibrated` | 1 if calibrated or applied, 0 if empty | - |
| `.detail` | Model-specific statistics, results, parameters (struct) | - |

**`.prediction` return values by model type:**
- Decomposition (PCA, MCR, etc.) - x-block scores (`.loads{1,1}`)
- Regression (PLS, PCR, SVM, etc.) - y-block predictions (y_hat, usually `.pred{2}`)
- Classification (PLSDA, SVMDA, KNN, etc.) - single-class assignment string per sample

**`.detail` shortcut:** Many fields within `.detail` can be accessed directly from the top-level model:
```matlab
model.ssq              % Same as model.detail.ssq
model.rmsec            % Same as model.detail.rmsec
model.rmsecv           % Same as model.detail.rmsecv
```

NOTE: To SET preprocessing before calibration, use `model.options.preprocessing` (not `model.detail.preprocessing`). After calibration, `model.detail.preprocessing` contains the calibrated preprocessing with learned parameters.

### Statistics Properties

| Property | Returns | Notes |
|----------|---------|-------|
| `.t2` | Hotelling's T2 vector | Indexable: `model.t2(1:5)`. If `.reducedstats='on'`, normalized to confidence limit. |
| `.q` | Q residuals vector | If `.reducedstats='on'`, normalized to confidence limit. |
| `.scoredistance` | Normalized KNN score distance | Detects inliers in unusual score space. Optional `(k)` input. Value of 1 = as far as furthest calibration sample. |
| `.esterror` | Error estimate per sample (see `ils_esterror`) | For predictions: `pred.esterror(model)` |

### Component Naming

```matlab
% Available for PCA, MCR, PURITY, PARAFAC model types
model.componentnames = {'Component 1' 'Low Zirconium' 'High Yttrium'};
```
Recalculating the model clears component names. Set them at the end of model building.

### Behavior-Modifying Properties

| Property | Values | Effect |
|----------|--------|--------|
| `.matchvars` | `'on'` / `'off'` | `'on'`: align new data variables to model before `.apply()`. `'off'`: error if variables don't match. |
| `.contributions` | `'passed'` / `'used'` / `'full'` | Controls detail of T2/Q contributions from `.tcon`/`.qcon`. `'passed'` = only passed variables in passed order (preferred). |
| `.reducedstats` | `'on'` / `'off'` | `'on'`: `.t2` and `.q` are normalized to their confidence limits. `'off'`: raw values. |
| `.display` | `'on'` / `'off'` | Command-line output during apply |
| `.plots` | `'final'` / `'none'` | Plot generation during apply |

## Calibrated Model Methods

### Applying to New Data

```matlab
prediction = model.apply(x_new);                    % Basic prediction
prediction = model.apply(x_new, y_new);             % With validation y-data
prediction = model.apply(x_new, y_new, options);    % With custom options
```

NOTE: `.plots` and `.display` settings on the model override any values in the `options` input.

### Cross-Validation (after calibration)

```matlab
model = model.crossvalidate(x, cvi, ncomp);
```
Requires x-block data as input (most models don't store calibration x-data).

### Plotting Methods

| Method | Description |
|--------|-------------|
| `.plotscores` | Plot scores (all sample-specific statistics). With output: returns DSO, no plot. |
| `.plotloads` | Plot loadings (all variable-specific statistics). With output: returns DSO, no plot. |
| `.ploteigen` | Plot eigenvalues / RMSEC / misclassification vs. components. With output: returns DSO, no plot. |

```matlab
model.plotscores           % Generate interactive plot
dso = model.plotscores;    % Get data as DSO without plotting
```

### Contribution Methods

| Method | Description |
|--------|-------------|
| `.qcon(x)` | Q contributions (x-block residuals matrix). Requires x-data input for most model types. See `qconcalc`. |
| `.tcon(x)` | T2 contributions (scaled x-block projections). If `x` omitted, returns calibration contributions. See `tconcalc`. |

### Variance Captured

| Method | Returns |
|--------|---------|
| `.ssqtable` | MATLAB table object |
| `.ssqtext` | Raw text |
| `.ssqcell` | Cell array |

## Applied Model (Prediction) Properties

When `.apply()` is used, the result is an EVRIModel in the "applied" state.

| Property | Returns | Description |
|----------|---------|-------------|
| `.isprediction` | 0 or 1 | 1 if this is a prediction object |
| `.parent` | EVRIModel | Copy of the original calibrated model |
| `.scores` | matrix | Scores for the NEW data (not calibration data) |
| `.t2` | vector | T2 for the new data |
| `.q` | vector | Q residuals for the new data |
| `.prediction` | varies | Predictions for the new data |

When a model is applied, `.modeltype` returns the type with a `_PRED` suffix (e.g., `PCA_PRED`, `PLS_PRED`, `MCR_PRED`, `MLR_PRED`, `PCR_PRED`, `CLS_PRED`, `PLSDA_PRED`).

All calibrated model plotting and extraction methods work on predictions, returning results for the applied data.

### Re-applying the original model

```matlab
pred2 = pred.parent.apply(x_newer);   % Apply original model to different data
```

### Prediction-specific method calls

Some methods require the original model when used on predictions:
```matlab
pred.esterror(model)              % Error estimate needs original model
pred.scoredistance(model)         % Score distance needs original model
pred.scoredistance(model, 1)      % Score distance with k=1
```

## General Properties (All States)

### Informational (Read-Only)

| Property | Returns | Description |
|----------|---------|-------------|
| `.author` | string | `user@computername` - electronic signature |
| `.uniqueid` | string | Unique ID (author + date/time stamp) |
| `.evrimodelversion` / `.modelversion` | string | Model version (linked to PLS_Toolbox/Solo version) |
| `.info` | cell array | Text description of model (same as command-line display) |
| `.isclassification` | 0 or 1 | 1 if classification model type |
| `.isyused` | 0 or 1 | 1 if model uses x-block and y-block |
| `.content` | struct | Raw model in old PLS_Toolbox structure format |
| `.downgradeinfo` | string | Explains purpose of `.content` field |

### General Methods

| Method | Description |
|--------|-------------|
| `.disp` | Display model contents (no output variable) |
| `.encode` | Returns m-script code to regenerate model content (see `encode`) |
| `.encodexml` | Returns XML descriptor of model (see `encodexml`, `parsexml`) |
| `.help` | Opens help for the model type |
| `.help.predictions` | Returns struct of possible sub-fields for certain properties |
| `.isnewmodel` | Test if model is newer than current software version |

## Standard Model Structure Fields

See `references/standard-model-structure.md` for the full reference of top-level fields, `.loads` layout, `.detail` sub-fields, data reconstruction, and `.classification` sub-fields.

## Common Patterns

### Build PCA model and extract results

```matlab
model = evrimodel('pca');
model.x = spectra_dso;
model.ncomp = 5;
model.display = 'off';
model.plots = 'none';
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');
model.options = opts;
model = model.calibrate;

scores = model.scores;           % X-block scores
loadings = model.loadings;       % X-block loadings
t2_vals = model.t2;              % Hotelling's T2
q_vals = model.q;                % Q residuals
ssq_table = model.ssqcell;      % Variance captured
```

### Build PLS model with cross-validation

```matlab
model = evrimodel('pls');
model.x = xdata;
model.y = ydata;
model.ncomp = 10;
model = model.crossvalidate;     % Build + cross-validate

rmsecv = model.detail.rmsecv;
```

### Apply model to new data

```matlab
pred = model.apply(x_new);
y_predicted = pred.prediction;     % Get predictions
new_scores = pred.scores;          % Scores for new data
new_t2 = pred.t2;                  % T2 for new data
new_q = pred.q;                    % Q for new data
```

### Apply model with validation data

```matlab
pred = model.apply(x_test, y_test);
% pred now contains comparison statistics
```

### Get contributions for diagnostics

```matlab
t2_contrib = model.tcon(xdata);    % T2 contributions
q_contrib = model.qcon(xdata);     % Q contributions
```

### Extract data for external use

```matlab
% Export loadings with axis scale
wavenumbers = model.detail.axisscale{2,1}(model.detail.includ{2})';
xy_data = [wavenumbers model.loads{2,1}(:,1)];
save loadings.prn xy_data -ascii
```

### Plot without displaying, get DSO

```matlab
scores_dso = model.plotscores;     % Returns DSO, no plot
loads_dso = model.plotloads;       % Returns DSO, no plot
```

### Check model type capabilities

```matlab
model.isclassification   % 1 if classification model
model.isyused            % 1 if two-block method
model.cancalibrate       % 1 if supports .calibrate
model.isprediction       % 1 if this is an applied/prediction object
```

## Backwards Compatibility

- Models saved in current PLS_Toolbox are NOT readable by versions prior to EVRIModel objects.
- Use `.content` to extract old-style structure format (partial compatibility).
- To force all models to load as non-object structures:
  ```matlab
  setplspref('evrimodel', 'noobject', 1)
  ```
- Contact Eigenvector Helpdesk for specific compatibility needs.
