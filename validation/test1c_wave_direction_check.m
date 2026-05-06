function results = test1c_wave_direction_check(opts)
% TEST1C_WAVE_DIRECTION_CHECK  Decisive test for whether the alongshore
% α we observe is real radiation-stress-driven longshore current or a
% coordinate-rotation artifact.
%
% Model
%   v̄ = α_v0 · H_s²  +  α_v1 · sin(2θ_rel) · H_s²  +  β_v
%
% θ_rel is wave incidence relative to shore normal. Because L2.meanDir
% is already in the shore-normal-rotated frame (atan2d(Spv,Spu) on
% rotated PUV cross-spectra), meanDir IS θ_rel directly — 0° means
% waves from directly offshore, ±90° means waves arriving along-coast.
%
% Predictions
%   - Real radiation-stress longshore current:
%         α_v1 dominant, |α_v1| ≫ |α_v0|.
%   - Coordinate-rotation error θ_err on the shore-normal:
%         α_v0 = α_u · tan(θ_err), α_v1 ≈ 0.
%         The implied θ_err can be backed out as atan(α_v0 / α_u).
%
% Restricts fits to segments with H_s ≥ HsMin and |meanDir| ≤ 60°
% (sensibly-incident waves). Also reports same fit on cross-shore u
% as a sanity check that wave-direction-correlated residuals don't
% contaminate the cross-shore α.
% Author: Holden Leslie-Bole, 2026

if nargin < 1, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts,'L2dir_17'), opts.L2dir_17 = fullfile(pipelineRoot,'outputs','L2_17min'); end
if ~isfield(opts,'L2dir_60'), opts.L2dir_60 = fullfile(pipelineRoot,'outputs','L2'); end
if ~isfield(opts,'aggDir'),   opts.aggDir   = fullfile(pipelineRoot,'outputs','validation','mean_flow','_aggregate'); end
if ~isfield(opts,'HsMin'),    opts.HsMin    = 0.2; end
if ~isfield(opts,'dirMaxDeg'), opts.dirMaxDeg = 60; end
if ~exist(opts.aggDir,'dir'), mkdir(opts.aggDir); end

reg = deployment_registry();
deployments = sort(keys(reg));

results = struct('deployment',{},'label',{},'h_med',{}, ...
    'alpha_u',{},'beta_u',{},'R2_u',{}, ...
    'alpha_v0',{},'alpha_v1',{},'beta_v',{},'R2_v',{}, ...
    'alpha_v0_CI',{},'alpha_v1_CI',{}, ...
    'theta_err_deg',{},'meanDir_med',{},'meanDir_iqr',{},'N',{});

for iD = 1:numel(deployments)
    dep = deployments{iD};
    depDir = fullfile(opts.L2dir_60, dep);
    if ~isfolder(depDir), continue; end
    files = dir(fullfile(depDir,'*_L2.mat'));
    files = files(~contains({files.name},'.bak'));
    for iF = 1:numel(files)
        label = regexprep(files(iF).name,'_L2\.mat$','');
        L60 = load(fullfile(depDir, [label '_L2.mat']));  L60 = L60.L2;
        if ~isfield(L60,'vMean') || ~isfield(L60,'meanDir') || ~isfield(L60,'Hs'), continue; end
        valid = L60.segValid(:) & ~isnan(L60.uMean(:)) & ~isnan(L60.vMean(:)) ...
              & ~isnan(L60.Hs(:)) & ~isnan(L60.meanDir(:)) ...
              & L60.Hs(:) >= opts.HsMin ...
              & abs(L60.meanDir(:)) <= opts.dirMaxDeg;
        if sum(valid) < 100, continue; end

        Hs   = L60.Hs(valid);
        u    = L60.uMean(valid);
        v    = L60.vMean(valid);
        thR  = L60.meanDir(valid);  % deg, already shore-normal-relative
        h_med = median(L60.depth(valid));

        % --- Cross-shore u fit
        Xu = [Hs.^2, ones(size(Hs))];
        [b_u, bint_u] = regress(u, Xu);
        yhat_u = Xu * b_u;
        R2_u = 1 - sum((u - yhat_u).^2) / sum((u - mean(u)).^2);

        % --- Alongshore v fit with wave-direction term
        sin2t = sind(2 * thR);
        Xv = [Hs.^2, sin2t .* Hs.^2, ones(size(Hs))];
        [b_v, bint_v] = regress(v, Xv);
        yhat_v = Xv * b_v;
        R2_v = 1 - sum((v - yhat_v).^2) / sum((v - mean(v)).^2);

        % Implied θ_err if the bias-only hypothesis were true
        if abs(b_u(1)) > 1e-6
            theta_err = atand(b_v(1) / b_u(1));
        else
            theta_err = NaN;
        end

        results(end+1) = struct( ...
            'deployment', dep, 'label', label, 'h_med', h_med, ...
            'alpha_u', b_u(1), 'beta_u', b_u(2), 'R2_u', R2_u, ...
            'alpha_v0', b_v(1), 'alpha_v1', b_v(2), 'beta_v', b_v(3), 'R2_v', R2_v, ...
            'alpha_v0_CI', bint_v(1,:), 'alpha_v1_CI', bint_v(2,:), ...
            'theta_err_deg', theta_err, ...
            'meanDir_med', median(thR), 'meanDir_iqr', iqr(thR), ...
            'N', sum(valid)); %#ok<AGROW>

        fprintf('  %-12s %-14s  α_u=%+.4f  α_v0=%+.4f  α_v1=%+.4f  R²_v=%.3f  θ_err≈%+.1f°  N=%d  meanDir(med)=%+5.1f°\n', ...
            dep, label, b_u(1), b_v(1), b_v(2), R2_v, theta_err, sum(valid), median(thR));
    end
