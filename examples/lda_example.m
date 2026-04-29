%==========================================================================
%  LDA EXAMPLE — Linear Discriminant Analysis (classification)
%
%  Dataset    : `arch` (toolbox/dems/arch.mat). X-ray fluorescence data on
%               10 elements for 75 archaeological samples. Samples come
%               from 4 quarries (classes 1..4) plus a set of "unknowns"
%               (class 0). The same dataset is used by the PLSDA, SVMDA,
%               and classification-comparison scripts so the methods can
%               be compared directly.
%  Model      : LDA via evrimodel('lda')
%
%  You will learn
%  --------------
%  1. The OO LDA workflow with class labels.
%  2. How to split known-class samples into calibration and test, then
%     evaluate sensitivity, specificity, and classification error.
%  3. How to project truly unknown samples through a calibrated LDA model
%     to make a class prediction.
%
%  LDA assumptions and caveats
%  ---------------------------
%  LDA is the optimal classifier when each class is multivariate normal
%  with a SHARED covariance matrix and the prior class probabilities are
%  known. When those assumptions hold, LDA is hard to beat. When they
%  fail — markedly different class shapes, heavy-tailed distributions,
%  nonlinear class boundaries — LDA degrades gracefully but loses ground
%  to PLSDA (which absorbs collinearity) or SVMDA (which absorbs
%  nonlinearity).
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
%  Step 1 — Load and inspect data
%% ------------------------------------------------------------------------

% >>> USER: replace with your own DataSet Object that has classes in .class{1}.
load arch
xall = arch;

% Force class assignment to a column vector to avoid row/column concatenation
% ambiguity later in the stratified split.
classAll   = xall.class{1}(:);
knownIdx   = find(classAll > 0);
unknownIdx = find(classAll == 0);
fprintf('Loaded arch: %d known samples (4 classes), %d unknowns.\n', ...
        numel(knownIdx), numel(unknownIdx));


%% ------------------------------------------------------------------------
%  Step 2 — Stratified 80/20 split of the known samples
%% ------------------------------------------------------------------------
% A stratified split keeps each class's proportion in the calibration and
% test sets. This avoids the case where one class is missing from the
% test set (which would corrupt sensitivity / specificity for that class).

% >>> USER: change testFraction to your preferred split, or replace with a fixed index list.
testFraction = 0.20;
xKnown = xall(knownIdx, :);
classNumsKnown = xKnown.class{1}(:);          % column vector
uniqueClasses  = unique(classNumsKnown);

idxCal  = [];
idxTest = [];
for k = 1:numel(uniqueClasses)
    inClass = find(classNumsKnown == uniqueClasses(k));
    inClass = inClass(:);                                    % force column
    inClass = inClass(randperm(numel(inClass)));
    nTest   = max(1, round(testFraction * numel(inClass)));
    idxTest = [idxTest; inClass(1:nTest)];     %#ok<AGROW>
    idxCal  = [idxCal;  inClass(nTest+1:end)]; %#ok<AGROW>
end
idxCal  = sort(idxCal);
idxTest = sort(idxTest);

xCal = xKnown(idxCal, :);
xTst = xKnown(idxTest, :);

% LDA expects a class assignment as a y-block. Wrap as a DSO with one
% column of class indices.
yCal = dataset(classNumsKnown(idxCal));
yTst = dataset(classNumsKnown(idxTest));

xUnknown = xall(unknownIdx, :);

fprintf('Calibration: %d, Test: %d, Unknowns to project: %d\n', ...
        size(xCal,1), size(xTst,1), size(xUnknown,1));


%% ------------------------------------------------------------------------
%  Step 3 — Define preprocessing
%% ------------------------------------------------------------------------
% LDA needs the elements on a comparable scale (autoscale X) and the
% class label vector mean-centered (a convention LDA uses internally).

% >>> USER: change preprocessing to suit your data type.
ppX = preprocess('default', 'autoscale');
ppY = preprocess('default', 'mean center');


%% ------------------------------------------------------------------------
%  Step 4 — Build the LDA model
%% ------------------------------------------------------------------------

model = evrimodel('lda');
model.x = xCal;
model.y = yCal;

% >>> USER: ncomp for LDA controls the regularization on the within-class covariance. 3 is a common starting point.
model.ncomp = 3;

model.display = 'off';
model.plots   = 'none';

opts = model.options;
opts.preprocessing{1} = ppX;
opts.preprocessing{2} = ppY;
model.options = opts;

