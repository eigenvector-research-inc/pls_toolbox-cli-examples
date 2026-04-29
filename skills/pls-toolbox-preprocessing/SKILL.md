---
name: pls-toolbox-preprocessing
description: Reference for PLS_Toolbox PREPROCESS function in MATLAB. Use when the user needs to build preprocessing structures, apply preprocessing to data (mean centering, autoscaling, SNV, derivatives, normalization, baseline correction, etc.), set up preprocessing for model objects, or undo preprocessing. Provides structure format, keywords, calibrate/apply/undo workflow, and integration with EVRIModel objects.
---

# PLS_Toolbox Preprocessing Reference

The `preprocess` function is the central tool for selecting, calibrating, applying, and undoing preprocessing in Eigenvector's PLS_Toolbox. Preprocessing is stored as a **structure array** where each record represents one preprocessing step, applied in sequence.

Documentation: https://wiki.eigenvector.com/index.php?title=Preprocess

## Core Workflow: Calibrate / Apply / Undo

Preprocessing has three phases:

1. **Calibrate** - Estimate preprocessing parameters from calibration data and preprocess it.
2. **Apply** - Apply the calibrated preprocessing to new data (using stored parameters).
3. **Undo** - Reverse the preprocessing on preprocessed data.

```matlab
% 1. Create a preprocessing structure
s = preprocess('default', 'autoscale');

% 2. Calibrate on training data (estimates mean, std, etc.)
[x_cal_pp, sp] = preprocess('calibrate', s, x_cal);

% 3. Apply to new data (uses calibration parameters)
x_new_pp = preprocess('apply', sp, x_new);

% 4. Undo preprocessing (reverse the transformation)
x_original = preprocess('undo', sp, x_new_pp);
x_original = preprocess('undo_silent', sp, x_new_pp);  % Suppress warnings for irreversible steps
```

IMPORTANT: The output `sp` from `'calibrate'` is the **calibrated** structure — it contains the learned parameters in its `.out` field. You must use `sp` (not the original `s`) for `'apply'` and `'undo'`. If you use the original uncalibrated `s`, you will get an error: "Preprocessing must be calibrated before applying or undoing".

## Creating Preprocessing Structures

### Method 1: Using `preprocess('default', keyword)`  (PREFERRED for scripting)

```matlab
s = preprocess('default', 'mean center');      % Single method
s = preprocess('default', 'autoscale');         % Single method
s = preprocess('default', 'snv');              % Single method
```

### Method 2: Using shortcut strings in calibrate (simple cases only)

```matlab
[datap, sp] = preprocess('calibrate', 'mean center', data);
[datap, sp] = preprocess('calibrate', 'autoscale', data);
```

### Method 3: Interactive GUI

```matlab
s = preprocess;              % Opens GUI, returns structure on OK
[s, changed] = preprocess(s); % Edit existing structure in GUI
```

### Method 4: Build structure manually

```matlab
pp.description   = 'Mean Center';
pp.calibrate     = {'[data,out{1}] = mncn(data);'};
pp.apply         = {'data = scale(data,out{1});'};
pp.undo          = {'data = rescale(data,out{1});'};
pp.out           = {[]};
pp.settingsgui   = '';
pp.settingsonadd = 0;
pp.usesdataset   = 0;
pp.caloutputs    = 1;
pp.keyword       = 'meancenter';
pp.tooltip       = 'Remove mean offset from each variable';
pp.category      = 'Scaling and Centering';
pp.userdata      = [];
```

### Method 5: List all available keywords

```matlab
preprocess('keywords')           % Display all valid method keywords
list = preprocess('initcatalog'); % Returns full catalog structure array
```

## Multi-Step Preprocessing

Concatenate structures to create a multi-step preprocessing pipeline. Steps execute in order during calibrate/apply and in reverse order during undo.

```matlab
s1 = preprocess('default', 'snv');
s2 = preprocess('default', 'mean center');
s = [s1 s2];    % SNV first, then mean center

[datap, sp] = preprocess('calibrate', s, data);
```

## Preprocessing Structure Fields

Each record in a preprocessing structure array contains:

| Field | Type | Description |
|-------|------|-------------|
| `.description` | string | Human-readable name (e.g., `'Mean Center'`) |
| `.calibrate` | cell of strings | MATLAB code to execute during calibration |
| `.apply` | cell of strings | MATLAB code to execute during apply (defaults to calibrate if empty) |
| `.undo` | cell of strings | MATLAB code to execute during undo (empty = not undoable) |
| `.out` | cell | Storage for calibration parameters (means, stds, etc.). Populated during calibrate. |
| `.settingsgui` | string | Name of settings GUI function (empty = no settings) |
| `.settingsonadd` | 0 or 1 | 1 = show settings GUI when adding to list |
| `.usesdataset` | 0 or 1 | 1 = pass full DSO to method; 0 = pass raw numeric matrix |
| `.caloutputs` | integer | Number of calibration outputs to store (0 = none needed) |
| `.keyword` | string | Short keyword identifier (used by `preprocess('default', keyword)`) |
| `.tooltip` | string | Descriptive tooltip text |
| `.category` | string | Category grouping (e.g., `'Scaling and Centering'`, `'Normalization'`) |
| `.userdata` | any | Method-specific settings/parameters |

