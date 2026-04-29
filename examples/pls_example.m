%==========================================================================
%  PLS EXAMPLE — Partial Least Squares regression
%
%  Dataset    : `plsdata` ships with PLS_Toolbox in toolbox/dems/plsdata.mat
%               It contains four DSOs: xblock1 / yblock1 (calibration) and
%               xblock2 / yblock2 (independent test set). The X-blocks are
%               300x20 and the Y is a single response — a classic small
%               regression dataset with strongly collinear predictors.
%  Model      : PLS regression via evrimodel('pls')
%
%  You will learn
%  --------------
%  1. How to build a PLS model with the OO workflow.
%  2. How cross-validation guides the choice of latent variables (LVs).
%  3. How to evaluate a model on an independent test block (RMSEC vs
%     RMSECV vs RMSEP, and what each tells you).
%  4. How to read scores, regression vectors, and residuals.
%
%  Why PLS often beats PCR with fewer components
%  ---------------------------------------------
%  PCR builds latent variables that maximize variance in X alone. If a
%  high-variance direction in X is unrelated to Y, PCR still includes it
%  and burns components on noise. PLS instead builds latent variables that
%  maximize the covariance between X and Y — the directions retained are
%  selected for being predictive, not just energetic. On collinear,
%  Y-relevant data, PLS routinely achieves a given RMSE with fewer LVs.
%
%  Prerequisites
%  -------------
%  - MATLAB (base only — no MathWorks toolboxes required)
%  - PLS_Toolbox v9.0+ on the MATLAB path
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
% plsdata loads four DSOs into the workspace:
%   xblock1 / yblock1 = calibration set (300x20, 300x1)
%   xblock2 / yblock2 = independent validation/test set
% Working with a pre-defined cal/test split keeps every regression script
% in this series directly comparable.

% >>> USER: replace these four lines with your own DSOs (Xc, yc, Xt, yt). Ensure each is a DataSet Object.
load plsdata
Xc = xblock1;
yc = yblock1;
Xt = xblock2;
yt = yblock2;

fprintf('Calibration: %dx%d, test: %dx%d\n', size(Xc,1), size(Xc,2), size(Xt,1), size(Xt,2));


%% ------------------------------------------------------------------------
%  Step 2 — Define preprocessing
%% ------------------------------------------------------------------------
% Autoscaling X (mean center + unit-variance scale) is appropriate when
% predictor variables are on heterogeneous scales. Mean-centering Y is
% the standard for regression — it removes the constant term so the
% regression vector reflects only the slope.

% >>> USER: for spectral data, consider 'snv' or 'derivative' on X. Pure mean-centering on X is also common when variables share units.
ppX = preprocess('default', 'autoscale');
ppY = preprocess('default', 'mean center');


%% ------------------------------------------------------------------------
%  Step 3 — Build and cross-validate the model
%% ------------------------------------------------------------------------
% .crossvalidate calibrates the model AND runs cross-validation in one
% step. The CV scheme is set via the cvi cell array. Venetian blinds
% ('vet') with 10 splits is a robust default for ordered or unordered
% samples. After this call, model.detail.rmsecv is a vector indexed by
% number of LVs — exactly what we need to pick a model.

% >>> USER: pick a maximum LV count that comfortably exceeds where you expect the optimum.
maxLV = 15;

% >>> USER: change cvi to {'rnd', 10, 5} for repeated random splits, or {'loo'} for leave-one-out.
cvi = {'vet', 10};

model = evrimodel('pls');
model.x     = Xc;
model.y     = yc;
model.ncomp = maxLV;
model.display = 'off';
model.plots   = 'none';

opts = model.options;
opts.preprocessing{1} = ppX;
opts.preprocessing{2} = ppY;
model.options = opts;

model = model.crossvalidate(cvi, maxLV);


%% ------------------------------------------------------------------------
%  Step 4 — Choose the optimal number of LVs from the CV curve
%% ------------------------------------------------------------------------
% Two defensible rules:
%   (a) Minimum-RMSECV     — pick whichever LV gives the lowest CV error.
%   (b) One-standard-error — pick the SIMPLEST model whose RMSECV is
%       within 1 standard error of the minimum. Favors parsimony and
%       tends to generalize better when the curve is flat near the optimum.
% This script uses rule (a). To apply rule (b), you would need per-fold
% RMSECV (model.detail.split_*) to estimate the standard error.

rmsecv = model.detail.rmsecv(:);              % column vector, length maxLV
rmsec  = model.detail.rmsec(:);
[~, optLV] = min(rmsecv);
fprintf('\nOptimal LV by minimum RMSECV: %d\n', optLV);

% Build a FRESH model at the chosen LV. EVRIModel makes ncomp read-only
% once the model has been calibrated, so mutating the existing model is
% not allowed — create a new one instead.
model = evrimodel('pls');
model.x     = Xc;
model.y     = yc;
model.ncomp = optLV;
model.display = 'off';
model.plots   = 'none';
opts = model.options;
opts.preprocessing{1} = ppX;
opts.preprocessing{2} = ppY;
model.options = opts;
model = model.crossvalidate(cvi, optLV);


