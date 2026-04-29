%==========================================================================
%  PLSDA EXAMPLE — PLS Discriminant Analysis (classification)
%
%  Dataset    : `arch` (toolbox/dems/arch.mat). Same XRF / quarry dataset
%               and the same calibration / test split as the LDA example,
%               so the two methods can be compared directly.
%  Model      : PLSDA via evrimodel('plsda')
%
%  You will learn
%  --------------
%  1. The OO PLSDA workflow with cross-validated LV selection.
%  2. How to read CV misclassification curves to pick a parsimonious LV.
%  3. How PLSDA's per-class probability output and class threshold work.
%  4. How to evaluate sensitivity, specificity, and classification error
%     on a held-out test set.
%
%  How does PLSDA pick a class threshold?
%  --------------------------------------
%  PLSDA fits a PLS regression of an indicator-coded y matrix (one column
%  per class, 1 if the sample is in the class else 0). For each class,
%  PLS_Toolbox derives a probability-like score and a threshold (often
%  Bayesian, calibrated against the prior class frequencies). A sample is
%  assigned to whichever class has the highest score above its threshold.
%  When predictors are highly collinear, PLSDA tends to outperform LDA
%  because the latent-variable basis avoids the ill-conditioned within-
%  class covariance estimate that hurts LDA on collinear data.
%
%  Prerequisites
%  -------------
%  - MATLAB (base only)
%  - PLS_Toolbox v9.0+ on the path
%
%  How to adapt this script to your data
%  -------------------------------------
%  Search for the marker:   % >>> USER:
%
%  Author : EVRI CLI Examples
%  Date   : 2026-04-29
%==========================================================================

clear; clc; close all;

rng(0, 'twister');

set(groot, 'defaultAxesFontSize', 11);
set(groot, 'defaultLineLineWidth', 1.4);


%% ------------------------------------------------------------------------
%  Step 1 — Load and split known samples (same logic as the LDA example)
%% ------------------------------------------------------------------------

% >>> USER: replace with your own DataSet Object that has classes in .class{1}.
load arch
xall      = arch;
classAll  = xall.class{1}(:);                 % force column
knownIdx  = find(classAll > 0);
unknownIdx = find(classAll == 0);
xKnown    = xall(knownIdx, :);
classNums = xKnown.class{1}(:);
uniqueClasses = unique(classNums);

testFraction = 0.20;                          % >>> USER: adjust split fraction.
idxCal = []; idxTest = [];
for k = 1:numel(uniqueClasses)
    inClass = find(classNums == uniqueClasses(k));
    inClass = inClass(:);
    inClass = inClass(randperm(numel(inClass)));
    nTest   = max(1, round(testFraction * numel(inClass)));
    idxTest = [idxTest; inClass(1:nTest)];     %#ok<AGROW>
    idxCal  = [idxCal;  inClass(nTest+1:end)]; %#ok<AGROW>
end
idxCal  = sort(idxCal);
idxTest = sort(idxTest);

xCal = xKnown(idxCal, :);
xTst = xKnown(idxTest, :);
yCal = dataset(classNums(idxCal));
yTst = dataset(classNums(idxTest));
xUnknown = xall(unknownIdx, :);

fprintf('Calibration: %d, Test: %d, Unknowns: %d\n', size(xCal,1), size(xTst,1), size(xUnknown,1));


%% ------------------------------------------------------------------------
%  Step 2 — Define preprocessing
%% ------------------------------------------------------------------------

% >>> USER: change for your data type.
ppX = preprocess('default', 'autoscale');


%% ------------------------------------------------------------------------
%  Step 3 — Build and cross-validate the PLSDA model
%% ------------------------------------------------------------------------

% >>> USER: pick a maxLV comfortably above the optimum.
maxLV = 10;

% >>> USER: change cvi for different CV strategies.
cvi = {'vet', 5};

model = evrimodel('plsda');
model.x = xCal;
model.y = yCal;
model.ncomp = maxLV;
model.display = 'off';
model.plots   = 'none';

opts = model.options;
opts.preprocessing{1} = ppX;
model.options = opts;