end

save(fullfile(opts.aggDir,'wave_direction_check.mat'),'results');

% =========== Aggregate stats ===========
au   = [results.alpha_u]';
av0  = [results.alpha_v0]';
av1  = [results.alpha_v1]';
te   = [results.theta_err_deg]';

fprintf('\n======================================================================\n');
fprintf(' Wave-direction test  (1-hour L2,  v = α_v0·H_s² + α_v1·sin(2θ)·H_s² + β)\n');
fprintf('======================================================================\n');
fprintf('N instruments fit                  : %d\n', numel(au));
fprintf('median α_u  (cross-shore slope)    : %+.4f m/s/m^2\n', median(au));
fprintf('median α_v0 (wave-dir-INDEPENDENT) : %+.4f m/s/m^2\n', median(av0));
fprintf('median α_v1 (sin(2θ) coefficient)  : %+.4f m/s/m^2\n', median(av1));
fprintf('|α_v1| > |α_v0| in                 : %.0f%% of instruments\n', 100*mean(abs(av1) > abs(av0)));
fprintf('α_v1 > 0 (NW-swell drives South)   : %.0f%% of instruments\n', 100*mean(av1 > 0));
fprintf('CI on α_v1 excludes 0 in           : %.0f%% of instruments\n', ...
    100*mean(arrayfun(@(r) sign(r.alpha_v1_CI(1))==sign(r.alpha_v1_CI(2)), results)));
fprintf('CI on α_v0 excludes 0 in           : %.0f%% of instruments\n', ...
    100*mean(arrayfun(@(r) sign(r.alpha_v0_CI(1))==sign(r.alpha_v0_CI(2)), results)));
fprintf('implied |θ_err| (rotation error)   : median %.1f°, 90th-pctl %.1f°\n', ...
    median(abs(te(~isnan(te)))), prctile(abs(te(~isnan(te))), 90));

% =========== Figure ===========
fig = figure('Visible','off','Position',[100 100 1500 950]);

% Site colors
[siteName, siteCol] = get_site(results);
sites = unique(siteName);

% Panel 1: α_v0 vs α_v1
subplot(2,2,1); hold on;
lim = max(max(abs(av0), abs(av1)))*1.1;
plot([-lim lim],[0 0],'k-','LineWidth',0.5,'HandleVisibility','off');
plot([0 0],[-lim lim],'k-','LineWidth',0.5,'HandleVisibility','off');
plot([-lim lim],[-lim lim], 'k:', 'LineWidth', 1.0, 'HandleVisibility','off');
for st = sites'
    pick = (siteName == st);
    if any(pick)
        scatter(av0(pick), av1(pick), 70, siteCol(pick,:), 'filled', ...
            'MarkerEdgeColor','k', 'DisplayName', char(st));
    end
end
xlabel('\alpha_{v0}  (wave-direction-INDEPENDENT, m/s/m^2)');
ylabel('\alpha_{v1}  (sin(2\theta) coefficient,  m/s/m^2)');
title(sprintf('|\\alpha_{v1}| > |\\alpha_{v0}| in %.0f%%   (rotation-error hyp predicts vertical band at \\alpha_{v1}=0)', ...
    100*mean(abs(av1) > abs(av0))));
xlim([-lim lim]); ylim([-lim lim]); grid on; axis square;
legend('Location','best','FontSize',8);

% Panel 2: α_u vs α_v0 (rotation-error fingerprint)
subplot(2,2,2); hold on;
lim = max(max(abs(au), abs(av0)))*1.1;
plot([-lim lim],[0 0],'k-','LineWidth',0.5,'HandleVisibility','off');
plot([0 0],[-lim lim],'k-','LineWidth',0.5,'HandleVisibility','off');
% Constant-rotation lines for θ_err = ±5°, ±15°
for theta = [5, 15]
    plot([-lim lim], tand(theta)*[-lim lim], 'r:', 'LineWidth', 0.8, 'HandleVisibility','off');
    plot([-lim lim], -tand(theta)*[-lim lim], 'r:', 'LineWidth', 0.8, 'HandleVisibility','off');
