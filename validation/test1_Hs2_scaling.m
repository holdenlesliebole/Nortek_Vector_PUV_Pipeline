function results = test1_Hs2_scaling(deployment, labels, opts)
% TEST1_HS2_SCALING  Test whether segment-mean cross-shore velocity scales
% with Hs² as Stokes return-flow theory predicts.
%
%   results = test1_Hs2_scaling('TBR23', {'MOP580_5m','MOP580_7m','MOP586_5m','MOP586_7m'})
%
% For each instrument:
%   1. Load L2 (default: 17-min). Extract uMean, Hs, depth.
%   2. Optional QC: drop outliers in (Hs, uMean), require both finite.
%   3. Linear fit: uMean = alpha*Hs^2 + beta.
%   4. Compare alpha to Stokes-return-flow prediction:
%        alpha_theory = -g / (16 * c * h),  c = sqrt(g*h)
%      Using shore-normal sign convention with +x onshore, undertow is
%      negative.
%   5. Report alpha, beta (with 95% CI), R^2, N. The intercept beta is the
%      key diagnostic for the instrumental-bias hypothesis: beta ≈ 0
%      means no constant offset; beta ≠ 0 quantifies any offset.
%
% INPUTS
%   deployment - 'TBR23'
%   labels     - cell array of instrument labels
%   opts.useHourly - use 1-hour L2 if available (default false)
%   opts.figDir    - default outputs/validation/mean_flow/<deployment>
%   opts.HsMin     - minimum Hs to include (default 0.2 m, drops calm-noise)
%
% OUTPUT
%   results - struct keyed by label with fit params and diagnostics
%   Figure: outputs/validation/mean_flow/<deployment>/test1_Hs2_scaling.png
% Author: Holden Leslie-Bole, 2026

if nargin < 3, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts, 'useHourly'), opts.useHourly = false; end
if opts.useHourly
    L2dirDefault = fullfile(pipelineRoot,'outputs','L2_hourly');
else
    L2dirDefault = fullfile(pipelineRoot,'outputs','L2');
end
if ~isfield(opts, 'L2dir'),  opts.L2dir  = L2dirDefault; end
if ~isfield(opts, 'figDir'), opts.figDir = fullfile(pipelineRoot,'outputs','validation','mean_flow', deployment); end
if ~isfield(opts, 'HsMin'),  opts.HsMin  = 0.2; end

if ~exist(opts.figDir, 'dir'), mkdir(opts.figDir); end
if ischar(labels) || isstring(labels), labels = cellstr(labels); end

g = 9.81;
nI = numel(labels);
results = struct();

% Figure: 2-row layout. Top: scatter+fit per instrument. Bottom: summary table panel.
fig = figure('Visible','off','Position',[100 100 1400 800]);

