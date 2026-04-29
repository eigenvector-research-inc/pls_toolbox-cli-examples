%==========================================================================
%  REGRESSION COMPARISON — Five regressors on a single shared dataset
%
%  Dataset    : `plsdata` (toolbox/dems/plsdata.mat). One calibration and
%               one independent test block, used identically by every
%               regressor in this script. The collinear, near-linear
%               nature of plsdata is the kind of setting where regularized
%               and latent-variable methods tend to dominate, and where a
%               nonlinear method like SVMR is unlikely to gain ground.
%
%  Models     : Ridge (1-SE lambda), Elastic Net (built-in optimizer),
%               PCR (CV ncomp), PLS (CV LV), SVMR (CV cost / gamma / eps).
%
%  You will learn
%  --------------
%  1. How to make an apples-to-apples regression comparison with one
%     calibration set, one test set, and the same evaluation metrics.
%  2. How to package each model as a self-contained block that can be
%     commented out without breaking the rest.
%  3. What this particular dataset reveals about when each method wins.
%
%  Adding or removing a model
%  --------------------------
%  Each block below is a stand-alone unit that produces one entry in the
%  results struct array via the local addResult() helper. To remove a
%  model, comment out its entire %% Block X — ... section. To add a model,
%  copy any block, change the algorithm setup, and let addResult() do the
%  bookkeeping.
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
%  Step 1 — Shared cal/test data, preprocessing, and CV scheme
%% ------------------------------------------------------------------------

% >>> USER: replace with your own DSOs.
load plsdata
Xc = xblock1;  yc = yblock1;
Xt = xblock2;  yt = yblock2;
Nc = size(Xc, 1);
fprintf('Calibration: %dx%d, test: %dx%d\n', Nc, size(Xc,2), size(Xt,1), size(Xt,2));

% Shared preprocessing — all blocks use these unless they say otherwise
% in a comment. (SVMR uses the same X preprocessing; it does not take a
% Y-block preprocessing because the SVR loss is computed on raw y.)
ppX = preprocess('default', 'autoscale');
ppY = preprocess('default', 'mean center');

% Shared CV scheme for all blocks
kFolds = 5;
cviCell = {'vet', kFolds};

% Initialize results container
results = struct('name', {}, 'rmsec', {}, 'rmsep', {}, 'r2c', {}, 'r2p', {}, ...
                 'biasp', {}, 'yhat_c', {}, 'yhat_t', {}, 'hp', {});

% Plain vectors for downstream metrics
y_c = asvector(yc);
y_t = asvector(yt);


%% ========================================================================
%  Block A — PLS regression
%% ========================================================================
modelPLS = evrimodel('pls');
modelPLS.x = Xc;  modelPLS.y = yc;
modelPLS.ncomp = 12;
modelPLS.display = 'off';  modelPLS.plots = 'none';
oP = modelPLS.options;
oP.preprocessing{1} = ppX;
oP.preprocessing{2} = ppY;
modelPLS.options = oP;
modelPLS = modelPLS.crossvalidate(cviCell, 12);
[~, optLV] = min(modelPLS.detail.rmsecv(:));
% Fresh model at chosen LV (ncomp is read-only after calibration).
modelPLS = evrimodel('pls');
modelPLS.x = Xc;  modelPLS.y = yc;
modelPLS.ncomp = optLV;
modelPLS.display = 'off';  modelPLS.plots = 'none';
oP = modelPLS.options;
oP.preprocessing{1} = ppX;  oP.preprocessing{2} = ppY;
modelPLS.options = oP;
modelPLS = modelPLS.crossvalidate(cviCell, optLV);
predPLS = modelPLS.apply(Xt, yt);
results = addResult(results, 'PLS', y_c, asvector(modelPLS.prediction), ...
                    y_t, asvector(predPLS.prediction), sprintf('LV=%d', optLV));


%% ========================================================================
%  Block B — PCR regression
%% ========================================================================
modelPCR = evrimodel('pcr');
modelPCR.x = Xc;  modelPCR.y = yc;
modelPCR.ncomp = 12;
modelPCR.display = 'off';  modelPCR.plots = 'none';
oP = modelPCR.options;
oP.preprocessing{1} = ppX;
oP.preprocessing{2} = ppY;
modelPCR.options = oP;
modelPCR = modelPCR.crossvalidate(cviCell, 12);
[~, optPC] = min(modelPCR.detail.rmsecv(:));
% Fresh model at chosen #PCs.
modelPCR = evrimodel('pcr');
modelPCR.x = Xc;  modelPCR.y = yc;
modelPCR.ncomp = optPC;
modelPCR.display = 'off';  modelPCR.plots = 'none';
oP = modelPCR.options;
oP.preprocessing{1} = ppX;  oP.preprocessing{2} = ppY;
modelPCR.options = oP;
modelPCR = modelPCR.crossvalidate(cviCell, optPC);
predPCR = modelPCR.apply(Xt, yt);
results = addResult(results, 'PCR', y_c, asvector(modelPCR.prediction), ...
                    y_t, asvector(predPCR.prediction), sprintf('PC=%d', optPC));


