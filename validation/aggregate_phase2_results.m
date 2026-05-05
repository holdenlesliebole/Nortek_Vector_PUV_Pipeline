function aggregate_phase2_results(opts)
% AGGREGATE_PHASE2_RESULTS  Build cross-deployment figures from the
% phase2_summary.mat written by run_phase2_all_deployments.
%
%   aggregate_phase2_results()
%
% Figures saved to outputs/validation/mean_flow/_aggregate/
% Author: Holden Leslie-Bole, 2026

if nargin < 1, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
% Accept opts.aggDir to redirect output (e.g. for mean_flow_hourly comparison)
if isfield(opts,'aggDir')
    aggDir = opts.aggDir;
else
    aggDir = fullfile(pipelineRoot,'outputs','validation','mean_flow','_aggregate');
end

S = load(fullfile(aggDir,'phase2_summary.mat')); s = S.summary;

% Force all numeric arrays to column vectors for consistent indexing
nums = {'h_med','alpha','alpha_lo','alpha_hi','beta','beta_lo','beta_hi', ...
        'R2_Hs2','alpha_th','modAmp_low','modAmp_mid','modAmp_high','R_uMean_uw','N_segs'};
for k = 1:numel(nums)
    s.(nums{k}) = s.(nums{k})(:);
end
s.label      = s.label(:);
s.deployment = s.deployment(:);

% Optionally merge in range settings if available
rangeFile = fullfile(aggDir,'vector_range_settings.mat');
if isfile(rangeFile)
    R = load(rangeFile); rangeT = R.T;
    % Build a lookup
    rangeMap = containers.Map();
    for k = 1:height(rangeT)
        key = sprintf('%s/%s', rangeT.deployment{k}, rangeT.label{k});
        rangeMap(key) = rangeT.range_mps(k);
    end
    range_mps = nan(numel(s.label),1);
    for k = 1:numel(s.label)
        key = sprintf('%s/%s', s.deployment{k}, s.label{k});
        if rangeMap.isKey(key), range_mps(k) = rangeMap(key); end
    end
    s.range_mps = range_mps;
else
    s.range_mps = nan(numel(s.label),1);
end

% Tag site categories for color coding
site = strings(numel(s.label),1);
for k = 1:numel(s.label)
    d = s.deployment{k};
    if startsWith(d,'TBR') || startsWith(d,'TOR'), site(k) = "Torrey";
    elseif startsWith(d,'SOL'),                    site(k) = "Solana";
    elseif startsWith(d,'SIO'),                    site(k) = "SIO Pier";
    elseif startsWith(d,'LPL'),                    site(k) = "LPL lagoon";
    else,                                          site(k) = "other";
    end
end
s.site = site;

% Flag known-bad instruments
isBad = false(numel(s.label),1);
for k = 1:numel(s.label)
    isBad(k) = strcmp(s.deployment{k},'TBR23') && strcmp(s.label{k},'MOP580_5m');
end
s.isBad = isBad;

% Composition: how many instruments per site?
fprintf('\nInstrument inventory:\n');
sites = unique(site);
for k = 1:numel(sites)
    fprintf('  %-12s  N=%d\n', sites(k), sum(site==sites(k)));
end

% Color map per site
siteColors = containers.Map();
siteColors('Torrey')     = [0.20 0.45 0.85];
siteColors('Solana')     = [0.85 0.30 0.20];
siteColors('SIO Pier')   = [0.95 0.65 0.10];
siteColors('LPL lagoon') = [0.30 0.65 0.30];
siteColors('other')      = [0.50 0.50 0.50];

% ============================== FIGURE 1: alpha vs depth =====================
fig1 = figure('Visible','off','Position',[100 100 1100 700]);
hold on;
% Theory curve
hPlot = linspace(2, 12, 200);
g = 9.81;
alpha_th = -g ./ (16 * sqrt(g*hPlot) .* hPlot);
plot(hPlot, alpha_th, 'k-', 'LineWidth', 1.4, 'DisplayName', 'Stokes return-flow theory');