### How `.calibrate` / `.apply` / `.undo` work

These fields contain MATLAB code strings that are `eval`'d with these variables in scope:

- `data` - the data being processed (numeric matrix or DSO depending on `.usesdataset`)
- `out` - cell array for storing/retrieving calibration parameters (e.g., `out{1}` = means)
- `userdata` - method-specific settings from `.userdata`
- `include` - cell of include indices

Example — Mean Center:
```
calibrate: '[data,out{1}] = mncn(data);'     % mncn returns mean-centered data + mean vector
apply:     'data = scale(data,out{1});'       % scale uses the stored mean
undo:      'data = rescale(data,out{1});'     % rescale reverses it
```

## Available Preprocessing Methods (Keywords)

### Scaling and Centering
| Keyword | Description | Function |
|---------|-------------|----------|
| `'mean center'` | Center columns to zero mean | `mncn` |
| `'median center'` | Center columns to zero median | `medcn` |
| `'autoscale'` | Mean center + scale to unit variance | `auto` |
| `'autoscalenomean'` | Variance (std) scaling only, no mean centering | `auto` |
| `'pareto'` | Pareto scaling (sqrt of std) | `auto` |
| `'classcenter'` | Center each class to its own mean | `classcenter` |
| `'classcentroid'` | Center data to centroid of all classes | `classcentroid` |
| `'classcentroidscale'` | Center to centroid + scale to intra-class variance | `classcentroid` |
| `'minmax'` | Min-max scaling (0 to 1) | `minmax` |

### Normalization
| Keyword | Description | Function |
|---------|-------------|----------|
| `'normalize'` | Row normalization | `normaliz` |
| `'snv'` | Standard Normal Variate (autoscale rows) | `snv` |
| `'msc'` | Multiplicative Scatter Correction (mean reference) | `mscorr` |
| `'msc_median'` | MSC with median reference | `mscorr` |
| `'emsc'` | Extended MSC | `emscorr` |
| `'PQN'` | Probabilistic Quotient Normalization | `pqnorm` |
| `'sqmnsc'` | Poisson (sqrt mean) scaling | `poissonscale` |

### Filtering and Smoothing
| Keyword | Description | Function |
|---------|-------------|----------|
| `'smooth'` | Savitzky-Golay smoothing | `savgol` |
| `'derivative'` | Savitzky-Golay derivative across rows | `savgol` |
| `'derivative columns'` | Savitzky-Golay derivative down columns | `savgol` |
| `'gapsegment'` | Gap-segment derivatives | `gapsegment` |
| `'window_filter'` | Spectral filtering | `windowfilter` |

### Baseline Correction
| Keyword | Description | Function |
|---------|-------------|----------|
| `'baseline'` | Baseline correction using user-specified points | `baseline` |
| `'whittaker'` | Automatic Whittaker filter baseline | `wlsbaseline` |
| `'detrend'` | Remove linear trend | `baseline` |

### Transformations
| Keyword | Description | Function |
|---------|-------------|----------|
| `'log10'` | Base 10 logarithm | `log10` |
| `'abs'` | Absolute value | `abs` |
| `'trans2abs'` | Transmission to absorbance (log(1/T)) | - |
| `'arithmetic'` | Simple arithmetic operations | `arithmetic` |
| `'haar'` | Haar transform | - |

### Advanced Methods
| Keyword | Description | Function |
|---------|-------------|----------|
| `'osc'` | Orthogonal Signal Correction (requires y-block) | `osccalc`, `oscapp` |
| `'gls weighting'` | Generalized Least Squares weighting (requires y-block) | `glsw` |
| `'epo'` | External Parameter Orthogonalization | `glsw` |
| `'specalign'` | Variable alignment | `cow`, `registerspec` |
| `'gscale'` | Group/block scaling | `gscale` |
| `'logdecay'` | Log decay scaling | - |
| `'referencecorrection'` | Reference/background correction | - |
| `'centering'` | Multiway centering | - |
| `'scaling'` | Multiway scaling | - |
| `'holoreact'` | Kaiser HoloReact method | `hrmethodreadr` |
| `'eemfilter'` | EEM fluorescence filtering | - |

### MIA_Toolbox Methods (require MIA_Toolbox)
| Keyword | Description |
|---------|-------------|
| `'Image_Flatfield'` | Background subtraction (flatfield) |
| `'Image_Close'` | Morphological close |
| `'Image_Dilate'` | Morphological dilate |
| `'Image_Erode'` | Morphological erode |
| `'Image_Max'` | Replace pixel window with max |
| `'Image_Mean'` | Replace pixel window with mean |
| `'Image_Median'` | Replace pixel window with median |
| `'Image_Min'` | Replace pixel window with min |
| `'Image_Open'` | Morphological open |
| `'Image_Smooth'` | Image smoothing |

## Multi-Block Preprocessing (OSC, GLS Weighting)

