%==========================================================================
%  PCA EXAMPLE — Principal Component Analysis (exploratory, unsupervised)
%
%  Dataset    : Block A uses `wine` (small EVRI demo — wine/beer/liquor
%               consumption by country); Block B uses `arch` (XRF
%               archaeology data, 4 quarry classes + unknowns). Both ship
%               with PLS_Toolbox in toolbox/dems/.
%  Model      : PCA via evrimodel('pca')
%
%  You will learn
%  --------------
%  1. The OO EVRIModel workflow: create empty model, assign data, set
%     preprocessing via the options struct, calibrate, inspect results.
%  2. How to choose the number of components from the scree plot.
%  3. How to read scores, loadings, T2 (Hotelling), and Q residuals, and
%     use them to detect outliers via the 95% confidence limits.
%  4. How to project NEW data through a calibrated PCA model with .apply.
%
%  Why two side-by-side blocks?
%  ----------------------------
%  Block A is intentionally tiny so you can see every sample and follow
%  the math by eye. Block B is the dataset the LDA / PLSDA / SVMDA scripts
%  later model — running PCA on it first reveals the class structure that
%  classifiers will exploit. You can comment out either block; they are
%  independent.
%
%  Prerequisites
%  -------------
%  - MATLAB (base only — no MathWorks toolboxes required)
%  - PLS_Toolbox v9.0+ on the MATLAB path:  addpath(genpath('<your_path>/pls_toolbox'));
%
%  How to adapt this script to your data
%  -------------------------------------
%  Search for the marker:   % >>> USER:
%  Each marker indicates a place where you should swap in your own data,
%  preprocessing, or hyperparameters.
%
%  Author : EVRI CLI Examples
%  Date   : 2026-04-29
%==========================================================================

clear; clc; close all;

rng(0, 'twister');                           % >>> USER: change seed to vary any random splits.

% Plot styling shared across all examples in this series.
set(groot, 'defaultAxesFontSize', 11);
set(groot, 'defaultLineLineWidth', 1.4);
plotcolors = lines(7);                        %#ok<NASGU>


%% ========================================================================
%  Block A — PCA on the small `wine` dataset (transparent first pass)
%% ========================================================================

%% ------------------------------------------------------------------------
%  Step A.1 — Load and inspect data
%% ------------------------------------------------------------------------
% Loading a PLS_Toolbox demo dataset puts a DataSet Object (DSO) in the
% workspace. A DSO bundles the numeric matrix with labels, classes, and
% axis scales. Its core fields are:
%   .data        - the numeric matrix
%   .label{m,s}  - sample (m=1) or variable (m=2) labels for set s
%   .class{m,s}  - numeric class assignments
%   .axisscale   - axis values (e.g., wavenumbers)
% Typing the variable name calls disp() and gives a structured summary.

% >>> USER: replace `wine` with your own DataSet Object (use `dataset(myMatrix)` to wrap a plain matrix).
load wine
disp('--- Wine DSO ---');
disp(wine);

%% ------------------------------------------------------------------------
%  Step A.2 — Define preprocessing
%% ------------------------------------------------------------------------
% Why autoscale (mean center + unit-variance scale) for PCA?
% PCA finds directions of maximum variance. If one variable is measured on
% a much larger scale than another, it will dominate the variance budget
% and the first PC will mostly track that one variable's noise. Autoscaling
% puts every variable on equal footing so PCA discovers structure shared
% across variables, not artifacts of measurement units.

% >>> USER: change to 'mean center', 'snv', 'derivative', etc., depending on your data.
ppA = preprocess('default', 'autoscale');

%% ------------------------------------------------------------------------
%  Step A.3 — Build the PCA model (OO workflow)
%% ------------------------------------------------------------------------
% The OO workflow is: create empty model -> assign data and ncomp -> set
% preprocessing via the options struct (round-trip: get, modify, assign
% back) -> .calibrate. The resulting object has dot-notation accessors for
% scores, loadings, T2, Q, and confidence limits.

modelA = evrimodel('pca');                   % create an empty PCA model object
modelA.x = wine;                              % assign x-block (DSO or numeric)

% >>> USER: pick an ncomp consistent with your data. With wine's 5 variables, 3 PCs is plenty.
modelA.ncomp = 3;

modelA.display = 'off';                       % silence command-window chatter
modelA.plots   = 'none';                      % suppress automatic plot windows

opts = modelA.options;
opts.preprocessing{1} = ppA;                  % preprocessing for the x-block (block 1)
modelA.options = opts;

modelA = modelA.calibrate;                    % build the PCA model