end
text(lim*0.9, tand(15)*lim*0.9, '\theta_{err}=+15°', 'Color','r','FontSize',8,'HorizontalAlignment','right');
text(lim*0.9, tand(5)*lim*0.9, '\theta_{err}=+5°', 'Color','r','FontSize',8,'HorizontalAlignment','right');
for st = sites'
    pick = (siteName == st);
    if any(pick)
        scatter(au(pick), av0(pick), 70, siteCol(pick,:), 'filled', 'MarkerEdgeColor','k', 'HandleVisibility','off');
    end
end
xlabel('\alpha_u  (cross-shore slope,  m/s/m^2)');
ylabel('\alpha_{v0}  (alongshore wave-dir-INDEPT slope,  m/s/m^2)');
title(sprintf('Rotation-error fingerprint: \\alpha_{v0} vs \\alpha_u   (median |\\theta_{err}| = %.1f°)', median(abs(te(~isnan(te))))));
xlim([-lim lim]); ylim([-lim lim]); grid on; axis square;

% Panel 3: implied theta_err histogram
subplot(2,2,3);
histogram(te(~isnan(te)), 'BinWidth', 5, 'FaceColor', [0.55 0.4 0.75], 'EdgeColor','k');
xline(0, 'k--', 'LineWidth', 1.2);
for theta = [-15 -5 5 15]
    xline(theta, 'r:', 'LineWidth', 0.8, 'HandleVisibility','off');
end
xlabel('implied \theta_{err}  =  atan(\alpha_{v0} / \alpha_u)   (°)');
ylabel('# instruments');
title(sprintf('Implied rotation error per instrument  (median |\\theta_{err}|=%.1f°, 90th pctl=%.1f°)', ...
    median(abs(te(~isnan(te)))), prctile(abs(te(~isnan(te))),90)));
grid on;
xlim([-90 90]);

% Panel 4: α_v1 with theory line
subplot(2,2,4); hold on;
hPlot = linspace(2,16,200);
g = 9.81;
% Order-of-magnitude expected α_v1 from radiation-stress longshore current.
% Scaling: V ~ -K · H_s² · sin(2θ) / h.  Use K = g/(16·c) = α_u-equivalent.
av1_th = -g ./ (16 * sqrt(g*hPlot) .* hPlot);
plot(hPlot, av1_th, 'k-', 'LineWidth', 1.3, 'DisplayName','order-of-magnitude (Stokes-equivalent)');
yline(0,'k:','HandleVisibility','off');
hVec = [results.h_med]';
for st = sites'
    pick = (siteName == st);
    if any(pick)
        scatter(hVec(pick), av1(pick), 70, siteCol(pick,:), 'filled', ...
            'MarkerEdgeColor','k', 'DisplayName', char(st));
    end
end
xlabel('h_{med}  (m)');
ylabel('\alpha_{v1}  (m/s/m^2)');
title('Wave-direction coefficient \alpha_{v1} vs depth');
ylim([-0.05 0.05]);
grid on;
legend('Location','best','FontSize',8);

outFig = fullfile(opts.aggDir, 'wave_direction_check.png');
exportgraphics(fig, outFig, 'Resolution', 200);
close(fig);
fprintf('\nFigure: %s\n', outFig);
end


function [siteName, siteCol] = get_site(results)
n = numel(results);
siteName = strings(n,1);
siteCol = zeros(n,3);
colors = struct('Torrey',[0.20 0.45 0.85], 'Solana',[0.85 0.30 0.20], ...
                'SIO_Pier',[0.95 0.65 0.10], 'LPL_lagoon',[0.30 0.65 0.30], ...
                'other',[0.5 0.5 0.5]);
for k = 1:n
    d = results(k).deployment;
    if startsWith(d,'TBR')||startsWith(d,'TOR'), siteName(k) = "Torrey";       siteCol(k,:) = colors.Torrey;
    elseif startsWith(d,'SOL'),                  siteName(k) = "Solana";       siteCol(k,:) = colors.Solana;
    elseif startsWith(d,'SIO'),                  siteName(k) = "SIO Pier";     siteCol(k,:) = colors.SIO_Pier;
    elseif startsWith(d,'LPL'),                  siteName(k) = "LPL lagoon";   siteCol(k,:) = colors.LPL_lagoon;
    else,                                        siteName(k) = "other";        siteCol(k,:) = colors.other;
    end
end
end