Some methods require both x-block and y-block data:

```matlab
s = preprocess('default', 'osc');
[xp, sp] = preprocess('calibrate', s, xblock, yblock);
```

## Integration with EVRIModel Objects

See the `pls-toolbox-model-object` skill for full model object documentation.

### Setting preprocessing on an uncalibrated model

Preprocessing is set via `model.options.preprocessing`, which is a cell array with one entry per data block (block 1 = x-block, block 2 = y-block). You must get the options struct, modify it, then assign it back:

```matlab
% Build preprocessing structure
s = preprocess('default', 'mean center');
% Or multi-step:
s = [preprocess('default', 'snv'), preprocess('default', 'mean center')];

% Create and configure model
model = evrimodel('pca');
model.x = data;
model.ncomp = 5;

% Assign preprocessing to x-block (block 1) via options
opts = model.options;
opts.preprocessing{1} = s;
model.options = opts;

% Calibrate (preprocessing is applied automatically)
model = model.calibrate;
```

### Assigning preprocessing to y-block (regression models)

```matlab
model = evrimodel('pls');
model.x = xdata;
model.y = ydata;
model.ncomp = 3;

% Set preprocessing for both blocks via options
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');    % X-block
opts.preprocessing{2} = preprocess('default', 'mean center');  % Y-block
model.options = opts;

model = model.calibrate;
```

IMPORTANT: Do NOT use `model.detail.preprocessing{1} = ...` to set preprocessing before calibration — this will not work correctly. Always use `model.options.preprocessing`.

### Extracting calibrated preprocessing from a model

After calibration, the preprocessing structures stored in the model are the **calibrated** versions (with `.out` populated):

```matlab
% Extract calibrated preprocessing
cal_pp = model.detail.preprocessing{1};   % X-block preprocessing (calibrated)

% Apply same preprocessing to external data
x_new_pp = preprocess('apply', cal_pp, x_new);

% Undo preprocessing (e.g., on predictions)
y_unscaled = preprocess('undo', model.detail.preprocessing{2}, y_pred);
```

### Using model.apply() (preferred)

When using `model.apply(x_new)`, preprocessing is handled automatically — you don't need to manually preprocess the new data. The model applies its stored preprocessing during the apply step.

```matlab
pred = model.apply(x_new);    % Preprocessing applied automatically
```

## Modifying Preprocessing Settings via .userdata

Many methods have configurable settings stored in `.userdata`. Modify these after creating the default structure:

```matlab
% Savitzky-Golay derivative with custom settings
s = preprocess('default', 'derivative');
s.userdata.order = 2;        % 2nd derivative
s.userdata.window = 15;      % Window size
s.userdata.polyorder = 2;    % Polynomial order

% Normalization with specific norm type
s = preprocess('default', 'normalize');
s.userdata.type = 1;         % 1-norm (area normalization)

% MSC with specific reference spectrum
s = preprocess('default', 'msc');
% (reference is computed from calibration data by default)
```

To see available settings for a method, use the GUI:
```matlab
s = preprocess('default', 'derivative');
s = preprocess(s);  % Opens GUI to inspect/modify settings
```

## Common Patterns

### Typical spectral preprocessing pipeline

```matlab
s1 = preprocess('default', 'derivative');     % 1st derivative
s2 = preprocess('default', 'snv');            % SNV normalization
s3 = preprocess('default', 'mean center');    % Mean center
s = [s1 s2 s3];

[xp, sp] = preprocess('calibrate', s, x_cal);
x_new_pp = preprocess('apply', sp, x_new);
```

### Quick autoscale for PCA

```matlab
model = evrimodel('pca');
model.x = data;
model.ncomp = 5;
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');
model.options = opts;
model = model.calibrate;
```

### Quick mean center for PLS

```matlab
model = evrimodel('pls');
model.x = xdata;
model.y = ydata;
model.ncomp = 10;
opts = model.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');
opts.preprocessing{2} = preprocess('default', 'mean center');
model.options = opts;
model = model.crossvalidate;
```

### Standalone preprocessing without a model

```matlab
% Preprocess data directly
[x_pp, sp] = preprocess('calibrate', 'autoscale', x_cal);
x_test_pp = preprocess('apply', sp, x_test);
```

### Inspecting what preprocessing a model used

```matlab
pp = model.detail.preprocessing{1};
for i = 1:length(pp)
    fprintf('Step %d: %s\n', i, pp(i).description);
end
```

## Troubleshooting

### "Preprocessing must be calibrated before applying or undoing"
You passed the original (uncalibrated) structure `s` to `'apply'` instead of the calibrated structure `sp` returned by `'calibrate'`. Always use the second output of `preprocess('calibrate', ...)`.

### Some preprocessing cannot be undone
Methods like `'osc'` and derivatives do not have defined inverse operations. Using `'undo'` on these will produce a warning. Use `'undo_silent'` to suppress.

### Wrong keyword
Use `preprocess('keywords')` to see all valid keywords. Keywords are case-insensitive. Common mistakes: `'meancenter'` works, `'mean_center'` does not (use `'mean center'` with a space).