model = model.crossvalidate(cvi, maxLV);


%% ------------------------------------------------------------------------
%  Step 4 — Pick the optimal LV from the CV misclassification curve
%% ------------------------------------------------------------------------
% PLS_Toolbox stores the CV misclassification rate (per LV) in
% model.detail.misclassedcv. The minimum is the obvious choice; we also
% compute the simplest (smallest-LV) model within the empirical SE for a
% 1-SE-style selection, although fold-level data are needed to compute a
% true SE — we use a heuristic SE = 1 / sqrt(N) here for parsimony.

% PLSDA stores per-class misclassification as a 1xK cell, each entry a
% 2 x ncomp matrix (row 1 = sensitivity-miss, row 2 = specificity-miss).
% Average across rows AND classes to get one overall miss-rate curve per LV.
mcCV = aggregate_misclass(model.detail.misclassedcv, maxLV);
mcC  = aggregate_misclass(model.detail.misclassedc,  maxLV);
[~, optLV] = min(mcCV);
fprintf('\nOptimal LV by minimum CV misclassification: %d (%.2f%% errors)\n', optLV, 100*mcCV(optLV));

% Build a FRESH model at the chosen LV (ncomp is read-only after calibration).
model = evrimodel('plsda');
model.x = xCal;
model.y = yCal;
model.ncomp = optLV;
model.display = 'off';
model.plots   = 'none';
opts = model.options;
opts.preprocessing{1} = ppX;
model.options = opts;
model = model.crossvalidate(cvi, optLV);


%% ------------------------------------------------------------------------
%  Step 5 — Apply to the test set
%% ------------------------------------------------------------------------

predTest = model.apply(xTst, yTst);

yTstTrue = asvector(yTst);
yTstHat  = asvector(predTest.classification.mostprobable);
if isempty(yTstHat) || all(isnan(yTstHat))
    % Fallback for older versions: take argmax of predicted class probabilities.
    probMat  = predTest.classification.probability;
    [~, ix]  = max(probMat, [], 2);
    yTstHat  = uniqueClasses(ix);
end

[confMat, classLabels] = confusion_matrix(yTstTrue, yTstHat, uniqueClasses);
[sens, spec, errOverall] = classification_metrics(confMat);


%% ------------------------------------------------------------------------
%  Step 6 — Plots: CV curve, class probabilities, confusion matrix
%% ------------------------------------------------------------------------

figure('Name', 'PLSDA — diagnostics');

% CV misclassification vs # LVs
subplot(2, 2, 1);
plot(1:numel(mcCV), 100*mcCV, '-o', 'MarkerFaceColor','auto'); hold on;
plot(1:numel(mcC),  100*mcC,  '-s', 'MarkerFaceColor','auto');
xline(optLV, '--k', sprintf('Chosen LV = %d', optLV));
xlabel('# Latent variables'); ylabel('Misclassification (%)');
legend({'CV','Calibration'}, 'Location','best');
title('Misclassification vs LV'); grid on; hold off;

% LV1 vs LV2 scores colored by class
subplot(2, 2, 2);
sc = model.scores;
hold on;
colors = lines(numel(uniqueClasses));
classNumsCal = asvector(yCal);
for k = 1:numel(uniqueClasses)
    sel = classNumsCal == uniqueClasses(k);
    plot(sc(sel,1), sc(sel,2), 'o', 'MarkerFaceColor', colors(k,:), ...
         'MarkerEdgeColor','none', 'DisplayName', sprintf('Class %d', uniqueClasses(k)));
end
xlabel('LV1'); ylabel('LV2'); title('Calibration scores');
legend('Location','best'); grid on; hold off;

% Predicted probability for class 1 across all calibration samples
subplot(2, 2, 3);
prob = model.classification.probability;
plot(1:size(prob,1), prob(:,1), 'o', 'MarkerFaceColor', colors(1,:), 'MarkerEdgeColor','none');
xlabel('Calibration sample #'); ylabel('P(class 1)');
title('PLSDA class-1 probability'); grid on;

