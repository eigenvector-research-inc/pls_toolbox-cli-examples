%==========================================================================
%  CLASSIFICATION COMPARISON — Three classifiers on a single shared split
%
%  Dataset    : `arch` (toolbox/dems/arch.mat). Same XRF / quarry dataset
%               as the LDA, PLSDA, and SVMDA examples. A single stratified
%               80/20 split is shared by all three classifiers, ensuring
%               every model sees the same calibration and test samples.
%
%  Models     : LDA, PLSDA (CV LV), SVMDA (CV cost / gamma).
%
%  You will learn
%  --------------
%  1. How to make an apples-to-apples classification comparison with one
%     shared cal/test split and the same evaluation metrics.
%  2. How to package each classifier as a self-contained block that can
%     be commented out without breaking the rest.
%  3. What this dataset (small, low-dimensional, low-collinearity) reveals
%     about when each classifier wins.
%
%  Adding or removing a classifier
%  -------------------------------
%  Each block is stand-alone and writes one entry to the results struct
%  via addClassResult(). Comment out a block to skip a classifier.
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
%  Step 1 — Shared stratified split, preprocessing, and CV scheme
%% ------------------------------------------------------------------------

% >>> USER: replace with your own DataSet Object that has classes in .class{1}.
load arch
xall      = arch;
classAll  = xall.class{1}(:);                 % force column
knownIdx  = find(classAll > 0);
xKnown    = xall(knownIdx, :);
classNums = xKnown.class{1}(:);
uniqueClasses = unique(classNums);

testFraction = 0.20;                          % >>> USER: change split fraction
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

ppX = preprocess('default', 'autoscale');
ppY = preprocess('default', 'mean center');

cviCell = {'vet', 5};

% Plain vectors used by all blocks
yTstTrue = asvector(yTst);

% Initialize results
results = struct('name', {}, 'errOverall', {}, 'sens', {}, 'spec', {}, ...
                 'confMat', {}, 'classLabels', {}, 'hp', {});

fprintf('Calibration: %d, Test: %d, %d classes\n', size(xCal,1), size(xTst,1), numel(uniqueClasses));


%% ========================================================================
%  Block A — LDA
%% ========================================================================
mLDA = evrimodel('lda');
mLDA.x = xCal;  mLDA.y = yCal;  mLDA.ncomp = 3;
mLDA.display = 'off';  mLDA.plots = 'none';
o = mLDA.options;
o.preprocessing{1} = ppX;  o.preprocessing{2} = ppY;
mLDA.options = o;
mLDA = mLDA.calibrate;
predLDA = mLDA.apply(xTst, yTst);
yHatLDA = predicted_class(predLDA, uniqueClasses);
results = addClassResult(results, 'LDA', yTstTrue, yHatLDA, uniqueClasses, ...
                         sprintf('ncomp=%d', mLDA.ncomp));


%% ========================================================================
%  Block B — PLSDA with CV-chosen LV
%% ========================================================================
mPLSDA = evrimodel('plsda');
mPLSDA.x = xCal;  mPLSDA.y = yCal;  mPLSDA.ncomp = 8;
mPLSDA.display = 'off';  mPLSDA.plots = 'none';
o = mPLSDA.options;
o.preprocessing{1} = ppX;
mPLSDA.options = o;
mPLSDA = mPLSDA.crossvalidate(cviCell, 8);
% PLSDA stores per-class misclassification as a 1xK cell, each entry 2 x nLV.
% Aggregate to a single curve before picking the optimum.
mcCurve = aggregate_misclass(mPLSDA.detail.misclassedcv, 8);
[~, optLV] = min(mcCurve);
% Fresh model at chosen LV.
mPLSDA = evrimodel('plsda');
mPLSDA.x = xCal;  mPLSDA.y = yCal;  mPLSDA.ncomp = optLV;
mPLSDA.display = 'off';  mPLSDA.plots = 'none';
o = mPLSDA.options;
o.preprocessing{1} = ppX;
mPLSDA.options = o;
mPLSDA = mPLSDA.crossvalidate(cviCell, optLV);
predPLSDA = mPLSDA.apply(xTst, yTst);
yHatPLSDA = predicted_class(predPLSDA, uniqueClasses);
results = addClassResult(results, 'PLSDA', yTstTrue, yHatPLSDA, uniqueClasses, ...
                         sprintf('LV=%d', optLV));


