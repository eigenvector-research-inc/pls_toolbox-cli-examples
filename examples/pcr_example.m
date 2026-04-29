%==========================================================================
%  PCR EXAMPLE — Principal Component Regression
%
%  Dataset    : `plsdata` (toolbox/dems/plsdata.mat). Same calibration /
%               independent test split as the PLS example so the two
%               methods can be compared directly on identical data.
%  Model      : PCR via evrimodel('pcr')
%
%  You will learn
%  --------------
%  1. The OO PCR workflow (mirrors PLS but with a different latent basis).
%  2. How to choose the number of PCs from the cross-validation curve.
%  3. Why PCR can need MORE components than PLS to reach a given RMSE.
%
%  PCR vs PLS in one paragraph
%  ---------------------------
%  PCR is a two-step recipe: do PCA on X (variance only — Y is ignored),
%  then ordinary least squares of Y onto the leading PCA scores. PLS
%  builds latent variables that maximize covariance with Y, so each LV is
%  selected for being predictive. On highly collinear data where the
%  Y-relevant directions are NOT the highest-variance directions in X,
%  PCR will burn components on noise before reaching the signal.
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

% >>> USER: replace with your own DataSet Objects (Xc, yc, Xt, yt).
load plsdata
Xc = xblock1;  yc = yblock1;
Xt = xblock2;  yt = yblock2;

fprintf('Calibration: %dx%d, test: %dx%d\n', size(Xc,1), size(Xc,2), size(Xt,1), size(Xt,2));


%% ------------------------------------------------------------------------
%  Step 2 — Define preprocessing
%% ------------------------------------------------------------------------
% Same preprocessing choices as the PLS example so PCR and PLS results
% are directly comparable.

% >>> USER: change these to suit your data type (e.g., 'snv' for spectra).
ppX = preprocess('default', 'autoscale');
ppY = preprocess('default', 'mean center');


%% ------------------------------------------------------------------------
%  Step 3 — Build and cross-validate
%% ------------------------------------------------------------------------

% >>> USER: pick a maximum component count comfortably above the expected optimum.
maxPC = 15;

% >>> USER: change cvi for different CV strategies. {'rnd', k, r} for repeated random.
cvi = {'vet', 10};

model = evrimodel('pcr');
model.x     = Xc;
model.y     = yc;
model.ncomp = maxPC;
model.display = 'off';
model.plots   = 'none';

opts = model.options;
opts.preprocessing{1} = ppX;
opts.preprocessing{2} = ppY;
model.options = opts;

model = model.crossvalidate(cvi, maxPC);


%% ------------------------------------------------------------------------
%  Step 4 — Choose ncomp by minimum RMSECV
%% ------------------------------------------------------------------------
% Minimum-RMSECV is direct and easy to communicate. The 1-SE rule
% (smallest model within 1 SE of the minimum) is a common alternative
% that prefers parsimony — useful when the curve is flat near the optimum.

rmsecv = model.detail.rmsecv(:);
rmsec  = model.detail.rmsec(:);
[~, optPC] = min(rmsecv);
fprintf('\nOptimal #PCs by minimum RMSECV: %d\n', optPC);

% Build a FRESH model at the chosen #PCs (ncomp is read-only after calibration).
model = evrimodel('pcr');
model.x     = Xc;
model.y     = yc;
model.ncomp = optPC;
model.display = 'off';
model.plots   = 'none';
opts = model.options;
opts.preprocessing{1} = ppX;
opts.preprocessing{2} = ppY;
model.options = opts;
model = model.crossvalidate(cvi, optPC);


%% ------------------------------------------------------------------------
%  Step 5 — Apply to the test set
%% ------------------------------------------------------------------------

pred = model.apply(Xt, yt);

y_c    = asvector(yc);
y_t    = asvector(yt);
yhat_c = asvector(model.prediction);
yhat_t = asvector(pred.prediction);

[rmseC, r2C, biasC] = regression_metrics(y_c, yhat_c);
[rmseP, r2P, biasP] = regression_metrics(y_t, yhat_t);
ss_tot = sum((y_c - mean(y_c)).^2);
r2CV   = 1 - (rmsecv(optPC)^2 * numel(y_c)) / ss_tot;


%% ------------------------------------------------------------------------
%  Step 6 — Plots
%% ------------------------------------------------------------------------

figure('Name', 'PCR — diagnostics');

subplot(2, 2, 1);
plot(1:maxPC, rmsecv, '-o', 'MarkerFaceColor','auto'); hold on;
plot(1:maxPC, rmsec,  '-s', 'MarkerFaceColor','auto');
xline(optPC, '--k', sprintf('Chosen #PC = %d', optPC));
xlabel('# Principal components'); ylabel('RMSE');
legend({'RMSECV','RMSEC'}, 'Location','best');
title('Component selection'); grid on; hold off;

subplot(2, 2, 2);
plot(model.reg, '-'); xlabel('Variable index'); ylabel('Regression coefficient');
title(sprintf('Regression vector @ #PC=%d', optPC)); grid on;

subplot(2, 2, 3);
res = y_c - yhat_c;
plot(yhat_c, res, 'o', 'MarkerFaceColor', [.2 .4 .8], 'MarkerEdgeColor','none');
yline(0, 'k--'); xlabel('Predicted y (cal)'); ylabel('Residual');
title('Residuals vs. predicted'); grid on;

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
fprintf('  Model             : PCR\n');
fprintf('  Preprocessing (X) : autoscale\n');
fprintf('  Preprocessing (Y) : mean center\n');
fprintf('  CV scheme         : venetian blinds, 10 splits\n');
fprintf('  Optimal #PCs      : %d (chosen by min RMSECV)\n', optPC);
fprintf('  Calibration RMSEC : %.4f   R^2 = %.4f   bias = %+.4f\n', rmseC, r2C, biasC);
fprintf('  Cross-val   RMSECV: %.4f   R^2 = %.4f\n', rmsecv(optPC), r2CV);
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
