---
name: pls-toolbox-dataset
description: Reference for PLS_Toolbox DataSet Objects (DSO) in MATLAB. Use when the user is working with Eigenvector PLS_Toolbox dataset objects, spectral data, chemometrics, or multivariate analysis in MATLAB. Provides field definitions, methods, creation patterns, and assignment syntax.
---

# PLS_Toolbox DataSet Object (DSO) Reference

The DataSet Object (DSO) is the core data container in Eigenvector's PLS_Toolbox for MATLAB. It bundles numeric data with labels, classes, axis scales, and metadata in a single object.

Documentation: https://www.eigenvectordocs.com/index.php?title=DataSet_Object

To get help on any DSO method: `help dataset/method` (e.g., `help dataset/updateset`)

## Creating a DSO

```matlab
mydata = dataset(rand(10,5));          % From a matrix
mydata = dataset;                       % Empty DSO
mydata.data = my_matrix;                % Assign data after creation
```

IMPORTANT: The constructor is `dataset()` (lowercase). The class name is `dataset`. The Eigenvector DSO is NOT the same as the MathWorks Statistics Toolbox `dataset` — they are incompatible.

### Creating a 3-Way DSO

```matlab
% From an existing 3-way array
dso3way = dataset(x3way);

% From multiple 2-way arrays (modes 1 and 2 must have same size)
dso3way = dataset(zeros(4, 2, 10));    % Pre-allocate: 4 samples, 2x10 per sample
dso3way.data(1,:,:) = x1;
dso3way.data(2,:,:) = x2;
dso3way.data(3,:,:) = x3;
dso3way.data(4,:,:) = x4;             % Can append beyond pre-allocated size
```

### Displaying a DSO

```matlab
>> wine                 % Typing the variable name calls disp()
wine =
  name: Wine
  type: data
  author: B.M. Wise
  data: 10x5 [double]
  label: {2x1} ...
  ...
```

## Modes and Sets

DSOs use a **mode/set** indexing system:
- **Mode** = dimension of the data (mode 1 = rows/samples, mode 2 = columns/variables, mode 3+ for multiway)
- **Set** = multiple label/class/axisscale entries per mode (set 1, set 2, etc.)

All label-like fields use `{mode, set}` cell indexing.

Convention: mode 1 = rows (samples/observations), mode 2 = columns (variables/measurements). For multi-block analyses, mode 1 is the common dimension (e.g., samples).

## Fields Reference

### .data
The numeric matrix. Standard MATLAB indexing applies.
```matlab
mydata.data                    % Full matrix
mydata.data(:,1)               % First column
mydata.data.include            % Only included data (read-only shortcut)
```
Supported types: double, single, logical, int8/16/32, uint8/16/32.

For `type='batch'`: `.data` is a cell array where each cell can have variable-length first mode. Extract a single batch with: `batch_1 = allbatches{1}` (returns a full DSO with fields reduced to that batch).

### .size / .sizestr
Convenience fields (read-only):
```matlab
mydata.size        % Returns vector, e.g. [10 5]
mydata.sizestr     % Returns string, e.g. '10x5'
```

### .label {M x S_lbls} — Sample/Variable Labels
Character arrays identifying rows or columns. Each mode can have multiple label sets.
```matlab
mydata.label{1,1}              % Mode 1 (row) labels, set 1
mydata.label{2,1}              % Mode 2 (column) labels, set 1
mydata.label{1,2}              % Mode 1 labels, set 2
```

**Assigning labels:** Accepts char arrays or cell arrays of strings. Always stored and returned as char arrays.
```matlab
mydata.label{1,1} = char({'SampleA','SampleB','SampleC'});   % Char array
mydata.label{1,1} = {'France','Italy','Mexico'};              % Cell array (auto-converted)
mydata.label{1,2}{2} = 'New second label';                    % Single label in set 2
```

### .labelname {M x S_lbls} — Label Set Names
Descriptive name for each label set.
```matlab
mydata.labelname{1,1} = 'Countries';     % Name the first label set for mode 1
mydata.labelname{1,2} = 'Work Order';    % Name the second label set
```

### .class {M x S_class} — Numeric Class Assignments
Numeric vectors grouping samples/variables into classes.
```matlab
mydata.class{1,1}              % Class assignments for mode 1, set 1 (ALWAYS numeric)
mydata.class{1,1} = [1 1 2 2 3 3]';  % Assign numeric classes
mydata.class{1,1} = {'A','A','B','B'}'; % Also accepts strings (stored as numbers internally)
```

IMPORTANT: Assignment accepts BOTH numeric vectors and string cell arrays. Retrieval from `.class` ALWAYS returns numeric values. Use `.classid` to retrieve as strings.