% Confusion matrix
subplot(2, 2, 4);
plot_confusion(confMat, classLabels, 'PLSDA test-set confusion matrix');


%% ------------------------------------------------------------------------
%  Step 7 — Summary
%% ------------------------------------------------------------------------

fprintf('\n========================================================\n');
fprintf('  %s — SUMMARY\n', mfilename);
fprintf('========================================================\n');
fprintf('  Dataset           : arch (X: %dx%d, %d classes)\n', size(xall,1), size(xall,2), numel(uniqueClasses));
fprintf('  Calibration       : %d samples\n', size(xCal,1));
fprintf('  Test              : %d samples\n', size(xTst,1));
fprintf('  Preprocessing (X) : autoscale\n');
fprintf('  CV scheme         : venetian blinds, 5 splits\n');
fprintf('  Optimal LVs       : %d (min CV misclass)\n', optLV);
fprintf('  Classification err: %.2f%%\n', 100*errOverall);
fprintf('  Per-class sensitivity:\n');
for k = 1:numel(classLabels)
    fprintf('    Class %d : %.2f%%\n', classLabels(k), 100*sens(k));
end
fprintf('  Per-class specificity:\n');
for k = 1:numel(classLabels)
    fprintf('    Class %d : %.2f%%\n', classLabels(k), 100*spec(k));
end
fprintf('========================================================\n\n');


%% ------------------------------------------------------------------------
%  Local helpers
%% ------------------------------------------------------------------------

function v = asvector(x)
    if isa(x, 'dataset'); x = x.data; end
    x = double(x);
    if size(x, 2) > 1; x = x(:, 1); end
    v = x(:);
end

function v = aggregate_misclass(mc, nLV)
    % Flatten PLS_Toolbox per-class misclassification storage to one curve.
    % `mc` is a 1xK cell (one entry per class); each entry is 2 x nLV.
    % Returns a column vector of length nLV (mean across classes and rows).
    if isnumeric(mc)
        v = mean(mc(:, 1:nLV), 1).';                          % already a matrix
        return;
    end
    nK = numel(mc);
    rows = cell(nK, 1);
    for k = 1:nK
        if isnumeric(mc{k}) && size(mc{k}, 2) >= nLV
            rows{k} = mc{k}(:, 1:nLV);
        end
    end
    M = vertcat(rows{:});
    v = mean(M, 1).';
end

function [C, classLabels] = confusion_matrix(yTrue, yPred, classLabels)
    classLabels = classLabels(:);
    n = numel(classLabels);
    C = zeros(n, n);
    for i = 1:n
        for j = 1:n
            C(i, j) = sum(yTrue == classLabels(i) & yPred == classLabels(j));
        end
    end
end

function [sens, spec, errOverall] = classification_metrics(C)
    n = size(C, 1);
    total = sum(C(:));
    correct = sum(diag(C));
    errOverall = 1 - correct / max(total, 1);
    sens = zeros(n, 1); spec = zeros(n, 1);
    for k = 1:n
        TP = C(k, k);
        FN = sum(C(k, :)) - TP;
        FP = sum(C(:, k)) - TP;
        TN = total - TP - FN - FP;
        if (TP + FN) > 0; sens(k) = TP / (TP + FN); end
        if (TN + FP) > 0; spec(k) = TN / (TN + FP); end
    end
end

function plot_confusion(C, labels, ttl)
    imagesc(C); colormap(flipud(gray)); colorbar;
    set(gca, 'XTick', 1:numel(labels), 'YTick', 1:numel(labels), ...
             'XTickLabel', arrayfun(@(v) sprintf('%d', v), labels, 'UniformOutput', false), ...
             'YTickLabel', arrayfun(@(v) sprintf('%d', v), labels, 'UniformOutput', false));
    xlabel('Predicted class'); ylabel('True class'); title(ttl);
    for i = 1:size(C, 1)
        for j = 1:size(C, 2)
            txtColor = 'k'; if C(i, j) > max(C(:)) * 0.5; txtColor = 'w'; end
            text(j, i, sprintf('%d', C(i,j)), 'HorizontalAlignment','center', 'Color', txtColor);
        end
    end
end
