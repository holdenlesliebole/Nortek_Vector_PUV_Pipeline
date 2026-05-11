% FIG_L4_DIAGNOSTIC  Per-instrument 3-panel L4 IG / bound-wave diagnostic.
%
%   Loops over every L4 .mat file in outputs/L4/{deployment}/ and produces
%   a 4-panel PNG per instrument summarising the IG / bound-wave outputs:
%
%     (1) Frequency-resolved reflection coefficient R²(f) over the IG band
%         with the full-IG-band scalar R²_IG marked.
%     (2) Time-mean bicoherence map Bic_mean(f1, f2) with the swell self-
%         coupling and swell-IG difference-coupling regions outlined and
%         the 95% significance contour overlaid.
%     (3) Per-segment bound-IG coupling metric (bic_swell_ig_diff) vs time
%         with the median b95 threshold.
%     (4) IG energy flux timeseries: shoreward vs seaward.
%
%   At the end of the loop, also produces a cross-instrument summary
%   figure of bic_swell_ig_diff and R²_IG vs depth across the deployment.
%
%   USAGE
%     deployment_name = 'TBR23';   % edit at top of script
%     run fig_L4_diagnostic
% Author: Holden Leslie-Bole, 2026

%% ======================== USER SETTINGS ========================
deployment_name = 'TBR23';

%% ======================== SETUP ========================
startup_puv

registry = deployment_registry();
configFn = registry(deployment_name);
cfg      = configFn();

l4Dir  = fullfile(cfg.outputDir, 'L4', cfg.name);
figDir = fullfile(cfg.outputDir, 'validation', 'L4_diagnostic', cfg.name);
if ~exist(figDir, 'dir'), mkdir(figDir); end

l4Files = dir(fullfile(l4Dir, '*_L4.mat'));
if isempty(l4Files)
    error('fig_L4_diagnostic:noFiles', ...
        'No L4 files found in %s. Run PUV_L4_driver first.', l4Dir);
end

fprintf('\n=== L4 diagnostics: %s (%d instruments) ===\n', deployment_name, numel(l4Files));

% Cross-instrument summary collectors
labels       = {};
depths_all   = [];
bicDiff_med  = [];
R2IG_med     = [];