### .classid {M x S_class} — String Class Assignments
Pseudonym for `.class` that accepts and returns string cell arrays instead of numbers.
```matlab
mydata.classid{1,1}            % Class assignments as strings
mydata.classid{1,1} = {'TypeA','TypeA','TypeB','TypeB'}';  % Assign string classes
```

IMPORTANT: `.class` and `.classid` access the same underlying data. `.class` returns numbers, `.classid` returns strings.

### .classname {M x S_class} — Class Set Names
Descriptive name for each class set.
```matlab
mydata.classname{1,1} = 'Sample Type';  % Name the first class set
mydata.classname{1,2} = 'Batch ID';     % Name the second class set
```

### .classlookup {M x S_class} — Class Number-to-Name Mapping
Lookup table (k x 2 cell array) mapping numeric class values to string names.
```matlab
mydata.classlookup{1,1}                          % View lookup table
mydata.classlookup{1,1}.find(2)                   % Get name for class number 2
mydata.classlookup{1,1}.find('SomeClass')          % Get number for class name
mydata.classlookup{1,1}.assignstr = {3, 'NewName'};  % Change class 3's label
mydata.classlookup{1,1}.assignval = {18, 'OldName'}; % Change number for 'OldName'
```

**Bulk editing:** Extract, modify, and reassign the entire table:
```matlab
a = mydata.classlookup{1};
a{3,2} = 'NewLabel';
mydata.classlookup{1} = a;
```

WARNING: If you replace the entire lookup table, any class number in `.class` that does not appear in the new table will be reset to class 0.

### .axisscale {M x S_scale} — Axis Scales
IMPORTANT: Must be numeric vectors (class double). Used for wavelengths, time points, etc.
```matlab
mydata.axisscale{2,1} = wavenumbers;     % Assign wavenumber axis to mode 2
mydata.axisscale{1,1} = (1:n_samples)';  % Numeric index for mode 1
mydata.axisscale{3,1} = 1:10;            % Third mode axis scale
```

For `type='batch'`: Mode 1 axisscale entries are cell arrays (variable-length per batch). Other modes are standard vectors.

For dates, convert to datenum: `mydata.axisscale{1,1} = datenum(date_strings, 'mm/dd/yy');`
Convert back with: `datestr(mydata.axisscale{1,1})`

### .axisscalename {M x S_scale} — Axis Scale Names
```matlab
mydata.axisscalename{2,1} = 'Wavenumber (cm-1)';
mydata.axisscalename{1,1} = 'Coating Date';
```

### .axistype {M x S_scale} — Axis Type
Informational field describing the relationship between adjacent elements. Values:
- `'none'` — (default) relationship unknown
- `'discrete'` — unrelated items, show as individual points
- `'stick'` — discrete but connected to zero (stick plot)
- `'continuous'` — points on a continuous axis, can interpolate

Used by plotting commands. When concatenating DSOs with different axistypes, the least-presumptive type is used (none > discrete > stick > continuous).

### .title {M x S_title} — Mode Titles
General descriptor for each mode (e.g., what the rows/columns represent).
```matlab
mydata.title{1} = 'Country';          % Title for mode 1 (rows)
mydata.title{2} = 'Variable';         % Title for mode 2 (columns)
```

### .titlename {M x S_title} — Title Names
Names for each title set.
```matlab
mydata.titlename{1,1} = 'Mode 1 Title';
```

### .include {M x 1} — Soft Exclusion
Indices of included samples/variables. Enables "soft delete" without removing data.
```matlab
mydata.include{1}              % Included row indices (default: 1:N1)
mydata.include{2}              % Included column indices (default: 1:N2)
mydata.include{1} = [1 3 5 7]; % Only include these rows
```

Access only included data: `mydata.data.include` (read-only, cannot assign through this).

### .name — Dataset Name
```matlab
mydata.name = 'FTIR Spectra';
```

### .type — Dataset Type
Valid values: `'data'`, `'image'`, `'batch'`
```matlab
mydata.type = 'data';          % Standard fixed-size data
```
Setting `type='image'` enables image-specific fields. Setting `type='batch'` allows cell array `.data`.

### .author, .date, .moddate, .description, .history, .uniqueid
```matlab
mydata.author = 'Lab Operator';
mydata.description = 'FTIR spectra from production run';
mydata.description = {'Line 1', 'Line 2'};   % Can be cell array of strings
mydata.history = 'Imported from CSV';  % Appends timestamped entry
% e.g., "%%% Comment: Imported from CSV. (08-Sep-2009 17:14:52.538)"
mydata.date      % [year month day hour minute second] of creation
mydata.moddate   % [year month day hour minute second] of last modification
mydata.uniqueid  % Read-only unique identifier string
```

