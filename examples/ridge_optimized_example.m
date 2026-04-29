%==========================================================================
%  RIDGE-OPTIMIZED EXAMPLE — L2-regularized regression with explicit
%  cross-validated grid search and the one-standard-error rule.
%
%  Dataset    : `plsdata` (toolbox/dems/plsdata.mat). Same calibration /
%               independent test split as the other regression scripts.
%  Model      : MLR with L2 regularization, via evrimodel('mlr') with
%               options.algorithm = 'ridge' and options.ridge = lambda.
%
%  You will learn
%  --------------
%  1. How to drive PLS_Toolbox's MLR in ridge mode through the OO API.
%  2. How to run an explicit cross-validated grid search over lambda by
%     hand — the loop you would adapt to any regularization parameter.
%  3. How to compute per-fold RMSE so you can apply the one-standard-error
%     (1-SE) rule, not just argmin.
%  4. How to read a coefficient path: which predictors survive shrinkage
%     and which collapse first.
%
%  Why L2 regularization?
%  ----------------------
%  When predictors are collinear, the unregularized normal equations are
%  ill-conditioned: tiny changes in y produce wild changes in the
%  regression vector. L2 regularization adds lambda * I to X'X before
%  inversion, which shrinks the regression coefficients toward zero in
%  proportion to lambda. Coefficients shrink but rarely become exactly
%  zero — that's the L1 (lasso) behaviour, demonstrated in the elastic-net
%  script.
%
%  Note on PLS_Toolbox built-ins
%  -----------------------------
%  PLS_Toolbox MLR also has a one-call optimizer: setting
%       options.algorithm = 'optimized_ridge'
%       options.optimized_ridge = your_lambda_grid
%       options.cvi = {'vet', 10}
%  performs the same grid search internally. We hand-code the loop here
%  for pedagogy — it is the same pattern you would write for ANY
%  hyperparameter and the only way to get per-fold information for the
%  1-SE rule.
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

% >>> USER: replace with your own DSOs.
load plsdata
Xc = xblock1;  yc = yblock1;
Xt = xblock2;  yt = yblock2;

Nc = size(Xc, 1);
fprintf('Calibration: %dx%d, test: %dx%d\n', Nc, size(Xc,2), size(Xt,1), size(Xt,2));


%% ------------------------------------------------------------------------
%  Step 2 — Define preprocessing
%% ------------------------------------------------------------------------
% Autoscale X is essential for ridge: lambda penalizes ALL coefficients
% equally, so variables on different scales would be penalized unequally
% if you did not standardize them first.

% >>> USER: change to suit your data type.
ppX = preprocess('default', 'autoscale');
ppY = preprocess('default', 'mean center');


%% ------------------------------------------------------------------------
%  Step 3 — Define the lambda grid and CV partitioning
%% ------------------------------------------------------------------------
% A geometric grid spans many orders of magnitude of regularization
% strength. log10(lambda) from -4 to 2 gives 25 points. Adjust the bounds
% if your validation curve hits the edge of the range.

% >>> USER: widen / narrow the lambda grid as needed for your data.
lambdaGrid = logspace(-4, 2, 25);
nL         = numel(lambdaGrid);

% >>> USER: change kFolds for more or fewer CV splits.
kFolds = 10;

% Venetian-blinds CV assignment, identical to PLS_Toolbox's {'vet', k}.
cvAssign = mod(0:Nc-1, kFolds)' + 1;          % length Nc, values 1..kFolds


%% ------------------------------------------------------------------------
%  Step 4 — Cross-validated grid search (the explicit loop)
%% ------------------------------------------------------------------------
% For each lambda, we calibrate on (k-1) folds and predict on the held-out
% fold, repeating until every sample has been predicted once. We collect
% the per-fold RMSE so we can compute both the mean RMSECV and its
% standard error across folds.

rmseFold   = nan(kFolds, nL);                 % rows = fold, cols = lambda
betaPath   = nan(size(Xc, 2), nL);            % regression vectors at each lambda