%% ------------------------------------------------------------------------
%  Step A.4 — Inspect scores, loadings, and variance captured
%% ------------------------------------------------------------------------
% .scores is the projection of samples onto the principal components.
% .loadings is each PC expressed as a linear combination of variables —
% reading the loading vector tells you which variables drove each PC.
% .ssqcell summarizes the variance captured per component (and cumulative).

scoresA  = modelA.scores;
loadsA   = modelA.loadings;
ssqA     = modelA.ssqcell;
fprintf('\nWine: variance captured per component (%%):\n');
disp(ssqA);

% Aside: What is Q residual?
% --------------------------
% After projecting a sample onto the top-k PCs, Q is the sum of squared
% residuals in the directions PCA chose to discard. A high Q means the
% sample has structure the model cannot explain — usually an outlier.

% Aside: How does T2 measure leverage?
% ------------------------------------
% T2 (Hotelling's) is the squared, scale-normalized distance from the
% origin in the score space of the retained PCs. A high T2 means the
% sample is unusual ALONG the directions PCA does model — a high-leverage
% observation with respect to the calibration set.

%% ------------------------------------------------------------------------
%  Step A.5 — Plot scores, loadings, and outlier diagnostics
%% ------------------------------------------------------------------------
figure('Name', 'PCA on wine');

% PC1 vs PC2 scores (annotated with sample labels when available)
subplot(2, 2, 1);
plot(scoresA(:,1), scoresA(:,2), 'o', 'MarkerFaceColor', [.2 .4 .8], 'MarkerEdgeColor', 'none');
sampleLabels = safeLabels(wine, 1, size(scoresA, 1));
if ~isempty(sampleLabels)
    text(scoresA(:,1), scoresA(:,2), sampleLabels, 'FontSize', 8, 'VerticalAlignment','bottom');
end
xlabel('PC1'); ylabel('PC2'); title('Scores (wine)'); grid on;

% Loadings as a bar plot — which variables define PC1?
subplot(2, 2, 2);
bar(loadsA(:, 1:min(2, modelA.ncomp)));
varLabels = safeLabels(wine, 2, size(loadsA, 1));
if ~isempty(varLabels)
    set(gca, 'XTick', 1:size(loadsA, 1), 'XTickLabel', varLabels);
    xtickangle(30);
end
ylabel('Loading'); title('Loadings on PC1, PC2'); legend({'PC1','PC2'}, 'Location','best'); grid on;

% Scree
subplot(2, 2, 3);
ssqMat = cell2mat(ssqA(2:end, 2));            % %variance captured per component
plot(1:numel(ssqMat), ssqMat, '-o', 'MarkerFaceColor','auto');
xlabel('PC #'); ylabel('% variance captured'); title('Scree plot'); grid on;

% Q vs T2 with 95% limits.
% Note: PLS_Toolbox returns .tsqlim and .reslim as 1x1 cells wrapping the
% scalar 95% confidence limits — unwrap with {1} before plotting.
subplot(2, 2, 4);
plot(modelA.t2, modelA.q, 'o', 'MarkerFaceColor', [.2 .4 .8], 'MarkerEdgeColor','none');
tsqLim = unwrap_limit(modelA.tsqlim);
resLim = unwrap_limit(modelA.reslim);
if ~isempty(tsqLim); xline(tsqLim, '--r', 'T2 95%'); end
if ~isempty(resLim); yline(resLim, '--r', 'Q 95%'); end
xlabel('Hotelling T^2'); ylabel('Q residual'); title('Outlier diagnostics'); grid on;


%% ========================================================================
%  Block B — PCA on the larger `arch` dataset (preview for classifiers)
%% ========================================================================
% The arch dataset contains x-ray fluorescence (XRF) measurements on 10
% elements for 75 archaeological samples. Samples come from 4 quarries
% (classes 1..4) plus a set of unknowns (class 0). PCA scores will reveal
% the class structure without ever being told the labels — this is what
% LDA / PLSDA / SVMDA later model directly.

%% ------------------------------------------------------------------------
%  Step B.1 — Load and split known vs unknown samples
%% ------------------------------------------------------------------------

% >>> USER: replace with your own DataSet Object.
load arch

knownIdx   = find(arch.class{1} > 0);         % labelled samples
unknownIdx = find(arch.class{1} == 0);        % "novel" samples to project later

xKnown   = arch(knownIdx, :);
xUnknown = arch(unknownIdx, :);

fprintf('\nArch: %d labelled samples across %d classes, %d unknowns.\n', ...
        numel(knownIdx), numel(unique(xKnown.class{1})), numel(unknownIdx));

%% ------------------------------------------------------------------------
%  Step B.2 — Build the PCA model
%% ------------------------------------------------------------------------

modelB = evrimodel('pca');
modelB.x = xKnown;

% >>> USER: 3 PCs is a sensible starting choice for 10 elements; tune from the scree plot.
modelB.ncomp = 3;
modelB.display = 'off';
modelB.plots   = 'none';

opts = modelB.options;
opts.preprocessing{1} = preprocess('default', 'autoscale');
modelB.options = opts;

modelB = modelB.calibrate;

%% ------------------------------------------------------------------------
%  Step B.3 — Project the unknowns through the calibrated model
%% ------------------------------------------------------------------------
% .apply takes new x-data, runs it through the SAME preprocessing (already
% calibrated and stored inside the model) and returns a prediction object
% with scores, T2, and Q for the new data — but no labels are needed.

predUnknown = modelB.apply(xUnknown);

%% ------------------------------------------------------------------------
%  Step B.4 — Plot scores colored by class, and project unknowns on top
%% ------------------------------------------------------------------------

figure('Name', 'PCA on arch');

subplot(1, 2, 1);
classNums  = xKnown.class{1};
classList  = unique(classNums);
colors     = lines(numel(classList));
hold on;
for k = 1:numel(classList)
    sel = classNums == classList(k);
    plot(modelB.scores(sel, 1), modelB.scores(sel, 2), 'o', ...
         'MarkerFaceColor', colors(k, :), 'MarkerEdgeColor', 'none', ...
         'DisplayName', sprintf('Class %d', classList(k)));
end
% Unknowns as black open circles
plot(predUnknown.scores(:, 1), predUnknown.scores(:, 2), 'ko', ...
     'MarkerFaceColor', 'none', 'DisplayName', 'Unknown');
xlabel('PC1'); ylabel('PC2');
title('Arch scores: known + projected unknowns');
legend('Location','best'); grid on; hold off;

% Loadings on PC1
subplot(1, 2, 2);
bar(modelB.loadings(:, 1));
varLabels = cellstr(xKnown.label{2});
if numel(varLabels) == size(modelB.loadings, 1)
    set(gca, 'XTick', 1:size(modelB.loadings, 1), 'XTickLabel', varLabels);
    xtickangle(30);
end
ylabel('Loading on PC1'); title('Which elements drive PC1?'); grid on;


%% ========================================================================
%  Wine vs arch: what each block teaches
%% ========================================================================
% Wine is hand-traceable: with only 5 samples, you can verify by eye that
% PC1 separates "high-consumption" countries from "low-consumption" ones,
% and you can map each loading back to a single beverage. It is an X-ray
% of the PCA mechanism.
%
% Arch is realistic: classes you weren't told about appear as clusters in
% PC1-PC2 score space. The unknown samples land where their unobserved
% chemistry implies they belong. This is the everyday utility of PCA —
% an unsupervised lens that often reveals supervised structure.


%% ========================================================================
%  Summary
%% ========================================================================

fprintf('\n========================================================\n');
fprintf('  %s — SUMMARY\n', mfilename);
fprintf('========================================================\n');
fprintf('  Block A: wine\n');
fprintf('    Samples x Variables : %dx%d\n', size(wine, 1), size(wine, 2));
fprintf('    Components used     : %d\n', modelA.ncomp);
fprintf('    Total var captured  : %.2f%%\n', sum(cell2mat(modelA.ssqcell(2:end, 2))));
fprintf('  Block B: arch\n');
fprintf('    Calibration samples : %d (%d classes)\n', size(xKnown, 1), numel(unique(xKnown.class{1})));
fprintf('    Unknowns projected  : %d\n', size(xUnknown, 1));
fprintf('    Components used     : %d\n', modelB.ncomp);
fprintf('    Total var captured  : %.2f%%\n', sum(cell2mat(modelB.ssqcell(2:end, 2))));
fprintf('========================================================\n\n');


%% ------------------------------------------------------------------------
%  Local helpers
%% ------------------------------------------------------------------------

function val = unwrap_limit(lim)
    % .tsqlim / .reslim are 1x1 cells wrapping a scalar in current
    % PLS_Toolbox versions. Unwrap to a plain scalar; return [] if empty.
    val = [];
    if iscell(lim) && ~isempty(lim); lim = lim{1}; end
    if isnumeric(lim) && isscalar(lim) && isfinite(lim); val = double(lim); end
end

function lbls = safeLabels(dso, mode, expectedCount)
    % Return DSO labels for a given mode as a cellstr if they exist and
    % match the expected length; otherwise return empty so callers can skip.
    lbls = {};
    try
        raw = dso.label{mode};
        if isempty(raw); return; end
        c = cellstr(raw);
        if numel(c) == expectedCount && ~all(cellfun(@isempty, c))
            lbls = c;
        end
    catch
    end
end