%% ========================================================================
%  Block C — Ridge regression with a compressed CV grid (min-RMSECV rule)
%% ========================================================================
% Compressed version of the workflow in ridge_optimized_example.m. We
% drop the 1-SE bookkeeping here for readability — see the dedicated
% script for the full treatment.

% >>> USER: tighten or widen this grid for your data.
lambdaGrid = logspace(-3, 1, 12);
cvAssign   = mod(0:Nc-1, kFolds)' + 1;
rmseFold   = nan(kFolds, numel(lambdaGrid));
for iL = 1:numel(lambdaGrid)
    for f = 1:kFolds
        idxTr = find(cvAssign ~= f);
        idxVa = find(cvAssign == f);
        m = evrimodel('mlr');
        m.x = Xc(idxTr, :);  m.y = yc(idxTr, :);
        m.display = 'off';   m.plots = 'none';
        o = m.options;
        o.algorithm = 'ridge';  o.ridge = lambdaGrid(iL);
        o.preprocessing{1} = ppX;  o.preprocessing{2} = ppY;
        m.options = o;
        m = m.calibrate;
        p = m.apply(Xc(idxVa, :), yc(idxVa, :));
        rmseFold(f, iL) = sqrt(mean((asvector(yc(idxVa,:)) - asvector(p.prediction)).^2));
    end
end
[~, iMin] = min(mean(rmseFold, 1));
lambdaChosen = lambdaGrid(iMin);

modelRidge = evrimodel('mlr');
modelRidge.x = Xc;  modelRidge.y = yc;
modelRidge.display = 'off';  modelRidge.plots = 'none';
oR = modelRidge.options;
oR.algorithm = 'ridge';  oR.ridge = lambdaChosen;
oR.preprocessing{1} = ppX;  oR.preprocessing{2} = ppY;
modelRidge.options = oR;
modelRidge = modelRidge.calibrate;
predRidge  = modelRidge.apply(Xt, yt);
results = addResult(results, 'Ridge', y_c, asvector(modelRidge.prediction), ...
                    y_t, asvector(predRidge.prediction), sprintf('lambda=%.3g', lambdaChosen));


%% ========================================================================
%  Block D — Elastic Net via the PLS_Toolbox built-in optimizer
%% ========================================================================
% Compact form: pass vector grids and let MLR run the internal CV grid.
% See elasticnet_optimized_example.m for the explicit hand-coded loop.

modelEN = evrimodel('mlr');
modelEN.x = Xc;  modelEN.y = yc;
modelEN.display = 'off';  modelEN.plots = 'none';
oE = modelEN.options;
oE.algorithm        = 'elasticnet';
oE.optimized_ridge  = logspace(-3, 0, 6);
oE.optimized_lasso  = logspace(-3, 0, 6);
oE.solver           = 'coordinatedescent';
oE.silent           = true;
oE.cvi              = cviCell;
oE.preprocessing{1} = ppX;
oE.preprocessing{2} = ppY;
modelEN.options = oE;
modelEN = modelEN.calibrate;
predEN  = modelEN.apply(Xt, yt);
chosenL2 = getoptfield(modelEN, 'detail.mlr.best_params.optimized_ridge', NaN);
chosenL1 = getoptfield(modelEN, 'detail.mlr.best_params.optimized_lasso', NaN);
hpStr = sprintf('L2=%.3g, L1=%.3g', chosenL2, chosenL1);
results = addResult(results, 'ElasticNet', y_c, asvector(modelEN.prediction), ...
                    y_t, asvector(predEN.prediction), hpStr);


%% ========================================================================
%  Block E — SVM regression (RBF kernel, built-in CV grid)
%% ========================================================================
% Note: SVMR uses autoscale on X (same as everyone else) but does not
% receive a Y preprocessing — the epsilon-insensitive loss operates on
% raw y values.

modelSVM = evrimodel('svm');
modelSVM.x = Xc;  modelSVM.y = yc;
modelSVM.display = 'off';  modelSVM.plots = 'none';
oS = modelSVM.options;
oS.svmtype          = 'epsilon-svr';
oS.kerneltype       = 'rbf';
oS.cost             = [0.1 1 10 100];
oS.gamma            = [1e-4 1e-3 1e-2 1e-1];
oS.epsilon          = [0.01 0.1];
oS.cvi              = cviCell;
oS.cvtimelimit      = 60;
oS.preprocessing{1} = ppX;
modelSVM.options = oS;
modelSVM = modelSVM.calibrate;
predSVM  = modelSVM.apply(Xt, yt);
chosenC  = getoptfield(modelSVM, 'detail.svm.model.param.C',     NaN);
chosenG  = getoptfield(modelSVM, 'detail.svm.model.param.gamma', NaN);
chosenE  = getoptfield(modelSVM, 'detail.svm.model.param.p',     NaN);
hpStr = sprintf('C=%.3g, gamma=%.3g, eps=%.3g', chosenC, chosenG, chosenE);
results = addResult(results, 'SVMR', y_c, asvector(modelSVM.prediction), ...
                    y_t, asvector(predSVM.prediction), hpStr);