fprintf('\nGrid-searching %d lambdas across %d folds...\n', nL, kFolds);
for iL = 1:nL
    lambda = lambdaGrid(iL);

    for f = 1:kFolds
        idxTest = find(cvAssign == f);
        idxCal  = find(cvAssign ~= f);

        Xc_fold = Xc(idxCal, :);
        yc_fold = yc(idxCal, :);
        Xt_fold = Xc(idxTest, :);
        yt_fold = yc(idxTest, :);

        m = evrimodel('mlr');
        m.x = Xc_fold;
        m.y = yc_fold;
        m.display = 'off';
        m.plots   = 'none';

        o = m.options;
        o.algorithm        = 'ridge';
        o.ridge            = lambda;
        o.preprocessing{1} = ppX;
        o.preprocessing{2} = ppY;
        m.options = o;

        m = m.calibrate;

        p = m.apply(Xt_fold, yt_fold);
        yhat = asvector(p.prediction);
        ytrue = asvector(yt_fold);

        rmseFold(f, iL) = sqrt(mean((ytrue - yhat).^2));
    end

    % Also record the regression vector trained on ALL calibration data at
    % this lambda — this is the coefficient path used in the diagnostic plot.
    mFull = evrimodel('mlr');
    mFull.x = Xc;  mFull.y = yc;  mFull.display = 'off';  mFull.plots = 'none';
    o = mFull.options;
    o.algorithm        = 'ridge';
    o.ridge            = lambda;
    o.preprocessing{1} = ppX;
    o.preprocessing{2} = ppY;
    mFull.options = o;
    mFull = mFull.calibrate;
    betaPath(:, iL) = mFull.reg(:);
end

rmsecv_mean = mean(rmseFold, 1);
rmsecv_se   = std(rmseFold, 0, 1) ./ sqrt(kFolds);


%% ------------------------------------------------------------------------
%  Step 5 — Apply two selection rules: minimum and 1-SE
%% ------------------------------------------------------------------------
% Minimum-RMSECV picks whichever lambda gave the lowest cross-validated
% error. The 1-SE rule picks the SIMPLEST (largest-lambda, most-shrunk)
% model whose RMSECV is within one standard error of the minimum.
% Pedagogical aside: the 1-SE rule favors stronger regularization when
% the validation curve is flat near the optimum — a common situation
% where the data simply do not distinguish between a range of lambdas.
% Choosing the simpler model in that case tends to generalize better and
% produces more interpretable coefficients.

[~, iMin] = min(rmsecv_mean);
threshold = rmsecv_mean(iMin) + rmsecv_se(iMin);

% Largest lambda whose RMSECV is within 1 SE of the minimum (lambdaGrid is sorted ascending).
withinSE = find(rmsecv_mean <= threshold);
i1SE     = max(withinSE);

lambdaMin = lambdaGrid(iMin);
lambda1SE = lambdaGrid(i1SE);

fprintf('\nlambda_min = %.4g  (RMSECV = %.4f)\n', lambdaMin, rmsecv_mean(iMin));
fprintf('lambda_1SE = %.4g  (RMSECV = %.4f, simpler model within 1 SE)\n', ...
        lambda1SE, rmsecv_mean(i1SE));

% >>> USER: change to lambdaMin if you prefer the unbiased (lower-RMSECV) optimum.
lambdaChosen = lambda1SE;


%% ------------------------------------------------------------------------
%  Step 6 — Refit at the chosen lambda and apply to the test block
%% ------------------------------------------------------------------------

model = evrimodel('mlr');
model.x = Xc;  model.y = yc;
model.display = 'off';  model.plots = 'none';

opts = model.options;
opts.algorithm        = 'ridge';
opts.ridge            = lambdaChosen;
opts.preprocessing{1} = ppX;
opts.preprocessing{2} = ppY;
model.options = opts;

model = model.calibrate;
pred  = model.apply(Xt, yt);

y_c    = asvector(yc);
y_t    = asvector(yt);
yhat_c = asvector(model.prediction);
yhat_t = asvector(pred.prediction);

