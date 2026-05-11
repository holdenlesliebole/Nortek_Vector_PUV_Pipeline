% FIG_L4_XSPEC  Pairwise IG cross-spectrum summary figure for one deployment.
%
%   Loads outputs/L4_xspec/{deployment}/xspec.mat and writes a 4-panel
%   summary PNG to outputs/validation/L4_xspec/{deployment}/:
%
%     (1) Time-mean coherence^2(f) for every pair, colored by alongshore
%         separation magnitude.
%     (2) Power-weighted mean cross-phase phi(f) for every pair (rad).
%     (3) Mean coh^2 in the IG band vs alongshore separation, with
%         cross-shore pairs marked separately.
%     (4) Map of instrument geometry (lat/lon) annotated with pair lines.
%
%   USAGE
%     deployment_name = 'TBR23';
%     run fig_L4_xspec
% Author: Holden Leslie-Bole, 2026

%% ======================== USER SETTINGS ========================
deployment_name = 'TBR23';

%% ======================== SETUP ========================
startup_puv

registry = deployment_registry();
configFn = registry(deployment_name);
cfg      = configFn();

xsFile = fullfile(cfg.outputDir, 'L4_xspec', cfg.name, 'xspec.mat');
if ~isfile(xsFile)
    error('fig_L4_xspec:noFile', 'Not found: %s\nRun PUV_L4_xspec_driver first.', xsFile);
end
loaded = load(xsFile, 'L4xs');
L4xs   = loaded.L4xs;

figDir = fullfile(cfg.outputDir, 'validation', 'L4_xspec', cfg.name);
if ~exist(figDir, 'dir'), mkdir(figDir); end

fIG    = L4xs.fIG;
pairs  = L4xs.pairs;
nPairs = numel(pairs);
fprintf('\n=== fig_L4_xspec: %s (%d pairs) ===\n', deployment_name, nPairs);

%% ======================== AGGREGATES ========================
sepAlong   = arrayfun(@(p) p.sep_alongshore, pairs);
sepCross   = arrayfun(@(p) p.sep_crossshore, pairs);
sepTot     = arrayfun(@(p) p.sep_total,      pairs);
meanCohIG  = arrayfun(@(p) p.mean_coh2_IG,   pairs);

% color by |sep_alongshore|
absAlong = abs(sepAlong);
cmin = 0;
cmax = max(absAlong) + eps;
cmap = parula(nPairs);

%% ======================== FIGURE ========================
fig = figure('Visible', 'off', 'Position', [100 100 1300 900]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

% --- (1) coh^2(f) per pair ---
nexttile;
hold on;
hLines = gobjects(nPairs, 1);
labels = cell(nPairs, 1);
% sort by |alongshore| for legend coherence
[~, sortIdx] = sort(absAlong);
for kIdx = 1:nPairs
    p = pairs(sortIdx(kIdx));
    cFrac = (absAlong(sortIdx(kIdx)) - cmin) / (cmax - cmin);
    cFrac = min(max(cFrac, 0), 1);
    col = interp1(linspace(0,1,size(cmap,1)), cmap, cFrac);
    hLines(kIdx) = plot(fIG, p.mean_coh2_f, '-', 'LineWidth', 1.4, 'Color', col);
    labels{kIdx} = sprintf('%s↔%s (Δy=%.0fm,Δx=%.0fm)', ...
        p.labels{1}, p.labels{2}, p.sep_alongshore, p.sep_crossshore);
end
yline(0, 'k:');
xlabel('Frequency (Hz)');
ylabel('⟨γ²(f)⟩_t');
title(sprintf('IG cross-coherence vs frequency — %s', deployment_name), 'Interpreter','none');
xlim(L4xs.bandIG);
ylim([0 1]);
legend(hLines, labels, 'Location', 'northeast', 'Interpreter','none', 'FontSize', 7);
grid on;

% --- (2) cross-phase(f) per pair ---
nexttile;
hold on;
for kIdx = 1:nPairs
    p = pairs(sortIdx(kIdx));
    cFrac = (absAlong(sortIdx(kIdx)) - cmin) / (cmax - cmin);
    cFrac = min(max(cFrac, 0), 1);
    col = interp1(linspace(0,1,size(cmap,1)), cmap, cFrac);
    plot(fIG, rad2deg(p.mean_phase_f), '-', 'LineWidth', 1.4, 'Color', col);
end
yline(0, 'k:');
xlabel('Frequency (Hz)');
ylabel('cross-phase φ (deg)');
title('Power-weighted mean phase — φ>0: j leads i');
xlim(L4xs.bandIG);
ylim([-180 180]);
grid on;

% --- (3) mean coh^2(IG) vs separation ---
nexttile;
hold on;
% mark cross-shore-dominated pairs separately
isXshore = abs(sepCross) > abs(sepAlong);
hX = scatter(sepTot(isXshore),  meanCohIG(isXshore),  80, [0.8 0.2 0.2], 'filled', 'MarkerEdgeColor','k');
hY = scatter(sepTot(~isXshore), meanCohIG(~isXshore), 80, [0.2 0.4 0.8], 'filled', 'MarkerEdgeColor','k');
for k = 1:nPairs
    p = pairs(k);
    text(sepTot(k)+5, meanCohIG(k), sprintf('%s/%s', p.labels{1}, p.labels{2}), ...
         'FontSize', 7, 'Interpreter','none');
end
xlabel('total separation (m)');
ylabel('⟨γ²⟩ in IG band');
title('IG coherence vs separation');
if any(isXshore) && any(~isXshore)
    legend([hX hY], {'cross-shore-dominated','alongshore-dominated'}, 'Location', 'northeast');
end
grid on;
ylim([0 1]);

% --- (4) geometry map ---
nexttile;
hold on;
lats = arrayfun(@(s) s.latlon(1), L4xs.instruments);
lons = arrayfun(@(s) s.latlon(2), L4xs.instruments);
for k = 1:nPairs
    p = pairs(k);
    plot([p.latlon_i(2) p.latlon_j(2)], [p.latlon_i(1) p.latlon_j(1)], ...
         'k-', 'LineWidth', 0.5);
end
scatter(lons, lats, 80, 'filled', 'MarkerEdgeColor','k');
for k = 1:numel(L4xs.instruments)
    text(lons(k), lats(k), ['  ' L4xs.instruments(k).label], 'FontSize', 8, 'Interpreter','none');
end
xlabel('lon');
ylabel('lat');
title('Instrument geometry');
axis equal;
grid on;

%% ======================== SAVE ========================
outPng = fullfile(figDir, sprintf('xspec_summary_%s.png', deployment_name));
exportgraphics(fig, outPng, 'Resolution', 200);
close(fig);
fprintf('  Saved: %s\n', outPng);