model = model.calibrate;


%% ------------------------------------------------------------------------
%  Step 5 — Apply to the held-out test samples
%% ------------------------------------------------------------------------

predTest = model.apply(xTst, yTst);

% Predicted-class index per sample. We try .classification.mostprobable
% first (the canonical accessor) and fall back to argmax of pred{2} for
% older versions or model variants that return per-class probabilities.
yTstTrue = asvector(yTst);
yTstHat  = predicted_class(predTest, uniqueClasses);

[confMat, classLabels] = confusion_matrix(yTstTrue, yTstHat, uniqueClasses);
[sens, spec, errOverall] = classification_metrics(confMat);


%% ------------------------------------------------------------------------
%  Step 6 — Project the truly-unknown samples
%% ------------------------------------------------------------------------

predUnknown = model.apply(xUnknown);
yUnknownHat = predicted_class(predUnknown, uniqueClasses);

fprintf('\nUnknown samples assigned to:\n');
for k = 1:numel(uniqueClasses)
    fprintf('  Class %d: %d\n', uniqueClasses(k), sum(yUnknownHat == uniqueClasses(k)));
end


%% ------------------------------------------------------------------------
%  Step 7 — Plots
%% ------------------------------------------------------------------------

figure('Name', 'LDA — diagnostics');

% LDA score space (cal samples), colored by class
subplot(1, 2, 1);
sc = model.scores;
hold on;
colors = lines(numel(uniqueClasses));
classNumsCal = asvector(yCal);
for k = 1:numel(uniqueClasses)
    sel = classNumsCal == uniqueClasses(k);
    plot(sc(sel,1), sc(sel,2), 'o', 'MarkerFaceColor', colors(k,:), ...
         'MarkerEdgeColor','none', 'DisplayName', sprintf('Class %d', uniqueClasses(k)));
end
xlabel('Discriminant 1'); ylabel('Discriminant 2');
title('LDA scores (calibration)'); legend('Location','best'); grid on; hold off;

% Confusion matrix as a heatmap
subplot(1, 2, 2);
plot_confusion(confMat, classLabels, 'LDA test-set confusion matrix');


%% ------------------------------------------------------------------------
%  Step 8 — Summary
%% ------------------------------------------------------------------------

fprintf('\n========================================================\n');
fprintf('  %s — SUMMARY\n', mfilename);
fprintf('========================================================\n');
fprintf('  Dataset           : arch (X: %dx%d, %d classes)\n', size(xall,1), size(xall,2), numel(uniqueClasses));
fprintf('  Calibration       : %d samples\n', size(xCal,1));
fprintf('  Test              : %d samples\n', size(xTst,1));
fprintf('  Unknowns projected: %d samples\n', size(xUnknown,1));
fprintf('  Preprocessing (X) : autoscale\n');
fprintf('  Preprocessing (Y) : mean center\n');
fprintf('  Components used   : %d\n', model.ncomp);
fprintf('  Classification err: %.2f%%\n', 100*errOverall);
fprintf('  Per-class sensitivity (TP / actual class):\n');
for k = 1:numel(classLabels)
    fprintf('    Class %d : %.2f%%\n', classLabels(k), 100*sens(k));
end
fprintf('  Per-class specificity (TN / non-class actuals):\n');
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

function yhat = predicted_class(predObj, uniqueClasses)
    % Try the canonical accessor first; fall back to argmax of pred{2}.
    yhat = [];
    try
        yhat = asvector(predObj.classification.mostprobable);
    catch
    end
    if isempty(yhat) || all(isnan(yhat))
        try
            p2 = predObj.pred{2};
            if isa(p2, 'dataset'); p2 = p2.data; end
            p2 = double(p2);
            if size(p2, 2) == 1
                yhat = p2(:);                          % single column = class index
            else
                [~, ix] = max(p2, [], 2);              % multi-column = probabilities
                yhat = uniqueClasses(ix);
            end
        catch
        end
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

    sens = zeros(n, 1);
    spec = zeros(n, 1);
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
    % Overlay counts
    for i = 1:size(C, 1)
        for j = 1:size(C, 2)
            txtColor = 'k'; if C(i, j) > max(C(:)) * 0.5; txtColor = 'w'; end
            text(j, i, sprintf('%d', C(i,j)), 'HorizontalAlignment','center', 'Color', txtColor);
        end
    end
end
