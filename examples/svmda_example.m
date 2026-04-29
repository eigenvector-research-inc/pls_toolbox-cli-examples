%==========================================================================
%  SVMDA EXAMPLE — Support Vector Machine Discriminant Analysis
%
%  Dataset    : `arch` (toolbox/dems/arch.mat). Same XRF dataset and the
%               same calibration / test split convention as the LDA and
%               PLSDA examples, so the three classifiers can be compared
%               directly.
%  Model      : Multi-class SVM (one-vs-one) with an RBF kernel via
%               evrimodel('svmda'). PLS_Toolbox's SVMDA function performs
%               CV-based selection of cost (C) and gamma when those
%               options are passed as vectors.
%
%  You will learn
%  --------------
%  1. The OO SVMDA workflow.
%  2. How PLS_Toolbox runs an internal cost x gamma CV grid for SVMs.
%  3. How to evaluate a multi-class SVM with sensitivity, specificity,
%     and a confusion matrix.
%
%  Multi-class SVM via one-vs-one
%  ------------------------------
%  SVMs are inherently binary classifiers. PLS_Toolbox's SVMDA defaults
%  to the one-vs-one scheme: it trains a separate binary SVM for every
%  pair of classes and assigns a sample to whichever class wins the most
%  pairwise votes. This is more robust to imbalanced data than the
%  alternative one-vs-rest scheme but scales as O(K^2) binary classifiers
%  for K classes.
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
%  Step 1 — Load and split known samples
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
% Autoscale X is essential when using an RBF kernel (see the SVMR example
% for the pedagogical aside on why kernel SVMs are scale-sensitive).

% >>> USER: change to suit your data type.
ppX = preprocess('default', 'autoscale');


%% ------------------------------------------------------------------------
%  Step 3 — Build the SVMDA model with a CV grid over cost x gamma
%% ------------------------------------------------------------------------

model = evrimodel('svmda');
model.x = xCal;
model.y = yCal;
model.display = 'off';
model.plots   = 'none';

opts = model.options;
opts.svmtype          = 'c-svc';
opts.kerneltype       = 'rbf';

% >>> USER: widen these grids if the chosen optimum lands at a boundary.
opts.cost             = [0.1 1 10 100];
opts.gamma            = [1e-4 1e-3 1e-2 1e-1];

opts.cvi              = {'vet', 5};
opts.cvtimelimit      = 60;

opts.preprocessing{1} = ppX;
model.options = opts;

fprintf('\nCalibrating SVMDA with built-in CV grid...\n');
model = model.calibrate;

% Inspect the chosen hyperparameters. libsvm exposes them on
% model.detail.svm.model.param (C = cost, gamma = RBF bandwidth).
chosenCost  = getoptfield(model, 'detail.svm.model.param.C',     NaN);
chosenGamma = getoptfield(model, 'detail.svm.model.param.gamma', NaN);


%% ------------------------------------------------------------------------
%  Step 4 — Apply to the test set
%% ------------------------------------------------------------------------

predTest = model.apply(xTst, yTst);

yTstTrue = asvector(yTst);
yTstHat  = asvector(predTest.classification.mostprobable);
if isempty(yTstHat) || all(isnan(yTstHat))
    probMat  = predTest.classification.probability;
    [~, ix]  = max(probMat, [], 2);
    yTstHat  = uniqueClasses(ix);
end

[confMat, classLabels] = confusion_matrix(yTstTrue, yTstHat, uniqueClasses);
[sens, spec, errOverall] = classification_metrics(confMat);


%% ------------------------------------------------------------------------
%  Step 5 — Project the unknowns
%% ------------------------------------------------------------------------

predUnknown = model.apply(xUnknown);
yUnknownHat = asvector(predUnknown.classification.mostprobable);
if isempty(yUnknownHat) || all(isnan(yUnknownHat))
    probMat = predUnknown.classification.probability;
    [~, ix] = max(probMat, [], 2);
    yUnknownHat = uniqueClasses(ix);
end

fprintf('\nUnknown samples assigned to:\n');
for k = 1:numel(uniqueClasses)
    fprintf('  Class %d: %d\n', uniqueClasses(k), sum(yUnknownHat == uniqueClasses(k)));
end


%% ------------------------------------------------------------------------
%  Step 6 — Plots: CV grid (if available), confusion matrix, score-space
%% ------------------------------------------------------------------------

figure('Name', 'SVMDA — diagnostics');

% CV grid plot from PLS_Toolbox
try
    subplot(1, 2, 1);
    svmcvplot(model, {'cost', 'gamma'});
catch err
    subplot(1, 2, 1);
    text(0.1, 0.5, sprintf('svmcvplot unavailable: %s', err.message), 'FontSize', 9);
    axis off;
end

% Confusion matrix
subplot(1, 2, 2);
plot_confusion(confMat, classLabels, 'SVMDA test-set confusion matrix');


%% ------------------------------------------------------------------------
%  Step 7 — Summary
%% ------------------------------------------------------------------------

fprintf('\n========================================================\n');
fprintf('  %s — SUMMARY\n', mfilename);
fprintf('========================================================\n');
fprintf('  Dataset           : arch (X: %dx%d, %d classes)\n', size(xall,1), size(xall,2), numel(uniqueClasses));
fprintf('  Calibration       : %d samples\n', size(xCal,1));
fprintf('  Test              : %d samples\n', size(xTst,1));
fprintf('  Unknowns projected: %d samples\n', size(xUnknown,1));
fprintf('  Preprocessing (X) : autoscale\n');
fprintf('  Kernel            : RBF (one-vs-one multi-class)\n');
fprintf('  Grid (cost)       : %s\n',  sprintf('%g ', opts.cost));
fprintf('  Grid (gamma)      : %s\n',  sprintf('%g ', opts.gamma));
fprintf('  Chosen cost       : %g\n',  chosenCost);
fprintf('  Chosen gamma      : %g\n',  chosenGamma);
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

function val = getoptfield(model, dottedPath, defaultVal)
    val = defaultVal;
    try
        parts = strsplit(dottedPath, '.');
        v = model;
        for k = 1:numel(parts); v = v.(parts{k}); end
        if isnumeric(v) && ~isempty(v); val = v; end
    catch
    end
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
