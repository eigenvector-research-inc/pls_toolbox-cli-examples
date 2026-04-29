---
name: pls-toolbox-model-builder
description: General guide for building multivariate models with Eigenvector PLS_Toolbox (PLST) in MATLAB. Trigger when user mentions PLS_Toolbox, PLST, plst, pls_toolbox, or asks to build PCA, PLS, PCR, MCR, PLSDA, classification, or regression models using Eigenvector software. Covers the Object-Oriented (OO) workflow (preferred) and Function-Form workflow. Coordinates the DSO, preprocessing, and model object skills.
---

# PLS_Toolbox Model Building Guide

PLS_Toolbox (PLST) is Eigenvector Research's chemometrics toolbox for MATLAB. This skill covers command-line / scripting workflows for building models. PLS_Toolbox also has a GUI (`analysis`), but this skill focuses exclusively on producing MATLAB code and scripts.

## Two Ways to Build Models

PLS_Toolbox supports two approaches:

1. **Object-Oriented (OO) form** — Uses `evrimodel()` objects with dot-notation. **This is the PREFERRED approach.** Always use this unless the user explicitly asks for the function form.
2. **Function form** — Direct function calls like `pca(x, ncomp)`, `pls(x, y, ncomp)`. Legacy approach, still fully supported.

### Why prefer the OO form?
- Cleaner, more readable scripts
- Preprocessing is stored in the model and applied automatically on `.apply()`
- `.calibrate` and `.crossvalidate` handle everything in one call
- Consistent API across all model types
- Easier to inspect, modify, and reapply models

## Skill Dependencies

This skill orchestrates three companion skills. Refer to them for detailed field and method reference:

- **`pls-toolbox-dataset`** — DataSet Object (DSO) creation, fields, labels, classes, axis scales
- **`pls-toolbox-preprocessing`** — Preprocessing structures, keywords, calibrate/apply/undo
- **`pls-toolbox-model-object`** — EVRIModel object properties, methods, Standard Model Structure

---

## Complete OO Workflow (Preferred)

The standard workflow for any model is:

```
1. Prepare data (DSO)
2. Create empty model (evrimodel)
3. Assign data and parameters
4. Assign preprocessing
5. Calibrate or cross-validate
6. Inspect results
7. Apply to new data
```

### Step-by-Step: PCA Model

```matlab
%% 1. Prepare data as DSO
data = dataset(x_matrix);
data.label{1} = sample_names;
data.label{2} = variable_names;
data.axisscale{2} = wavenumbers;

%% 2–4. Create model, assign data, preprocessing, and parameters
model = evrimodel('pca');
model.x = data;
model.ncomp = 5;
model.display = 'off';
model.plots = 'none';
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');
model.options = opts;

%% 5. Calibrate
model = model.calibrate;

%% 6. Inspect results
scores = model.scores;
loadings = model.loadings;
t2 = model.t2;
q = model.q;
model.plotscores;
model.plotloads;
model.ploteigen;

%% 7. Apply to new data
pred = model.apply(x_new);
new_scores = pred.scores;
new_t2 = pred.t2;
new_q = pred.q;
```

### Step-by-Step: PLS Regression Model

```matlab
%% Create and configure
model = evrimodel('pls');
model.x = xdata;
model.y = ydata;
model.ncomp = 10;
model.display = 'off';
model.plots = 'none';

%% Preprocessing (get options, modify, assign back)
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');      % X-block
opts.preprocessing{2} = preprocess('default', 'mean center');    % Y-block
model.options = opts;

%% Cross-validate (builds + cross-validates)
model = model.crossvalidate;

%% Inspect
rmsec = model.detail.rmsec;
rmsecv = model.detail.rmsecv;
model.plotscores;
model.ploteigen;

%% Predict
pred = model.apply(x_new);
y_pred = pred.prediction;
```

### Step-by-Step: PCR Regression Model

```matlab
model = evrimodel('pcr');
model.x = xdata;
model.y = ydata;
model.ncomp = 8;
model.display = 'off';
model.plots = 'none';
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');
opts.preprocessing{2} = preprocess('default', 'mean center');
model.options = opts;
model = model.crossvalidate;
```

### Step-by-Step: MCR Model

```matlab
model = evrimodel('mcr');
model.x = data;
model.ncomp = 3;
model.display = 'off';
model.plots = 'none';
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'mean center');
model.options = opts;
model = model.calibrate;

%% MCR-specific: concentrations and spectra
C = model.scores;       % Concentration profiles
S = model.loadings;     % Spectral profiles
```

### Step-by-Step: PLSDA Classification Model

```matlab
model = evrimodel('plsda');
model.x = xdata;
model.y = class_labels;    % Numeric class vector or cell array of strings
model.ncomp = 10;
model.display = 'off';
model.plots = 'none';
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');
model.options = opts;
model = model.crossvalidate;

%% Classification results
class_pred = model.prediction;                     % Class assignments
prob = model.classification.probability;           % Per-class probabilities
misclass = model.detail.misclassedc;               % Misclassification rates
```