for k = 1:numel(l4Files)
    fname  = fullfile(l4Dir, l4Files(k).name);
    loaded = load(fname, 'L4');
    L4     = loaded.L4;
    instrLabel = L4.label;
    fprintf('  [%d/%d] %s\n', k, numel(l4Files), instrLabel);

    valid    = L4.bispectra.segValid;
    if ~any(valid), continue, end
    medDepth = median(L4.eta.depth, 'omitnan');

    % --- Figure ---
    fig = figure('Visible', 'off', 'Position', [100 100 1200 900]);
    tiledlayout(3, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    % --- (1) R²(f) over IG band ---
    nexttile([1 1]);
    R2_med = median(L4.ref.R2_f, 2, 'omitnan');
    R2_q1  = quantile(L4.ref.R2_f, 0.25, 2);
    R2_q3  = quantile(L4.ref.R2_f, 0.75, 2);
    fIG    = L4.ref.fIG;
    fill([fIG; flipud(fIG)], [R2_q1; flipud(R2_q3)], [0.7 0.8 0.9], ...
        'EdgeColor','none','FaceAlpha',0.5); hold on;
    plot(fIG, R2_med, 'b', 'LineWidth', 1.5);
    yline(median(L4.ref.R2_IG, 'omitnan'), 'r--', 'LineWidth', 1, ...
        'Label', sprintf('R^2_{IG} median = %.2f', median(L4.ref.R2_IG, 'omitnan')));
    yline(1, 'k:');
    xlabel('Frequency (Hz)'); ylabel('R^2(f)');
    title(sprintf('Reflection coefficient — %s (H~%.1f m)', instrLabel, medDepth), ...
        'Interpreter','none');
    grid on; xlim([0.004 0.04]); ylim([0 max(2, max(R2_q3)*1.1)]);

    % --- (2) Time-mean bicoherence map ---
    nexttile([1 1]);
    f = L4.bispectra.f;
    Bic = L4.bispectra.Bic_mean;
    imagesc(f, f, Bic); set(gca, 'YDir', 'normal'); hold on;
    cmap = colormap(gca, 'parula'); cb = colorbar;
    cb.Label.String = 'Bic_{mean}'; cb.Label.Interpreter = 'tex';
    clim([0 max(Bic(:))]);
    % b95 contour
    b95med = median(L4.bispectra.b95, 'omitnan');
    contour(f, f, Bic, [b95med b95med], 'w', 'LineWidth', 1);
    % Swell self-coupling diagonal (Stokes 2nd)
    plot([0.04 0.25], [0.04 0.25], 'r--', 'LineWidth', 1.0);
    % Swell-IG-diff cells outline (f1 in swell, f2 in IG, f1+f2 in swell)
    rectangle('Position', [0.04 0.004 0.21 0.036], ...
        'EdgeColor', [0.9 0.4 0.0], 'LineStyle', '-', 'LineWidth', 1.2);
    xlabel('f_1 (Hz)'); ylabel('f_2 (Hz)');
    title(sprintf('Bicoherence (mean over %d segs)', L4.bispectra.nValid));
    xlim([0 0.30]); ylim([0 0.10]);
    text(0.12, 0.21, sprintf('b95 ≈ %.2f', b95med), 'Color', 'w', 'FontSize', 8);
    text(0.045, 0.005, 'swell-IG diff', 'Color', [0.9 0.4 0.0], 'FontSize', 8);
    text(0.13, 0.135, 'Stokes 2nd', 'Color', 'r', 'FontSize', 8, 'Rotation', 0);

    % --- (3) Bound-IG coupling metric vs time ---
    nexttile([1 2]);
    t      = L4.bispectra.time;
    bicDiff= L4.bispectra.bic_swell_ig_diff;
    bicSelf= L4.bispectra.bic_swell_self;
    plot(t, bicDiff, '.', 'MarkerSize', 4, 'Color', [0.9 0.4 0.0]); hold on;
    plot(t, bicSelf, '.', 'MarkerSize', 4, 'Color', [0.0 0.4 0.7]);
    yline(b95med, 'k--', 'LineWidth', 0.8, ...
        'Label', sprintf('b95=%.2f', b95med), 'LabelHorizontalAlignment','left');
    xlabel('Time'); ylabel('Bic peak');
    legend({'swell-IG diff (bound)', 'swell self (Stokes)'}, 'Location', 'best');
    title('Per-segment coupling metrics'); grid on;

    % --- (4) IG flux timeseries ---
    nexttile([1 2]);
    plot(L4.ref.time, L4.ref.Ef_IG_in,  '-', 'Color', [0.0 0.4 0.7], 'LineWidth', 0.6); hold on;
    plot(L4.ref.time, L4.ref.Ef_IG_out, '-', 'Color', [0.7 0.4 0.0], 'LineWidth', 0.6);
    plot(L4.ref.time, L4.ref.Ef_IG_net, '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.8);
    yline(0, 'k:');
    xlabel('Time'); ylabel('IG energy flux (W/m)');
    legend({'F_{in} shoreward', 'F_{out} seaward', 'F_{net} = in - out'}, ...
        'Location', 'best', 'Interpreter','tex');
    title(sprintf('IG energy flux (median R^2_{IG} = %.2f)', median(L4.ref.R2_IG,'omitnan')));
    grid on;

    sgtitle(sprintf('%s / %s — L4 diagnostic', deployment_name, instrLabel), ...
        'Interpreter','none');

    outFig = fullfile(figDir, sprintf('%s_L4_diagnostic.png', instrLabel));
    exportgraphics(fig, outFig, 'Resolution', 150);
    close(fig);
    fprintf('    saved %s\n', outFig);

    labels{end+1, 1} = instrLabel;          %#ok<SAGROW>
    depths_all(end+1, 1) = medDepth;        %#ok<SAGROW>
    bicDiff_med(end+1, 1) = median(bicDiff(valid), 'omitnan'); %#ok<SAGROW>
    R2IG_med(end+1, 1)    = median(L4.ref.R2_IG(valid), 'omitnan'); %#ok<SAGROW>
end

%% ======================== Cross-instrument summary ========================
if numel(labels) > 1
    fig = figure('Visible', 'off', 'Position', [100 100 1000 400]);
    tiledlayout(1, 2, 'Padding', 'compact');

    nexttile;
    scatter(depths_all, bicDiff_med, 80, 'filled'); hold on;
    text(depths_all + 0.1, bicDiff_med, labels, 'FontSize', 8, 'Interpreter','none');
    xlabel('Median depth H (m)'); ylabel('median bic\_swell\_ig\_diff');
    title({'Bound-IG coupling vs depth', '(should increase shoreward/shallower)'});
    grid on;

    nexttile;
    scatter(depths_all, R2IG_med, 80, 'filled'); hold on;
    text(depths_all + 0.1, R2IG_med, labels, 'FontSize', 8, 'Interpreter','none');
    yline(1, 'k--');
    xlabel('Median depth H (m)'); ylabel('median R^2_{IG}');
    title({'IG reflection coefficient vs depth', '(R^2 → 1 with bound-IG contamination)'});
    grid on;

    sgtitle(sprintf('%s — L4 cross-instrument summary', deployment_name), 'Interpreter','none');

    outFig = fullfile(figDir, sprintf('%s_L4_summary.png', deployment_name));
    exportgraphics(fig, outFig, 'Resolution', 150);
    close(fig);
    fprintf('\nSaved cross-instrument summary: %s\n', outFig);
end

fprintf('\nDiagnostics complete. Figures in: %s\n', figDir);