### .userdata — Custom Storage
Any data type. Becomes a cell array when DSOs are concatenated.
```matlab
mydata.userdata = struct('notes', 'extra info', 'params', [1 2 3]);
```

## Image-Specific Fields (when .type = 'image')

### .imagemode — Which mode contains spatial data
Scalar indicating which mode of `.data` holds the unfolded spatial pixels.
```matlab
imgdso.imagemode = 1;          % Spatial data is in mode 1 (typical)
```

### .imagesize / .imagesizestr — Original spatial dimensions
```matlab
imgdso.imagesize = [768 512];  % Original image was 768x512 pixels
imgdso.imagesizestr            % Returns '768x512'
```
Product of `.imagesize` must equal `size(.data, .imagemode)`.

### .foldedsize / .foldedsizestr — Full folded array size
Respects `.imagemode`. If image unfolded into mode 2: `foldedsize = [3 768 512]`.

### .imagedata — Read-only refolded image data
Returns `.data` refolded to original image dimensions (spatial dims first).
```matlab
img = imgdso.imagedata;        % Returns e.g. 768x512x3 from 393216x3
```
Read-only: changes to `.data` are reflected, but cannot write to `.imagedata`.

### .imagedataf — Read-only refolded data respecting imagemode
Like `.imagedata` but inserts spatial dims at the `.imagemode` position.
If `imagemode=2` and data is 3x62500: `.imagedataf` returns 3x250x250 while `.imagedata` returns 250x250x3.

### .imageaxisscale / .imageaxisscalename / .imageaxistype
Axis scales for spatial image dimensions (one entry per image mode).
```matlab
imgdso.imageaxisscale{1} = [1:768]/10;    % Scale for first spatial dim
imgdso.imageaxisscale{2} = [1:512]/10;    % Scale for second spatial dim
```

### Creating an Image DSO
```matlab
dat = imread('image.jpeg','jpeg');     % e.g. 768x512x3
sz = size(dat);
x = reshape(dat, sz(1)*sz(2), sz(3)); % Unfold spatial dims
imgdso = dataset(double(x));
imgdso.type = 'image';
imgdso.imagemode = 1;
imgdso.imagesize = sz(1:2);
```
With MIA_Toolbox: `imgdso = buildimage(dat, [1 2], 1);`

## Indexing into DSOs

### Standard MATLAB indexing
```matlab
sub = mydata(3,:);             % Row 3 as a new DSO (all fields sliced)
sub = mydata(:,1:3);           % First 3 columns as a new DSO
```

### Label-based indexing (dot notation)
```matlab
sub = mydata.sensor;                   % Column labeled 'sensor'
sub = mydata.('sensor number 2');      % Label with spaces/special characters
```
Restrictions: label must not match a DSO field/method name. Use `()` syntax for labels with special characters.

### Indexing using set names
Class and label set names can be used with dot notation:
```matlab
mylabels = wine.Country        % Returns labels from the set named 'Country'
```
Note: class names are checked first, then label names.

### Class-based extraction
```matlab
sub = mydata('myclass');               % All samples belonging to 'myclass'
sub = mydata('myclass').include;       % Only included samples of 'myclass'
```

### Accessing included data
```matlab
included_data = mydata.data.include;   % Numeric matrix with excluded rows/cols removed
```

### Batch DSO indexing
```matlab
batch_1 = allbatches{1};              % Extract first batch as a full DSO
```

## The updateset Method

The preferred way to add/update label, class, or axisscale sets with automatic naming.

```matlab
% Syntax:
dso = updateset(dso, 'field', mode, value);
dso = updateset(dso, 'field', mode, value, 'SetName');
dso = updateset(dso, 'class', mode, class_values, 'SetName', classlookup);
```

**field** can be: `'label'`, `'class'`, `'axisscale'`

When `'SetName'` is provided:
- If a set with that name exists, it is overwritten
- If not, a new set is created with that name

When `'SetName'` is omitted:
- Values go into the first empty set, or appended as a new set

### updateset Examples

```matlab
% Add row labels named 'File'
dso = updateset(dso, 'label', 1, char(file_names), 'File');

% Add column labels named 'Wavenumber'
dso = updateset(dso, 'label', 2, char(wn_labels), 'Wavenumber');

% Add a class set named 'Type' using string cell array
dso = updateset(dso, 'class', 1, cellstr(type_values), 'Type');

% Add a numeric axisscale named 'Wavelength'
dso = updateset(dso, 'axisscale', 2, wavelength_vector, 'Wavelength');

% Add axisscale for dates (must be numeric — use datenum)
dso = updateset(dso, 'axisscale', 1, datenum(date_strings, 'mm/dd/yy'), 'Date');
```