%% ------------------------------------------------------------------------
%  Step 5 — Apply to the independent test set and compute RMSEP
%% ------------------------------------------------------------------------
% .apply pushes Xt through the model's stored preprocessing AND its PLS
% regression. Passing yt as well lets the prediction object compute test
% statistics for us.

pred = model.apply(Xt, yt);

yhat_t = pred.prediction;                     % predicted y for test set
yhat_c = model.prediction;                    % predicted y for calibration set

% Convert any DSOs to plain vectors for downstream metrics.
y_c    = asvector(yc);
y_t    = asvector(yt);
yhat_c = asvector(yhat_c);
yhat_t = asvector(yhat_t);

[rmseC, r2C, biasC] = regression_metrics(y_c, yhat_c);
[rmseP, r2P, biasP] = regression_metrics(y_t, yhat_t);

% R^2 from cross-validation, derived from RMSECV and total sum of squares.
% Equivalent to R^2 computed from per-fold predictions when CV folds are balanced.
ss_tot = sum((y_c - mean(y_c)).^2);
r2CV   = 1 - (rmsecv(optLV)^2 * numel(y_c)) / ss_tot;


%% ------------------------------------------------------------------------
%  Step 6 — Plot CV curve, regression vector, and measured-vs-predicted
%% ------------------------------------------------------------------------

figure('Name', 'PLS — diagnostics');

% RMSECV vs LV
subplot(2, 2, 1);
plot(1:maxLV, rmsecv, '-o', 'MarkerFaceColor','auto'); hold on;
plot(1:maxLV, rmsec,  '-s', 'MarkerFaceColor','auto');
xline(optLV, '--k', sprintf('Chosen LV = %d', optLV));
xlabel('# Latent variables'); ylabel('RMSE');
legend({'RMSECV','RMSEC'}, 'Location','best');
title('Component selection'); grid on; hold off;

% Regression vector
subplot(2, 2, 2);
plot(model.reg, '-'); xlabel('Variable index'); ylabel('Regression coefficient');
title(sprintf('Regression vector @ LV=%d', optLV)); grid on;

% Scores LV1 vs LV2
subplot(2, 2, 3);
plot(model.scores(:,1), model.scores(:,2), 'o', 'MarkerFaceColor', [.2 .4 .8], 'MarkerEdgeColor','none');
xlabel('LV1'); ylabel('LV2'); title('Calibration scores'); grid on;

% Measured vs predicted
subplot(2, 2, 4);
plot(y_c, yhat_c, 'o', 'MarkerFaceColor', [.2 .4 .8], 'MarkerEdgeColor','none', 'DisplayName','Calibration'); hold on;
plot(y_t, yhat_t, 's', 'MarkerFaceColor', [.8 .3 .2], 'MarkerEdgeColor','none', 'DisplayName','Test');
yl = [min([y_c; y_t; yhat_c; yhat_t]), max([y_c; y_t; yhat_c; yhat_t])];
plot(yl, yl, 'k--', 'DisplayName','y = y_{hat}');
xlabel('Measured y'); ylabel('Predicted y'); title('Measured vs. predicted');
legend('Location','best'); axis equal tight; grid on; hold off;


%% ------------------------------------------------------------------------
%  Step 7 — Summary
%% ------------------------------------------------------------------------

fprintf('\n========================================================\n');
fprintf('  %s — SUMMARY\n', mfilename);
fprintf('========================================================\n');
fprintf('  Dataset           : plsdata (X: %dx%d, y: %dx1)\n', size(Xc,1), size(Xc,2), size(yc,1));
fprintf('  Model             : PLS-1\n');
fprintf('  Preprocessing (X) : autoscale\n');
fprintf('  Preprocessing (Y) : mean center\n');
fprintf('  CV scheme         : venetian blinds, 10 splits\n');
fprintf('  Optimal LVs       : %d (chosen by min RMSECV)\n', optLV);
fprintf('  Calibration RMSEC : %.4f   R^2 = %.4f   bias = %+.4f\n', rmseC, r2C, biasC);
fprintf('  Cross-val   RMSECV: %.4f   R^2 = %.4f\n', rmsecv(optLV), r2CV);
fprintf('  Test set    RMSEP : %.4f   R^2 = %.4f   bias = %+.4f\n', rmseP, r2P, biasP);
fprintf('========================================================\n\n');


%% ------------------------------------------------------------------------
%  Local helpers (base MATLAB only, no toolbox dependencies)
%% ------------------------------------------------------------------------

function v = asvector(x)
    % Convert a DSO or matrix to a column vector, taking the first column if 2-D.
    if isa(x, 'dataset')
        x = x.data;
    end
    x = double(x);
    if size(x, 2) > 1
        x = x(:, 1);
    end
    v = x(:);
end

function [rmse, r2, bias] = regression_metrics(y, yhat)
    e    = y - yhat;
    rmse = sqrt(mean(e.^2));
    bias = mean(e);
    r2   = 1 - sum(e.^2) / sum((y - mean(y)).^2);
end
