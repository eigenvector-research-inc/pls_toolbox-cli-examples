%==========================================================================
%  SVMR EXAMPLE — Support Vector Machine Regression
%
%  Dataset    : `plsdata` (toolbox/dems/plsdata.mat). Same calibration /
%               independent test split as the other regression scripts.
%  Model      : epsilon-SVR with an RBF kernel via evrimodel('svm').
%               PLS_Toolbox's SVM function performs CV-based selection
%               of cost (C), gamma, and epsilon when those options are
%               passed as vectors.
%
%  You will learn
%  --------------
%  1. The OO workflow for SVM regression.
%  2. How to set up a CV grid over (cost, gamma, epsilon) using small,
%     intentionally tractable ranges.
%  3. How to use svmcvplot to inspect the CV grid.
%  4. Why kernel SVMs are sensitive to feature scaling.
%
%  Linear vs RBF kernel — when nonlinearity helps
%  ----------------------------------------------
%  A linear-kernel SVM is essentially L2-regularized regression with an
%  insensitive-zone loss; it learns the same kind of structure that ridge
%  or PLS does. The RBF (Gaussian) kernel adds nonlinearity by mapping
%  every pair of samples to a similarity in a high-dimensional implicit
%  space — useful when the true relationship between X and y curves or
%  bends. On collinear, near-linear data like plsdata, RBF-SVMR is
%  unlikely to outperform PLS / ridge, and that is exactly the kind of
%  observation the regression-comparison script makes concrete.
%
%  Why scale matters
%  -----------------
%  RBF distances are dimensionful: variables on a larger scale dominate
%  the kernel. Autoscaling X removes this asymmetry so gamma is interpretable
%  as a relative bandwidth.
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

% >>> USER: replace with your own DSOs (Xc, yc, Xt, yt).
load plsdata
Xc = xblock1;  yc = yblock1;
Xt = xblock2;  yt = yblock2;

fprintf('Calibration: %dx%d, test: %dx%d\n', size(Xc,1), size(Xc,2), size(Xt,1), size(Xt,2));


%% ------------------------------------------------------------------------
%  Step 2 — Define preprocessing
%% ------------------------------------------------------------------------
% Always autoscale X for an RBF kernel SVM.

% >>> USER: change for your data type.
ppX = preprocess('default', 'autoscale');


%% ------------------------------------------------------------------------
%  Step 3 — Build the SVM-R model with a CV grid
%% ------------------------------------------------------------------------
% Passing vectors for cost / gamma / epsilon triggers PLS_Toolbox's
% built-in CV grid search inside the SVM function. The cvi field
% controls the splitting scheme. cvtimelimit caps the time per cell so
% one slow corner of the grid cannot wedge the whole sweep.

model = evrimodel('svm');
model.x = Xc;
model.y = yc;
model.display = 'off';
model.plots   = 'none';

opts = model.options;
opts.svmtype          = 'epsilon-svr';
opts.kerneltype       = 'rbf';

% >>> USER: widen these grids if the chosen optimum lands at a boundary.
opts.cost             = [0.1 1 10 100];
opts.gamma            = [1e-4 1e-3 1e-2 1e-1];
opts.epsilon          = [0.01 0.1];

opts.cvi              = {'vet', 5};
opts.cvtimelimit      = 60;                   % seconds per (cost, gamma, epsilon) cell

opts.preprocessing{1} = ppX;
model.options = opts;

fprintf('\nCalibrating SVM-R with built-in CV grid (this may take a few seconds)...\n');
model = model.calibrate;


%% ------------------------------------------------------------------------
%  Step 4 — Inspect the CV grid
%% ------------------------------------------------------------------------
% svmcvplot visualizes the CV result over any pair of the swept
% hyperparameters. The optimum is marked with an X. If the X sits next
% to the boundary, widen the corresponding range and re-run.

try
    svmcvplot(model, {'cost', 'gamma'});
catch err
    warning('svmcvplot failed: %s', err.message);
end

% Extract the chosen hyperparameters. libsvm exposes them on
% model.detail.svm.model.param: C is cost, gamma is the RBF bandwidth,
% and p is the epsilon-tube width (libsvm's name for epsilon-SVR's eps).
chosenCost    = getoptfield(model, 'detail.svm.model.param.C',     NaN);
chosenGamma   = getoptfield(model, 'detail.svm.model.param.gamma', NaN);
chosenEpsilon = getoptfield(model, 'detail.svm.model.param.p',     NaN);


%% ------------------------------------------------------------------------
%  Step 5 — Apply to the test block
%% ------------------------------------------------------------------------

pred = model.apply(Xt, yt);

y_c    = asvector(yc);
y_t    = asvector(yt);
yhat_c = asvector(model.prediction);
yhat_t = asvector(pred.prediction);

[rmseC, r2C, biasC] = regression_metrics(y_c, yhat_c);
[rmseP, r2P, biasP] = regression_metrics(y_t, yhat_t);


%% ------------------------------------------------------------------------
%  Step 6 — Plots
%% ------------------------------------------------------------------------

figure('Name', 'SVM-R — predictions');

% Measured vs predicted
subplot(1, 2, 1);
plot(y_c, yhat_c, 'o', 'MarkerFaceColor', [.2 .4 .8], 'MarkerEdgeColor','none', 'DisplayName','Calibration'); hold on;
plot(y_t, yhat_t, 's', 'MarkerFaceColor', [.8 .3 .2], 'MarkerEdgeColor','none', 'DisplayName','Test');
yl = [min([y_c; y_t; yhat_c; yhat_t]), max([y_c; y_t; yhat_c; yhat_t])];
plot(yl, yl, 'k--', 'DisplayName','y = y_{hat}');
xlabel('Measured y'); ylabel('Predicted y'); title('Measured vs. predicted');
legend('Location','best'); axis equal tight; grid on; hold off;

% Residuals vs predicted (test set)
subplot(1, 2, 2);
res_t = y_t - yhat_t;
plot(yhat_t, res_t, 's', 'MarkerFaceColor', [.8 .3 .2], 'MarkerEdgeColor','none');
yline(0, 'k--');
xlabel('Predicted y (test)'); ylabel('Residual'); title('Test-set residuals'); grid on;


%% ------------------------------------------------------------------------
%  Step 7 — Summary
%% ------------------------------------------------------------------------

fprintf('\n========================================================\n');
fprintf('  %s — SUMMARY\n', mfilename);
fprintf('========================================================\n');
fprintf('  Dataset           : plsdata (X: %dx%d, y: %dx1)\n', size(Xc,1), size(Xc,2), size(yc,1));
fprintf('  Model             : SVM-R, epsilon-SVR with RBF kernel\n');
fprintf('  Preprocessing (X) : autoscale\n');
fprintf('  Grid (cost)       : %s\n',  sprintf('%g ', opts.cost));
fprintf('  Grid (gamma)      : %s\n',  sprintf('%g ', opts.gamma));
fprintf('  Grid (epsilon)    : %s\n',  sprintf('%g ', opts.epsilon));
fprintf('  Chosen cost       : %g\n',  chosenCost);
fprintf('  Chosen gamma      : %g\n',  chosenGamma);
fprintf('  Chosen epsilon    : %g\n',  chosenEpsilon);
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

function val = getoptfield(model, dottedPath, defaultVal)
    % Safely fetch a possibly-nested field from a model object.
    val = defaultVal;
    try
        parts = strsplit(dottedPath, '.');
        v = model;
        for k = 1:numel(parts)
            v = v.(parts{k});
        end
        if isnumeric(v) && ~isempty(v)
            val = v;
        end
    catch
        % field missing in this model version; keep defaultVal
    end
end