### Step-by-Step: MLR Model

```matlab
model = evrimodel('mlr');
model.x = xdata;
model.y = ydata;
model.display = 'off';
model.plots = 'none';
model = model.calibrate;

reg_vector = model.reg;
pred = model.apply(x_new);
y_pred = pred.prediction;
```

## Cross-Validation Options

### Using `.crossvalidate` (OO form)

```matlab
%% Default: venetian blinds, sqrt(n) splits
model = model.crossvalidate;

%% Custom CVI
model = model.crossvalidate(cvi, ncomp);
```

### CVI (Cross-Validation Index) Formats

CVI defines how samples are split into calibration and test groups:

```matlab
%% Cell format: {method, splits, iterations}
cvi = {'vet', 10};           % Venetian blinds, 10 splits
cvi = {'con', 5};            % Contiguous blocks, 5 splits
cvi = {'rnd', 10, 20};       % Random subsets, 10 splits, 20 iterations
cvi = {'loo'};               % Leave-one-out

%% Vector format: integer vector (length = number of samples)
%   -2 = always in test set
%   -1 = always in calibration set
%    0 = never used
%    1,2,3,... = test subset assignment
cvi = [1 2 3 1 2 3 1 2 3 1];   % 3-fold manual split
```

## Multi-Step Preprocessing

```matlab
%% Build a pipeline
s1 = preprocess('default', 'snv');
s2 = preprocess('default', 'derivative');
s3 = preprocess('default', 'mean center');
pp = [s1 s2 s3];   % Applied in order: SNV -> derivative -> mean center

opts = model.options;
opts.preprocessing{1} = pp;
model.options = opts;
```

See the `pls-toolbox-preprocessing` skill for all available keywords, settings, and structure details.

## Extracting Results from Models

### Common extractions (all model types)

```matlab
model.info                    % Text summary
model.detail.ssq              % Variance captured table
model.ssqcell                 % Variance captured as cell array
model.detail.preprocessing    % Preprocessing used (calibrated; read-only after calibration)
model.detail.options          % Options used
model.author                  % Who built it
model.uniqueid                % Unique identifier
```

### Decomposition models (PCA, MCR)

```matlab
model.scores                  % X-block scores
model.loadings                % X-block loadings
model.t2                      % Hotelling's T2
model.q                       % Q residuals
model.reslim                  % Q confidence limit
model.tsqlim                  % T2 confidence limit
```

### Regression models (PLS, PCR, MLR, CLS)

```matlab
model.prediction              % Y predictions (y_hat)
model.reg                     % Regression vector
model.detail.rmsec            % RMSEC
model.detail.rmsecv           % RMSECV (after cross-validation)
```

### Classification models (PLSDA, SVMDA, ANNDA, SIMCA, etc.)

```matlab
model.prediction                        % Class assignments
model.classification.probability        % Per-class probabilities
model.classification.mostprobable       % Most probable class
model.classification.inclass            % Strict class assignment
model.classification.classids           % Class ID strings
model.detail.misclassedc                % Calibration misclassification
model.detail.misclassedcv               % CV misclassification
```

### Getting DSOs from plot methods (no actual plot)

```matlab
scores_dso = model.plotscores;     % Scores as DSO
loads_dso = model.plotloads;       % Loadings as DSO
eigen_dso = model.ploteigen;       % Eigenvalues as DSO
```

## Applying Models

```matlab
%% Basic prediction (preprocessing applied automatically)
pred = model.apply(x_new);

%% With validation data
pred = model.apply(x_test, y_test);

%% Extract results from prediction
pred.prediction          % Predictions
pred.scores              % Scores for new data
pred.t2                  % T2 for new data
pred.q                   % Q for new data

%% Re-apply original model from a prediction object
pred2 = pred.parent.apply(x_other);
```

## Contributions (Diagnostics)

```matlab
t2_con = model.tcon(xdata);     % T2 contributions
q_con = model.qcon(xdata);      % Q contributions

%% Control what's returned
model.contributions = 'passed';  % Only passed variables (preferred)
model.contributions = 'used';    % All variables used by model
model.contributions = 'full';    % All variables including excluded
```

## Reduced Statistics

```matlab
model.reducedstats = 'on';     % .t2 and .q normalized to confidence limits
model.reducedstats = 'off';    % .t2 and .q are raw values
```

When `'on'`, values > 1 exceed the confidence limit.

## Variable Matching

```matlab
model.matchvars = 'on';        % Align new data variables to model before apply
model.matchvars = 'off';       % Error if variables don't match (default)
```

---

## Function Form (Legacy — use only when requested)

The function form calls the modeling function directly. Each function returns a Standard Model Structure.

### PCA (function form)

```matlab
options = pca('options');
options.display = 'off';
options.plots = 'none';
options.preprocessing = {preprocess('default', 'autoscale')};

model = pca(x, ncomp, options);          % Calibrate
pred = pca(x_new, model, options);       % Apply to new data
```

### PLS (function form)