% Suppress error bars on points whose CI exceeds the visible window (one
% SIO Pier shallowest point has a CI that's wider than the data spread —
% it would render as a giant vertical line and dominate the figure).
yClip = 0.05;
ciHalf = max(s.alpha_hi - s.alpha, s.alpha - s.alpha_lo);
errBarOK = ciHalf <= yClip;
for st = sites'
    pickEB = s.site == st & ~s.isBad & errBarOK;
    if any(pickEB)
        a   = s.alpha(pickEB);
        errorbar(s.h_med(pickEB), a, a - s.alpha_lo(pickEB), s.alpha_hi(pickEB) - a, ...
            'o', 'Color', siteColors(char(st)), 'MarkerFaceColor', siteColors(char(st)), ...
            'MarkerSize', 7, 'CapSize', 0, 'DisplayName', char(st));
    end
    pickNoEB = s.site == st & ~s.isBad & ~errBarOK;
    if any(pickNoEB)
        scatter(s.h_med(pickNoEB), s.alpha(pickNoEB), 60, ...
            'MarkerFaceColor', siteColors(char(st)), 'MarkerEdgeColor', 'k', ...
            'Marker', 'd', 'HandleVisibility', 'off');
    end
end
% Bad markers
if any(s.isBad)
    plot(s.h_med(s.isBad), s.alpha(s.isBad), 'rx', 'MarkerSize', 14, 'LineWidth', 2, ...
        'DisplayName', 'flagged compromised');
end

yline(0, 'k:', 'HandleVisibility', 'off');
xlabel('h_{med} (m)');
ylabel('\alpha (m/s per m^2 of H_s^2)');
title('Phase 2 cross-deployment: H_s^2-scaling slope \alpha vs depth', ...
       'FontSize', 11);
legend('Location','northeast', 'FontSize', 9);
ylim([-yClip yClip]);
grid on;
exportgraphics(fig1, fullfile(aggDir, 'phase2_alpha_vs_depth.png'), 'Resolution', 200);
close(fig1);

% ============================== FIGURE 2: beta histogram =====================
fig2 = figure('Visible','off','Position',[100 100 1000 600]);
goodBeta = ~isnan(s.beta) & ~s.isBad;
histogram(s.beta(goodBeta), 25, 'FaceColor', [0.4 0.6 0.85]);
xline(0, 'k--', 'LineWidth', 1.2);
xline(0.02, 'r:', 'LineWidth', 1.2, 'Label', '+2 cm/s', 'LabelOrientation','horizontal');
xline(-0.02, 'r:', 'LineWidth', 1.2, 'Label', '-2 cm/s', 'LabelOrientation','horizontal');
xlabel('\beta = intercept of uMean = \alpha H_s^2 + \beta  (m/s)');
ylabel('# instruments');
title('Phase 2: intercept \beta distribution across all instruments', 'FontSize', 11);
text(0.02, 0.95, sprintf('N=%d   median=%+.4f m/s   p(|β|<2cm/s)=%.0f%%', ...
    sum(goodBeta), median(s.beta(goodBeta)), 100*mean(abs(s.beta(goodBeta))<0.02)), ...
    'Units','normalized','VerticalAlignment','top','BackgroundColor','w','EdgeColor','k', ...
    'Margin', 4);
grid on;
exportgraphics(fig2, fullfile(aggDir, 'phase2_beta_histogram.png'), 'Resolution', 200);
close(fig2);

% ============================== FIGURE 3: alpha / alpha_theory ratio =========
fig3 = figure('Visible','off','Position',[100 100 1000 600]);
ratio = s.alpha ./ s.alpha_th;
goodR = isfinite(ratio) & ~s.isBad;
histogram(ratio(goodR), -3:0.25:4, 'FaceColor', [0.55 0.4 0.75]);
xline(1, 'g--', 'LineWidth', 1.4, 'Label', 'theory match', 'LabelOrientation','horizontal');
xline(0, 'k--', 'LineWidth', 1.2, 'Label', 'no scaling', 'LabelOrientation','horizontal');
xlabel('\alpha / \alpha_{theory}    (negative ratio = sign mismatch)');
ylabel('# instruments');
title('Phase 2: empirical / theoretical slope ratio  \alpha / \alpha_{theory}', 'FontSize', 11);
text(0.02, 0.95, sprintf('N=%d   median=%.2f   p(ratio>0)=%.0f%%', ...
    sum(goodR), median(ratio(goodR),'omitnan'), 100*mean(ratio(goodR)>0,'omitnan')), ...
    'Units','normalized','VerticalAlignment','top','BackgroundColor','w','EdgeColor','k','Margin',4);
