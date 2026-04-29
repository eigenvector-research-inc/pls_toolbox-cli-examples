%==========================================================================
%  ELASTIC-NET-OPTIMIZED EXAMPLE — Combined L1/L2 regularization with a
%  cross-validated 2-D grid search.
%
%  Dataset    : `plsdata` (toolbox/dems/plsdata.mat). Same calibration /
%               independent test split as the other regression scripts.
%  Model      : MLR with elastic-net penalty, via evrimodel('mlr') with
%               options.algorithm = 'elasticnet'. PLS_Toolbox exposes the
%               two penalty strengths as options.optimized_ridge (L2) and
%               options.optimized_lasso (L1).
%
%  You will learn
%  --------------
%  1. How to drive PLS_Toolbox's elastic-net mode through the OO API.
%  2. How to run an explicit 2-D cross-validated grid search across the
%     (L2, L1) plane — the same grid pattern you would use for any pair
%     of hyperparameters.
%  3. How to read the resulting RMSECV heatmap and the coefficient
%     sparsity profile.
%
%  What does the elastic-net mixing parameter trade off?
%  -----------------------------------------------------
%  Lasso (L1 only) produces sparse solutions: many coefficients become
%  exactly zero, which doubles as variable selection. Ridge (L2 only)
%  shrinks coefficients smoothly toward zero but rarely sets any to zero.
%  Elastic net mixes the two: the L1 part picks out a sparse subset, the
%  L2 part stabilizes the choice when several predictors are highly
%  correlated (lasso alone tends to pick one arbitrarily from a correlated
%  group). The conventional alpha-lambda parametrization writes the
%  penalty as alpha*L1 + (1-alpha)*L2, scaled by lambda. PLS_Toolbox
%  parametrizes it as two independent strengths instead, which is more
%  flexible at the cost of a slightly less standard interface.
%
%  Note on PLS_Toolbox built-ins
%  -----------------------------
%  PLS_Toolbox has a one-call optimizer: setting algorithm='elasticnet'
%  with vector grids in options.optimized_ridge and options.optimized_lasso
%  plus options.cvi runs the same grid internally. We hand-code it here so
%  the loop is visible and so we can compute per-fold RMSE for the 1-SE
%  rule.
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

% >>> USER: change to suit your data type.
ppX = preprocess('default', 'autoscale');
ppY = preprocess('default', 'mean center');


%% ------------------------------------------------------------------------
%  Step 3 — Define the (L2, L1) grid and CV partitioning
%% ------------------------------------------------------------------------
% Grids are intentionally smallish so the script runs in a reasonable
% time. For real work, use larger grids and a coarse-then-fine refinement
% strategy.

% >>> USER: widen / narrow / refine the grids for your data.
ridgeGrid = logspace(-3, 0, 8);               % L2 strengths
lassoGrid = logspace(-3, 0, 8);               % L1 strengths
nR = numel(ridgeGrid);
nL = numel(lassoGrid);

% >>> USER: change kFolds for more or fewer CV splits.
kFolds = 5;

cvAssign = mod(0:Nc-1, kFolds)' + 1;          % venetian-blinds CV assignment


%% ------------------------------------------------------------------------
%  Step 4 — Explicit 2-D cross-validated grid search
%% ------------------------------------------------------------------------

rmseFold   = nan(kFolds, nR, nL);             % fold x ridge x lasso
nonzeroAtL = nan(nR, nL);                     % # nonzero coefficients in full-cal model

fprintf('\nGrid-searching %d ridge x %d lasso = %d cells across %d folds...\n', ...
        nR, nL, nR*nL, kFolds);
totalCells = nR * nL;
cellCount  = 0;
for iR = 1:nR
    for iL = 1:nL
        cellCount = cellCount + 1;
        l2 = ridgeGrid(iR);
        l1 = lassoGrid(iL);

        for f = 1:kFolds
            idxTest = find(cvAssign == f);
            idxCal  = find(cvAssign ~= f);

            m = evrimodel('mlr');
            m.x = Xc(idxCal, :);
            m.y = yc(idxCal, :);
            m.display = 'off';
            m.plots   = 'none';

            o = m.options;
            o.algorithm        = 'elasticnet';
            o.optimized_ridge  = l2;
            o.optimized_lasso  = l1;
            o.solver           = 'coordinatedescent';
            o.silent           = true;
            o.preprocessing{1} = ppX;
            o.preprocessing{2} = ppY;
            m.options = o;

            m = m.calibrate;

            p = m.apply(Xc(idxTest, :), yc(idxTest, :));
            yhat  = asvector(p.prediction);
            ytrue = asvector(yc(idxTest, :));

            rmseFold(f, iR, iL) = sqrt(mean((ytrue - yhat).^2));
        end

        % Also fit on full calibration data to record sparsity at this cell.
        mFull = evrimodel('mlr');
        mFull.x = Xc;  mFull.y = yc;  mFull.display = 'off';  mFull.plots = 'none';
        o = mFull.options;
        o.algorithm        = 'elasticnet';
        o.optimized_ridge  = l2;
        o.optimized_lasso  = l1;
        o.solver           = 'coordinatedescent';
        o.silent           = true;
        o.preprocessing{1} = ppX;
        o.preprocessing{2} = ppY;
        mFull.options = o;
        mFull = mFull.calibrate;
        coefs = mFull.reg(:);
        tol   = max(abs(coefs)) * 1e-4 + eps;
        nonzeroAtL(iR, iL) = sum(abs(coefs) > tol);

        if mod(cellCount, 8) == 0
            fprintf('  ...%d/%d cells\n', cellCount, totalCells);
        end
    end