```matlab
options = pls('options');
options.display = 'off';
options.plots = 'none';
options.preprocessing = {preprocess('default', 'autoscale'), preprocess('default', 'mean center')};

model = pls(x, y, ncomp, options);       % Calibrate
pred = pls(x_new, model, options);       % Predict (no y)
valid = pls(x_new, y_new, model, options); % Predict with validation
```

### PCR (function form)

```matlab
options = pcr('options');
model = pcr(x, y, ncomp, options);
pred = pcr(x_new, model, options);
```

### PLSDA (function form)

```matlab
options = plsda('options');
model = plsda(x, y, ncomp, options);     % y = class vector
pred = plsda(x_new, model, options);
```

### MCR (function form)

```matlab
options = mcr('options');
model = mcr(x, ncomp, options);
pred = mcr(x_new, model, options);
```

### Cross-validation (function form)

```matlab
[press, cumpress, rmsecv, rmsec, cvpred] = crossval(x, y, 'sim', cvi, ncomp);
% Or pass a model to add CV results:
model = crossval(x, y, model, cvi, ncomp);
```

### Function form I/O summary

| Function | Calibrate | Predict | Validate |
|----------|-----------|---------|----------|
| `pca` | `model = pca(x, ncomp, opts)` | `pred = pca(x_new, model, opts)` | — |
| `pls` | `model = pls(x, y, ncomp, opts)` | `pred = pls(x_new, model, opts)` | `v = pls(x, y, model, opts)` |
| `pcr` | `model = pcr(x, y, ncomp, opts)` | `pred = pcr(x_new, model, opts)` | `v = pcr(x, y, model, opts)` |
| `plsda` | `model = plsda(x, y, ncomp, opts)` | `pred = plsda(x_new, model, opts)` | `v = plsda(x, y, model, opts)` |
| `mcr` | `model = mcr(x, ncomp, opts)` | `pred = mcr(x_new, model, opts)` | — |
| `mlr` | `model = mlr(x, y, opts)` | `pred = mlr(x_new, model, opts)` | — |

### Function form options structure

Each function returns its default options via `funcname('options')`:

```matlab
options = pls('options');
% Common fields:
%   .display        'on' or 'off'
%   .plots          'final' or 'none'
%   .preprocessing  cell of preprocessing structs ({x_pp} or {x_pp, y_pp})
%   .algorithm      method-specific algorithm string
%   .blockdetails   'compact' or 'standard' (whether to store x-data in model)
%   .confidencelimit  0.95 (default confidence level)
```

---

## Quick Reference: OO vs Function Form

| Task | OO Form (Preferred) | Function Form |
|------|---------------------|---------------|
| Create model | `m = evrimodel('pca')` | — |
| Set data | `m.x = data` | passed as argument |
| Set components | `m.ncomp = 5` | passed as argument |
| Set preprocessing | `opts = m.options; opts.preprocessing{1} = pp; m.options = opts;` | `opts.preprocessing = {pp}` |
| Calibrate | `m = m.calibrate` | `m = pca(x, ncomp, opts)` |
| Cross-validate | `m = m.crossvalidate` | `crossval(x, y, 'sim', cvi, ncomp)` |
| Apply | `p = m.apply(x_new)` | `p = pca(x_new, m)` |
| Get scores | `m.scores` | `m.loads{1,1}` |
| Get loadings | `m.loadings` | `m.loads{2,1}` |
| Plot scores | `m.plotscores` | `plotscores(m)` or manually |
| Suppress output | `m.display = 'off'` | `opts.display = 'off'` |
| Suppress plots | `m.plots = 'none'` | `opts.plots = 'none'` |

## Common Patterns

### Build, cross-validate, and save a PLS model

```matlab
model = evrimodel('pls');
model.x = xdata;
model.y = ydata;
model.ncomp = 15;
model.display = 'off';
model.plots = 'none';
opts = model.options;
opts.preprocessing{1} = [preprocess('default', 'snv'), preprocess('default', 'mean center')];
opts.preprocessing{2} = preprocess('default', 'mean center');
model.options = opts;
model = model.crossvalidate;
save('my_pls_model.mat', 'model');
```

### Load a model and apply to new data

```matlab
load('my_pls_model.mat', 'model');
pred = model.apply(x_new);
y_pred = pred.prediction;
```

### Batch-apply a model to multiple datasets

```matlab
load('my_model.mat', 'model');
results = cell(1, numel(file_list));
for i = 1:numel(file_list)
    x = load_data(file_list{i});     % User's data loading function
    pred = model.apply(x);
    results{i} = pred.prediction;
end
```

### Compare multiple component counts

```matlab
model = evrimodel('pls');
model.x = xdata;
model.y = ydata;
model.display = 'off';
model.plots = 'none';
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');
opts.preprocessing{2} = preprocess('default', 'mean center');
model.options = opts;

for nc = 1:20
    model.ncomp = nc;
    model = model.crossvalidate;
    rmsecv(nc) = model.detail.rmsecv(nc);
end
plot(1:20, rmsecv, '-o'); xlabel('Components'); ylabel('RMSECV');
```