%% ========================================================================
%  Block C — SVMDA (RBF kernel, built-in CV grid)
%% ========================================================================
mSVMDA = evrimodel('svmda');
mSVMDA.x = xCal;  mSVMDA.y = yCal;
mSVMDA.display = 'off';  mSVMDA.plots = 'none';
o = mSVMDA.options;
o.svmtype     = 'c-svc';
o.kerneltype  = 'rbf';
o.cost        = [0.1 1 10 100];
o.gamma       = [1e-4 1e-3 1e-2 1e-1];
o.cvi         = cviCell;
o.cvtimelimit = 60;
o.preprocessing{1} = ppX;
mSVMDA.options = o;
mSVMDA = mSVMDA.calibrate;
predSVMDA = mSVMDA.apply(xTst, yTst);
yHatSVMDA = predicted_class(predSVMDA, uniqueClasses);
chosenC = getoptfield(mSVMDA, 'detail.svm.model.param.C',     NaN);
chosenG = getoptfield(mSVMDA, 'detail.svm.model.param.gamma', NaN);
results = addClassResult(results, 'SVMDA', yTstTrue, yHatSVMDA, uniqueClasses, ...
                         sprintf('C=%.3g, gamma=%.3g', chosenC, chosenG));


%% ------------------------------------------------------------------------
%  Step 2 — Print a comparison table
%% ------------------------------------------------------------------------

fprintf('\n========================================================\n');
fprintf('  CLASSIFICATION COMPARISON — %d models on arch\n', numel(results));
fprintf('========================================================\n');
fprintf('  %-8s  %12s  %s\n', 'Model', 'Class err %', 'Hyperparams');
fprintf('  %-8s  %12s  %s\n', repmat('-',1,8), repmat('-',1,12), repmat('-',1,15));
for i = 1:numel(results)
    r = results(i);
    fprintf('  %-8s  %12.2f  %s\n', r.name, 100*r.errOverall, r.hp);
end
fprintf('========================================================\n\n');


%% ------------------------------------------------------------------------
%  Step 3 — Bar chart of classification error
%% ------------------------------------------------------------------------

figure('Name', 'Classification comparison — error');
names = {results.name};
errs  = [results.errOverall];
bar(100 * errs); set(gca, 'XTickLabel', names);
ylabel('Test-set classification error (%)'); title('Classification comparison'); grid on;


%% ------------------------------------------------------------------------
%  Step 4 — Small-multiples panel of confusion matrices
%% ------------------------------------------------------------------------

figure('Name', 'Classification comparison — confusion matrices');
nM = numel(results);
nCol = ceil(sqrt(nM));
nRow = ceil(nM / nCol);
for i = 1:nM
    subplot(nRow, nCol, i);
    plot_confusion(results(i).confMat, results(i).classLabels, ...
                   sprintf('%s (err=%.1f%%)', results(i).name, 100*results(i).errOverall));
end


%% ------------------------------------------------------------------------
%  Interpretation
%% ------------------------------------------------------------------------
% The arch dataset has 4 fairly well-separated quarry classes in 10
% dimensions. In that regime:
%
%  - LDA tends to do well: with relatively few variables, low collinearity,
%    and roughly elliptical class shapes, the LDA assumptions are close
%    enough to true that the optimal-Bayes solution is hard to beat.
%  - PLSDA matches LDA closely on this data because there is not much
%    collinearity to absorb. Its strength shows up on spectral-style data
%    where p >> n and predictors are highly correlated.
%  - SVMDA with an RBF kernel can match the linear methods or even edge
%    them slightly when the true class boundaries curve, but it costs more
%    computation and gives less direct interpretability. On near-linear
%    boundaries the three classifiers usually agree to within sampling
%    noise.
%
% The takeaway: prefer LDA or PLSDA when class structure is roughly
% linear; reach for SVMDA when residual misclassifications correspond to
% samples sitting on visibly curved boundaries in score space.


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
    % Flatten PLS_Toolbox per-class misclassification (1xK cell of 2 x nLV)
    % to one column vector indexed by LV.
    if isnumeric(mc)
        v = mean(mc(:, 1:nLV), 1).';
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

function yhat = predicted_class(predObj, uniqueClasses)
    yhat = asvector(predObj.classification.mostprobable);
    if isempty(yhat) || all(isnan(yhat))
        probMat = predObj.classification.probability;
        [~, ix] = max(probMat, [], 2);
        yhat    = uniqueClasses(ix);
    end
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

function results = addClassResult(results, name, yTrue, yPred, uniqueClasses, hp)
    [C, classLabels]         = confusion_matrix(yTrue, yPred, uniqueClasses);
    [sens, spec, errOverall] = classification_metrics(C);
    results(end+1) = struct('name', name, 'errOverall', errOverall, ...
                            'sens', sens, 'spec', spec, ...
                            'confMat', C, 'classLabels', classLabels, 'hp', hp);
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
    sens = zeros(n, 1);  spec = zeros(n, 1);
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