grid on;
exportgraphics(fig3, fullfile(aggDir, 'phase2_alpha_ratio_histogram.png'), 'Resolution', 200);
close(fig3);

% ============================== FIGURE 4: high-Hs modulation amplitude =======
fig4 = figure('Visible','off','Position',[100 100 1100 700]);
hold on;
for st = sites'
    pick = s.site == st & ~s.isBad & isfinite(s.modAmp_high);
    if any(pick)
        scatter(s.h_med(pick), s.modAmp_high(pick), 60, ...
            'MarkerFaceColor', siteColors(char(st)), 'MarkerEdgeColor', 'k', ...
            'DisplayName', char(st));
    end
end
if any(s.isBad & isfinite(s.modAmp_high))
    scatter(s.h_med(s.isBad), s.modAmp_high(s.isBad), 100, 'rx', 'LineWidth', 2, ...
        'DisplayName', 'flagged compromised');
end
yline(0.02, 'k--', 'Label', '2 cm/s instrument-noise floor', 'LabelOrientation','horizontal', 'HandleVisibility', 'off');
xlabel('h_{med} (m)'); ylabel('Tidal modulation amplitude at H_s ≥ 1 m  (m/s)');
title('Phase 2: tidal modulation amplitude at H_s \geq 1 m vs depth', ...
       'FontSize', 11);
legend('Location','northeast', 'FontSize', 9);
grid on;
exportgraphics(fig4, fullfile(aggDir, 'phase2_modulation_vs_depth.png'), 'Resolution', 200);
close(fig4);

% ============================== FIGURE 5: range setting check ================
if any(~isnan(s.range_mps))
    fig5 = figure('Visible','off','Position',[100 100 1000 600]);
    scatter(s.range_mps(~s.isBad), s.beta(~s.isBad), 70, ...
        s.h_med(~s.isBad), 'filled', 'MarkerEdgeColor', 'k');
    colormap(parula); cbar = colorbar; cbar.Label.String = 'h_{med} (m)';
    yline(0, 'k--');
    yline(0.02, 'r:', 'Label','+2 cm/s'); yline(-0.02, 'r:', 'Label','-2 cm/s');
    xlabel('Vector nominal velocity range (m/s)');
    ylabel('\beta = intercept (m/s)');
    title('Phase 2: intercept \beta vs Vector range setting', 'FontSize', 11);
    grid on;
    exportgraphics(fig5, fullfile(aggDir, 'phase2_beta_vs_range.png'), 'Resolution', 200);
    close(fig5);
end

% ============================== Summary table ================================
fprintf('\nCross-deployment summary (excluding flagged):\n');
ok = ~s.isBad & ~isnan(s.alpha);
fprintf('  N instruments       = %d\n', sum(ok));
fprintf('  median alpha        = %+.4f m/s/m^2\n', median(s.alpha(ok)));
fprintf('  median alpha/theory = %+.2f\n', median(s.alpha(ok)./s.alpha_th(ok)));
fprintf('  alpha < 0 fraction  = %.0f%% (correct sign for offshore undertow)\n', 100*mean(s.alpha(ok)<0));
fprintf('  median beta         = %+.4f m/s\n', median(s.beta(ok),'omitnan'));
fprintf('  |beta| < 2 cm/s     = %.0f%%\n', 100*mean(abs(s.beta(ok))<0.02,'omitnan'));
fprintf('  median modAmp(high Hs) = %.4f m/s\n', median(s.modAmp_high(ok),'omitnan'));
fprintf('\nFigures: %s\n', aggDir);
end