%% ------------------------------------------------------------------------
%  Step 2 — Print a comparison table
%% ------------------------------------------------------------------------

fprintf('\n========================================================\n');
fprintf('  REGRESSION COMPARISON — %d models on plsdata\n', numel(results));
fprintf('========================================================\n');
fprintf('  %-12s  %8s  %8s  %8s  %8s  %s\n', 'Model', 'RMSEC', 'RMSEP', 'R2_cal', 'R2_test', 'Hyperparams');
fprintf('  %-12s  %8s  %8s  %8s  %8s  %s\n', repmat('-',1,12), '------', '------', '------', '------', repmat('-',1,15));
for i = 1:numel(results)
    r = results(i);
    fprintf('  %-12s  %8.4f  %8.4f  %8.4f  %8.4f  %s\n', ...
            r.name, r.rmsec, r.rmsep, r.r2c, r.r2p, r.hp);
end
fprintf('========================================================\n\n');


%% ------------------------------------------------------------------------
%  Step 3 — Bar chart of RMSEP across models
%% ------------------------------------------------------------------------

figure('Name', 'Regression comparison — RMSEP');
names = {results.name};
rmseps = [results.rmsep];
bar(rmseps); set(gca, 'XTickLabel', names);
ylabel('RMSEP (test set)'); title('Regression comparison — RMSEP'); grid on;


%% ------------------------------------------------------------------------
%  Step 4 — Small-multiples panel: measured vs predicted
%% ------------------------------------------------------------------------

figure('Name', 'Regression comparison — measured vs predicted');
nM = numel(results);
nCol = ceil(sqrt(nM));
nRow = ceil(nM / nCol);

yLo = min([y_c; y_t]);
yHi = max([y_c; y_t]);
for i = 1:nM
    subplot(nRow, nCol, i);
    plot(y_c, results(i).yhat_c, 'o', 'MarkerFaceColor', [.2 .4 .8], 'MarkerEdgeColor','none'); hold on;
    plot(y_t, results(i).yhat_t, 's', 'MarkerFaceColor', [.8 .3 .2], 'MarkerEdgeColor','none');
    plot([yLo yHi], [yLo yHi], 'k--');
    xlim([yLo yHi]); ylim([yLo yHi]);
    xlabel('Measured y'); ylabel('Predicted y');
    title(sprintf('%s (RMSEP=%.3f)', results(i).name, results(i).rmsep));
    grid on; hold off;
end


%% ------------------------------------------------------------------------
%  Interpretation
%% ------------------------------------------------------------------------
% The plsdata X-block is highly collinear and the relationship to y is
% close to linear. In that regime:
%
%  - PLS and Ridge typically tie at the top: both control coefficient
%    variance in the presence of collinearity, by different mechanisms
%    (latent variables vs L2 shrinkage). Their test errors are usually
%    within noise of each other on this data.
%  - Elastic Net usually lands close to PLS / Ridge but with a sparser
%    regression vector — useful if interpretability or feature selection
%    matters more than a fraction of an RMSE point.
%  - PCR is often slightly worse than PLS because PCR's components
%    maximize variance of X regardless of relevance to y; on this data
%    PCR can need a few more components to reach the same RMSE.
%  - SVMR with an RBF kernel will not beat the linear methods here. The
%    nonlinearity it can express has nothing to do — RBF excels when the
%    true relationship between X and y bends, which is not the case.


%% ------------------------------------------------------------------------
%  Local helpers
%% ------------------------------------------------------------------------

function v = asvector(x)
    if isa(x, 'dataset'); x = x.data; end
    x = double(x);
    if size(x, 2) > 1; x = x(:, 1); end
    v = x(:);
end

function results = addResult(results, name, y_c, yhat_c, y_t, yhat_t, hp)
    e_c = y_c - yhat_c;  e_t = y_t - yhat_t;
    rmsec = sqrt(mean(e_c.^2));  rmsep = sqrt(mean(e_t.^2));
    r2c   = 1 - sum(e_c.^2) / sum((y_c - mean(y_c)).^2);
    r2p   = 1 - sum(e_t.^2) / sum((y_t - mean(y_t)).^2);
    biasp = mean(e_t);
    results(end+1) = struct('name', name, 'rmsec', rmsec, 'rmsep', rmsep, ...
                            'r2c', r2c, 'r2p', r2p, 'biasp', biasp, ...
                            'yhat_c', yhat_c, 'yhat_t', yhat_t, 'hp', hp);
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