for iI = 1:nI
    label = labels{iI};
    L2file = fullfile(opts.L2dir, deployment, [label '_L2.mat']);
    if ~isfile(L2file)
        warning('test1:noFile','Missing %s', L2file);
        continue
    end
    S = load(L2file);
    L2 = S.L2;

    valid = L2.segValid(:) & ~isnan(L2.uMean(:)) & ~isnan(L2.Hs(:)) & ...
            L2.Hs(:) >= opts.HsMin;
    Hs    = L2.Hs(valid);
    uMean = L2.uMean(valid);
    h_seg = L2.depth(valid);

    h_med = median(h_seg);
    c_med = sqrt(g * h_med);
    alpha_theory = -g / (16 * c_med * h_med);   % m/s per m^2

    % Fit uMean = alpha * Hs^2 + beta
    X = [Hs.^2, ones(size(Hs))];
    [b, bint] = regress(uMean, X);   % bint is 95% CI
    alpha = b(1); beta = b(2);
    alpha_CI = bint(1, :);  beta_CI = bint(2, :);

    yhat = X * b;
    SSres = sum((uMean - yhat).^2);
    SStot = sum((uMean - mean(uMean)).^2);
    R2 = 1 - SSres / SStot;
    N = numel(Hs);

    % Stash
    results.(matlab.lang.makeValidName(label)) = struct( ...
        'N', N, 'h_med', h_med, ...
        'alpha', alpha, 'alpha_CI', alpha_CI, ...
        'beta',  beta,  'beta_CI',  beta_CI, ...
        'R2', R2, ...
        'alpha_theory', alpha_theory, ...
        'alpha_ratio', alpha / alpha_theory);

    % Subplot
    subplot(2, nI, iI);
    scatter(Hs.^2, uMean, 6, 'filled', 'MarkerFaceAlpha', 0.20); hold on;
    xPlot = linspace(0, max(Hs)^2, 50);
    plot(xPlot, alpha*xPlot + beta, 'r-', 'LineWidth', 1.6);
    plot(xPlot, alpha_theory*xPlot, 'k--', 'LineWidth', 1.2);
    yline(0, 'k:');
    xlabel('H_s^2 (m^2)'); ylabel('uMean cross-shore (m/s)');
    title({tex_label(label), sprintf('h=%.1f m   N=%d', h_med, N)});
    grid on;
    legend({'segments', sprintf('fit: %+.3f H_s^2 %+.3f', alpha, beta), ...
        sprintf('Stokes: %+.3f H_s^2', alpha_theory)}, ...
        'Location','best','FontSize',8);

    fprintf('\n--- %s (h_med=%.2f m, N=%d) ---\n', label, h_med, N);
    fprintf('  alpha (slope, m/s per m^2)    = %+.4f   95%% CI [%+.4f, %+.4f]\n', alpha, alpha_CI);
    fprintf('  beta  (intercept, m/s)        = %+.4f   95%% CI [%+.4f, %+.4f]\n', beta, beta_CI);
    fprintf('  R^2                           = %.3f\n', R2);
    fprintf('  Stokes return-flow theory α   = %+.4f\n', alpha_theory);
    fprintf('  Empirical / theory α ratio    = %+.2f\n', alpha / alpha_theory);
end

% Summary panel: compact table of point estimates (CIs are in the stdout report)
ax = subplot(2, 1, 2);
axis(ax, 'off');
fnames = fieldnames(results);
lines = {sprintf('%-13s  %-7s  %-10s  %-10s  %-7s  %-10s  %-7s', ...
    'instrument', 'h_med', 'alpha', 'beta [m/s]', 'R^2', 'alpha_th', 'a / ath')};
lines{end+1} = repmat('-', 1, 80);
for k = 1:numel(fnames)
    r = results.(fnames{k});
    lines{end+1} = sprintf('%-13s  %5.2f m   %+.4f    %+.4f    %.3f    %+.4f    %+.2f', ...
        fnames{k}, r.h_med, r.alpha, r.beta, r.R2, r.alpha_theory, r.alpha_ratio); %#ok<AGROW>
end
text(ax, 0.02, 0.95, strjoin(lines, newline), ...
    'Units','normalized','FontName','Courier','FontSize',10, ...
    'VerticalAlignment','top','Interpreter','none');

txt2 = {
    'Interpretation:'
    '  alpha < 0, magnitude near theory  →  real Stokes return flow'
    '  beta near 0                        →  no constant instrumental offset'
    '  alpha consistent across instruments →  not per-instrument artifact'
    '  R^2 modest is OK — H_s^2 is one driver among several (tide, wind, alongshore)'
};
text(ax, 0.02, 0.40, strjoin(txt2, newline), ...
    'Units','normalized','FontSize',10, 'VerticalAlignment','top');

sgtitle(sprintf('%s — Test 1: uMean vs H_s^2 scaling', deployment));
exportgraphics(fig, fullfile(opts.figDir, 'test1_Hs2_scaling.png'), 'Resolution', 200);
close(fig);

fprintf('\nFigure saved: %s\n', fullfile(opts.figDir, 'test1_Hs2_scaling.png'));
end