## Overloaded Math Operators

These operate on the `.data` field only (no effect on other fields):
- `+` (plus), `-` (minus), `.*` (times), `./` (rdivide), `.\` (ldivide)
- `double(dso)` — convert to double, `single(dso)` — convert to single

## All Methods

| Method | Purpose |
|--------|---------|
| `updateset(dso, field, mode, value, name)` | Add/update a label, class, or axisscale set |
| `cat(dim, dso1, dso2)` | Generic concatenation of DSOs |
| `horzcat(dso1, dso2)` or `[dso1 dso2]` | Horizontal concatenation (add variables) |
| `vertcat(dso1, dso2)` or `[dso1; dso2]` | Vertical concatenation (add samples) |
| `augment(dso1, dso2)` | Concatenate and add distinguishing class |
| `delsamps(dso, indices, mode)` | Delete or exclude samples/variables |
| `sortrows(dso)` / `sortcols(dso)` | Sort by rows or columns |
| `sortby(dso, field, mode, set)` | Sort by a specific field |
| `squeeze(dso)` | Remove singleton dimensions |
| `permute(dso, order)` | Permute dimensions |
| `reshape(dso, newsize)` | Reshape DSO |
| `repmat(dso, reps)` | Replicate and tile a DSO |
| `transpose(dso)` or `dso'` | Transpose (2-way only) |
| `explode(dso)` | Extract all fields as separate workspace variables |
| `findset(dso, field, mode, name)` | Find a set index by name |
| `listsets(dso, field, mode)` | List available sets for a field/mode |
| `rmset(dso, field, mode, set)` | Remove a set |
| `search(dso, field, mode, set, term)` | Search for a term in a field |
| `anyexcluded(dso)` | Check if any elements are excluded |
| `unique(dso)` | Return DSO with unique values |
| `disp(dso)` | Display summary of DSO contents |
| `get(dso, field)` | Get field values |
| `set(dso, field, value)` | Set field values |
| `size(dso)` / `length(dso)` / `ndims(dso)` | Data dimensions |
| `isempty(dso)` | Check if data field is empty |
| `numel(dso)` | Always returns 1 |

## Common Data Type Requirements

| Field | Required Type | Notes |
|-------|--------------|-------|
| `.label` | char array | Use `char()` to convert cell arrays; accepts cell array of strings on assignment |
| `.class` | numeric vector | Accepts strings or numbers on assignment; ALWAYS returns numbers |
| `.classid` | cell array of strings | Pseudonym for `.class`; returns strings |
| `.axisscale` | numeric vector (double) | Dates must use `datenum()` |

## Common Patterns

### Full DSO construction from scratch
```matlab
wined = dataset(dat);
wined.name = 'Wine';
wined.author = 'A.E. Newman';
wined.description = {'Wine, beer, and liquor consumption'};
wined.label{1} = {'France','Italy','Switz','Austra','Mexico'};
wined.label{2} = {'Liquor','Wine','Beer','LifeExp','HeartD'};
wined.labelname{1} = 'Countries';
wined.labelname{2} = 'Variables';
wined.title{1} = 'Country';
wined.title{2} = 'Variable';
wined.class{1} = [1 1 1 2 3];
wined.classname{1} = 'Continent';
wined.axisscale{2} = [1:5];
wined.axisscalename{2} = 'Variable Number';
```

### Import spectra and add metadata from a CSV lookup table
```matlab
% 1. Read CSV
LUT = readtable('metadata.csv', 'TextType', 'string');

% 2. Match by file name (label{1} = file names)
dso_labels = cellstr(mydata.label{1});

% 3. Loop and match
for i = 1:length(dso_labels)
    idx = find(strcmp(LUT.File, strtrim(dso_labels{i})));
    if ~isempty(idx)
        % extract values from LUT row idx
    end
end

% 4. Use updateset to add matched metadata
mydata = updateset(mydata, 'label', 1, char(wo_values), 'WO');
mydata = updateset(mydata, 'class', 1, cellstr(type_values), 'Type');
mydata = updateset(mydata, 'axisscale', 1, datenum_values, 'Date');
```

### Auto-detect CSV column names
When CSV column names vary (e.g., 'File' vs 'Folder / Folder'), use `contains()` for flexible matching:
```matlab
col_names = LUT.Properties.VariableNames;
file_col = col_names{contains(lower(col_names), 'file') | contains(lower(col_names), 'folder')};
```