end

rmsecv_mean = squeeze(mean(rmseFold, 1));     % nR x nL
rmsecv_se   = squeeze(std(rmseFold, 0, 1)) ./ sqrt(kFolds);


%% ------------------------------------------------------------------------
%  Step 5 — Pick min and 1-SE cells
%% ------------------------------------------------------------------------
% Min picks the lowest-RMSECV cell. The 1-SE rule looks across all cells
% within 1 SE of that minimum and picks the SPARSEST one — the cell with
% the strongest L1 penalty (and, as a tiebreak, the strongest L2). This
% favors interpretable, parsimonious models when the validation surface
% is flat near the optimum.

[minVal, minIdx] = min(rmsecv_mean(:));
[iR_min, iL_min] = ind2sub(size(rmsecv_mean), minIdx);
threshold        = minVal + rmsecv_se(iR_min, iL_min);

% Indices of cells within 1 SE of the min
withinSE = rmsecv_mean <= threshold;

% Among those, pick the one with the FEWEST nonzero coefficients (sparsest).
sparseScores       = nonzeroAtL;
sparseScores(~withinSE) = Inf;
[~, sparseIdx]     = min(sparseScores(:));
[iR_1SE, iL_1SE]   = ind2sub(size(sparseScores), sparseIdx);

ridgeMin = ridgeGrid(iR_min);
lassoMin = lassoGrid(iL_min);
ridge1SE = ridgeGrid(iR_1SE);
lasso1SE = lassoGrid(iL_1SE);

fprintf('\nMin cell  : ridge=%.4g, lasso=%.4g  (RMSECV = %.4f, nonzero coefs = %d)\n', ...
        ridgeMin, lassoMin, minVal, nonzeroAtL(iR_min, iL_min));
fprintf('1-SE cell : ridge=%.4g, lasso=%.4g  (RMSECV = %.4f, nonzero coefs = %d)\n', ...
        ridge1SE, lasso1SE, rmsecv_mean(iR_1SE, iL_1SE), nonzeroAtL(iR_1SE, iL_1SE));

% >>> USER: switch to (ridgeMin, lassoMin) for the unbiased optimum.
ridgeChosen = ridge1SE;
lassoChosen = lasso1SE;


%% ------------------------------------------------------------------------
%  Step 6 — Refit at the chosen cell and apply to the test block
%% ------------------------------------------------------------------------

model = evrimodel('mlr');
model.x = Xc;  model.y = yc;
model.display = 'off';  model.plots = 'none';

opts = model.options;
opts.algorithm        = 'elasticnet';
opts.optimized_ridge  = ridgeChosen;
opts.optimized_lasso  = lassoChosen;
opts.solver           = 'coordinatedescent';
opts.silent           = true;
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

% Count surviving (nonzero) predictors at the chosen cell.
finalCoefs   = model.reg(:);
finalTol     = max(abs(finalCoefs)) * 1e-4 + eps;
finalNonzero = sum(abs(finalCoefs) > finalTol);


%% ------------------------------------------------------------------------
%  Step 7 — Plots: RMSECV heatmap, sparsity profile, predictions
%% ------------------------------------------------------------------------

figure('Name', 'Elastic Net — diagnostics');

% RMSECV heatmap with X markers on min and 1-SE cells
subplot(2, 2, 1);
imagesc(log10(lassoGrid), log10(ridgeGrid), rmsecv_mean);
set(gca, 'YDir', 'normal'); colorbar;
hold on;
plot(log10(lassoMin), log10(ridgeMin), 'wx', 'MarkerSize', 14, 'LineWidth', 2);
plot(log10(lasso1SE), log10(ridge1SE), 'wo', 'MarkerSize', 14, 'LineWidth', 2);
xlabel('log_{10} lasso (L1)'); ylabel('log_{10} ridge (L2)');
title('RMSECV across grid (x = min, o = 1-SE)'); hold off;

% Sparsity profile along the chosen ridge slice
subplot(2, 2, 2);
plot(log10(lassoGrid), nonzeroAtL(iR_1SE, :), '-o', 'MarkerFaceColor','auto');
xline(log10(lassoChosen), '--k', '\lambda_{1, chosen}');
xlabel('log_{10} lasso (L1)'); ylabel('# nonzero coefficients');
title(sprintf('Sparsity at ridge = %.3g', ridge1SE)); grid on;

% Final regression vector
subplot(2, 2, 3);
stem(model.reg, 'filled');
xlabel('Variable index'); ylabel('Regression coefficient');
title(sprintf('Reg vector @ ridge=%.3g, lasso=%.3g (%d nonzero)', ...
              ridgeChosen, lassoChosen, finalNonzero)); grid on;

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
fprintf('  Model             : Elastic Net (MLR with L1+L2 penalty)\n');
fprintf('  Preprocessing (X) : autoscale\n');
fprintf('  Preprocessing (Y) : mean center\n');
fprintf('  Grid              : %d ridge x %d lasso = %d cells\n', nR, nL, nR*nL);
fprintf('  CV scheme         : venetian blinds, %d folds\n', kFolds);
fprintf('  Min cell          : ridge = %.4g, lasso = %.4g\n', ridgeMin, lassoMin);
fprintf('  1-SE cell (chosen): ridge = %.4g, lasso = %.4g\n', ridgeChosen, lassoChosen);
fprintf('  Nonzero coefs     : %d / %d\n', finalNonzero, numel(finalCoefs));
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