[rmseC, r2C, biasC] = regression_metrics(y_c, yhat_c);
[rmseP, r2P, biasP] = regression_metrics(y_t, yhat_t);


%% ------------------------------------------------------------------------
%  Step 7 — Plots: validation curve, coefficient path, and predictions
%% ------------------------------------------------------------------------

figure('Name', 'Ridge — diagnostics');

% Validation curve with +/- 1 SE
subplot(2, 2, 1);
errorbar(log10(lambdaGrid), rmsecv_mean, rmsecv_se, '-o', 'MarkerFaceColor','auto'); hold on;
yline(threshold, '--', '1-SE threshold');
xline(log10(lambdaMin), '--g', 'lambda_{min}');
xline(log10(lambda1SE), '--r', 'lambda_{1SE}');
xlabel('log_{10} lambda'); ylabel('RMSECV');
title('Validation curve (+/- 1 SE)'); grid on; hold off;

% Coefficient path
subplot(2, 2, 2);
semilogx(lambdaGrid, betaPath', '-');
hold on; xline(lambdaChosen, '--k', '\lambda_{chosen}');
xlabel('lambda (log scale)'); ylabel('Regression coefficient');
title('Coefficient shrinkage path'); grid on; hold off;

% Regression vector at chosen lambda
subplot(2, 2, 3);
stem(model.reg, 'filled');
xlabel('Variable index'); ylabel('Regression coefficient');
title(sprintf('Regression vector @ lambda=%.3g', lambdaChosen)); grid on;

% Measured vs predicted
subplot(2, 2, 4);
plot(y_c, yhat_c, 'o', 'MarkerFaceColor', [.2 .4 .8], 'MarkerEdgeColor','none', 'DisplayName','Calibration'); hold on;
plot(y_t, yhat_t, 's', 'MarkerFaceColor', [.8 .3 .2], 'MarkerEdgeColor','none', 'DisplayName','Test');
yl = [min([y_c; y_t; yhat_c; yhat_t]), max([y_c; y_t; yhat_c; yhat_t])];
plot(yl, yl, 'k--', 'DisplayName','y = y_{hat}');
xlabel('Measured y'); ylabel('Predicted y'); title('Measured vs. predicted');
legend('Location','best'); axis equal tight; grid on; hold off;


%% ------------------------------------------------------------------------
%  Step 8 — Summary
%% ------------------------------------------------------------------------

fprintf('\n========================================================\n');
fprintf('  %s — SUMMARY\n', mfilename);
fprintf('========================================================\n');
fprintf('  Dataset           : plsdata (X: %dx%d, y: %dx1)\n', size(Xc,1), size(Xc,2), size(yc,1));
fprintf('  Model             : Ridge (MLR with L2 penalty)\n');
fprintf('  Preprocessing (X) : autoscale\n');
fprintf('  Preprocessing (Y) : mean center\n');
fprintf('  Grid              : %d lambdas, log10 in [%.1f, %.1f]\n', nL, log10(lambdaGrid(1)), log10(lambdaGrid(end)));
fprintf('  CV scheme         : venetian blinds, %d folds\n', kFolds);
fprintf('  lambda_min        : %.4g  (RMSECV = %.4f)\n', lambdaMin, rmsecv_mean(iMin));
fprintf('  lambda_1SE        : %.4g  (RMSECV = %.4f) <-- chosen\n', lambda1SE, rmsecv_mean(i1SE));
fprintf('  Calibration RMSEC : %.4f   R^2 = %.4f   bias = %+.4f\n', rmseC, r2C, biasC);
fprintf('  Test set    RMSEP : %.4f   R^2 = %.4f   bias = %+.4f\n', rmseP, r2P, biasP);
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

function [rmse, r2, bias] = regression_metrics(y, yhat)
    e    = y - yhat;
    rmse = sqrt(mean(e.^2));
    bias = mean(e);
    r2   = 1 - sum(e.^2) / sum((y - mean(y)).^2);
end
