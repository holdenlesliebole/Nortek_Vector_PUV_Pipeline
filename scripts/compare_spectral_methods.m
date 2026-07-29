% compare_spectral_methods.m
% Author: Holden Leslie-Bole, 2026
% Process one instrument with three spectral methods and compare results.
% Produces diagnostic figures for advisor discussion.

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

%% Load L1 data
loaded = load('outputs/L1/TBR23/MOP580_7m_processed.mat', 'PUV');
registry = deployment_registry();
cfg = registry('TBR23');
cfg = cfg();
instr = cfg.instruments(2);  % MOP580_7m

%% Process with three methods
methods = {'welch', 'mtm_hybrid', 'mtm_full'};
labels  = {'Hanning/Welch (nfft=256)', 'Multi-taper hybrid (nfft=256, NW=4)', ...
           'Multi-taper full (nfft=2048, NW=4)'};
colors  = [0.2 0.4 0.8; 0.9 0.5 0.1; 0.2 0.7 0.3];

L2 = cell(3, 1);

for m = 1:3
    fprintf('\n=== Processing with %s ===\n', methods{m});
    opts = struct();
    opts.spectralMethod = methods{m};
    opts.NW = 4;
    if strcmp(methods{m}, 'mtm_full')
        opts.nfft = 2048;  % full segment
    end
    L2{m} = PUV_L2_spectral(loaded.PUV, instr, opts);
end

%% Select valid segments common to all three
v = L2{1}.segValid & L2{2}.segValid & L2{3}.segValid;
nValid = sum(v);
fprintf('\n%d segments valid across all methods\n', nValid);

%% Figure 1: Mean spectra overlay
fig1 = figure('Position', [50 50 1100 500], 'Name', 'Mean spectra');

subplot(1,2,1)
for m = 1:3
    meanS = mean(L2{m}.S_eta(:, v), 2, 'omitnan');
    plot(L2{m}.f, meanS, '-', 'Color', colors(m,:), 'LineWidth', 1.5, ...
        'DisplayName', labels{m}); hold on
end
xlabel('Frequency (Hz)'); ylabel('S_\eta (m^2/Hz)');
title('Mean surface elevation spectrum');
xlim([0.03 0.25]); grid on;
legend('Location', 'northeast', 'FontSize', 7);

subplot(1,2,2)
for m = 1:3
    meanS = mean(L2{m}.S_eta(:, v), 2, 'omitnan');
    plot(L2{m}.f, meanS, '-', 'Color', colors(m,:), 'LineWidth', 1.5); hold on
end
xlabel('Frequency (Hz)'); ylabel('S_\eta (m^2/Hz)');
title('Swell peak detail');
xlim([0.04 0.12]); grid on;

%% Figure 2: Bulk parameter comparison (Hs, Tp, meanDir)
fig2 = figure('Position', [50 50 1200 700], 'Name', 'Bulk parameter comparison');

% Hs scatter: method 2 & 3 vs method 1
subplot(2,3,1)
scatter(L2{1}.Hs(v), L2{2}.Hs(v), 4, colors(2,:), 'filled', 'MarkerFaceAlpha', 0.3); hold on
scatter(L2{1}.Hs(v), L2{3}.Hs(v), 4, colors(3,:), 'filled', 'MarkerFaceAlpha', 0.3);
maxH = max(L2{1}.Hs(v)) * 1.05;
plot([0 maxH], [0 maxH], 'k-');
xlabel('H_s Welch (m)'); ylabel('H_s multi-taper (m)');
title('H_s comparison');
legend('Hybrid', 'Full MTM', 'Location', 'southeast', 'FontSize', 7);
axis equal; xlim([0 maxH]); ylim([0 maxH]); grid on;

% Hs difference histograms
subplot(2,3,4)
dHs_hybrid = L2{2}.Hs(v) - L2{1}.Hs(v);
dHs_full   = L2{3}.Hs(v) - L2{1}.Hs(v);
histogram(dHs_hybrid*100, 50, 'FaceColor', colors(2,:), 'FaceAlpha', 0.5, ...
    'DisplayName', sprintf('Hybrid: %.1f \\pm %.1f cm', mean(dHs_hybrid)*100, std(dHs_hybrid)*100)); hold on
histogram(dHs_full*100, 50, 'FaceColor', colors(3,:), 'FaceAlpha', 0.5, ...
    'DisplayName', sprintf('Full: %.1f \\pm %.1f cm', mean(dHs_full)*100, std(dHs_full)*100));
xlabel('\DeltaH_s (cm)'); ylabel('Count');
title('H_s difference (MTM - Welch)');
legend('FontSize', 7); grid on;

% Tp scatter
subplot(2,3,2)
scatter(L2{1}.Tp(v), L2{2}.Tp(v), 4, colors(2,:), 'filled', 'MarkerFaceAlpha', 0.3); hold on
scatter(L2{1}.Tp(v), L2{3}.Tp(v), 4, colors(3,:), 'filled', 'MarkerFaceAlpha', 0.3);
maxT = 22;
plot([4 maxT], [4 maxT], 'k-');
xlabel('T_p Welch (s)'); ylabel('T_p multi-taper (s)');
title('T_p comparison');
xlim([4 maxT]); ylim([4 maxT]); grid on;

% Tp difference histogram
subplot(2,3,5)
dTp_hybrid = L2{2}.Tp(v) - L2{1}.Tp(v);
dTp_full   = L2{3}.Tp(v) - L2{1}.Tp(v);
histogram(dTp_hybrid, 50, 'FaceColor', colors(2,:), 'FaceAlpha', 0.5, ...
    'DisplayName', sprintf('Hybrid: %.2f \\pm %.2f s', mean(dTp_hybrid, 'omitnan'), std(dTp_hybrid, 'omitnan'))); hold on
histogram(dTp_full, 50, 'FaceColor', colors(3,:), 'FaceAlpha', 0.5, ...
    'DisplayName', sprintf('Full: %.2f \\pm %.2f s', mean(dTp_full, 'omitnan'), std(dTp_full, 'omitnan')));
xlabel('\DeltaT_p (s)'); ylabel('Count');
title('T_p difference (MTM - Welch)');
legend('FontSize', 7); grid on;

% Directional spread comparison
subplot(2,3,3)
% Energy-weighted swell-band spread from a1/b1
for m = 1:3
    fSS = L2{m}.params.fSS;
    iSS = L2{m}.f >= fSS(1) & L2{m}.f <= fSS(2);
    r1 = sqrt(L2{m}.a1(iSS, v).^2 + L2{m}.b1(iSS, v).^2);
    spread = rad2deg(sqrt(2 * max(1 - r1, 0)));
    E = L2{m}.S_eta(iSS, v);
    E_sum = sum(E, 1);
    wt_spread = sum(spread .* E, 1) ./ (E_sum + eps);
    L2{m}.wt_spread_SS = wt_spread(:);
end
scatter(L2{1}.wt_spread_SS, L2{2}.wt_spread_SS, 4, colors(2,:), 'filled', 'MarkerFaceAlpha', 0.3); hold on
scatter(L2{1}.wt_spread_SS, L2{3}.wt_spread_SS, 4, colors(3,:), 'filled', 'MarkerFaceAlpha', 0.3);
plot([0 50], [0 50], 'k-');
xlabel('Spread Welch (deg)'); ylabel('Spread MTM (deg)');
title('Directional spread (SS band)');
xlim([0 50]); ylim([0 50]); grid on;

% Radiation stress comparison
subplot(2,3,6)
scatter(L2{1}.Sxx(v), L2{2}.Sxx(v), 4, colors(2,:), 'filled', 'MarkerFaceAlpha', 0.3); hold on
scatter(L2{1}.Sxx(v), L2{3}.Sxx(v), 4, colors(3,:), 'filled', 'MarkerFaceAlpha', 0.3);
maxSxx = max(L2{1}.Sxx(v)) * 1.05;
plot([0 maxSxx], [0 maxSxx], 'k-');
xlabel('S_{xx} Welch (N/m)'); ylabel('S_{xx} MTM (N/m)');
title('Radiation stress S_{xx}');
xlim([0 maxSxx]); ylim([0 maxSxx]); grid on;

%% Figure 3: Single-segment spectral comparison (pick a high-energy segment)
[~, iMax] = max(L2{1}.Hs);
fig3 = figure('Position', [50 50 900 400], 'Name', 'Single segment spectra');

subplot(1,2,1)
for m = 1:3
    plot(L2{m}.f, L2{m}.S_eta(:, iMax), '-', 'Color', colors(m,:), 'LineWidth', 1.2, ...
        'DisplayName', labels{m}); hold on
end
xlabel('Frequency (Hz)'); ylabel('S_\eta (m^2/Hz)');
title(sprintf('Peak segment (H_s = %.2f m)', L2{1}.Hs(iMax)));
xlim([0.03 0.25]); grid on;
legend('Location', 'northeast', 'FontSize', 6);

subplot(1,2,2)
for m = 1:3
    plot(L2{m}.f, L2{m}.S_eta(:, iMax), '-', 'Color', colors(m,:), 'LineWidth', 1.2); hold on
end
xlabel('Frequency (Hz)'); ylabel('S_\eta (m^2/Hz)');
title('Swell peak detail');
xlim([0.04 0.12]); grid on;

%% Figure 4: Pressure-velocity QC diagnostics across spectral methods
% Z-test (P-U transfer-function magnitude) and Q-test (P-U coherence) are the
% two QC diagnostics raised by Bob/Steve. This panel shows BOTH are insensitive
% to the spectral estimator. Regenerated on bug-fixed Z (median ~0.95, not the
% pre-2026-06-05 buggy ~0.79).
fig4 = figure('Position', [50 50 1200 350], 'Name', 'PUV QC vs spectral method');

subplot(1,3,1)
for m = 1:3
    histogram(L2{m}.ztest_SS(v), 40, 'FaceColor', colors(m,:), 'FaceAlpha', 0.4, ...
        'DisplayName', sprintf('%s: med=%.3f', methods{m}, median(L2{m}.ztest_SS(v), 'omitnan'))); hold on
end
xline(1, 'k--', 'HandleVisibility','off'); xlabel('Z-test (SS band)'); ylabel('Count');
title('Z-test SS band'); legend('FontSize', 7); grid on;

subplot(1,3,2)
for m = 1:3
    histogram(L2{m}.ztest_IG(v), 40, 'FaceColor', colors(m,:), 'FaceAlpha', 0.4, ...
        'DisplayName', sprintf('%s: med=%.3f', methods{m}, median(L2{m}.ztest_IG(v), 'omitnan'))); hold on
end
xline(1, 'k--', 'HandleVisibility','off'); xlabel('Z-test (IG band)'); ylabel('Count');
title('Z-test IG band'); legend('FontSize', 7); grid on;

subplot(1,3,3)
for m = 1:3
    histogram(L2{m}.qtest_PU(v), 40, 'FaceColor', colors(m,:), 'FaceAlpha', 0.4, ...
        'DisplayName', sprintf('%s: med=%.3f', methods{m}, median(L2{m}.qtest_PU(v), 'omitnan'))); hold on
end
xline(1, 'k--', 'HandleVisibility','off'); xlabel('P-U coherence (0.05-0.20 Hz)'); ylabel('Count');
title('Q-test: P-U coherence^2'); legend('FontSize', 7, 'Location','northwest'); grid on;

%% Print summary statistics
fprintf('\n=== SUMMARY: Spectral Method Comparison ===\n');
fprintf('TBR23 MOP580_7m, %d valid segments\n\n', nValid);
fprintf('%-25s  %12s  %12s  %12s\n', 'Statistic', 'Welch', 'MTM Hybrid', 'MTM Full');
fprintf('%s\n', repmat('-', 1, 65));

for m = 1:3
    Hs_med(m) = median(L2{m}.Hs(v), 'omitnan');
    Tp_med(m) = median(L2{m}.Tp(v), 'omitnan');
    Ef_med(m) = median(L2{m}.Ef(v), 'omitnan');
    Sxx_med(m) = median(L2{m}.Sxx(v), 'omitnan');
    zSS_med(m) = median(L2{m}.ztest_SS(v), 'omitnan');
    qPU_med(m) = median(L2{m}.qtest_PU(v), 'omitnan');
    sp_med(m) = median(L2{m}.wt_spread_SS, 'omitnan');
end

fprintf('%-25s  %12.3f  %12.3f  %12.3f\n', 'Hs median (m)', Hs_med);
fprintf('%-25s  %12.2f  %12.2f  %12.2f\n', 'Tp median (s)', Tp_med);
fprintf('%-25s  %12.1f  %12.1f  %12.1f\n', 'Ef median (W/m)', Ef_med);
fprintf('%-25s  %12.1f  %12.1f  %12.1f\n', 'Sxx median (N/m)', Sxx_med);
fprintf('%-25s  %12.3f  %12.3f  %12.3f\n', 'Z-test SS median', zSS_med);
fprintf('%-25s  %12.3f  %12.3f  %12.3f\n', 'P-U coherence median', qPU_med);
fprintf('%-25s  %12.1f  %12.1f  %12.1f\n', 'Spread SS median (deg)', sp_med);
fprintf('\n');

fprintf('%-25s  %12s  %12.4f  %12.4f\n', 'Hs bias vs Welch (m)', '--', ...
    median(L2{2}.Hs(v) - L2{1}.Hs(v), 'omitnan'), ...
    median(L2{3}.Hs(v) - L2{1}.Hs(v), 'omitnan'));
fprintf('%-25s  %12s  %12.2f  %12.2f\n', 'Tp bias vs Welch (s)', '--', ...
    median(L2{2}.Tp(v) - L2{1}.Tp(v), 'omitnan'), ...
    median(L2{3}.Tp(v) - L2{1}.Tp(v), 'omitnan'));

%% Save figures
diagDir = fullfile('outputs', 'validation');
exportgraphics(fig1, fullfile(diagDir, 'spectral_method_comparison_spectra.png'), 'Resolution', 200);
exportgraphics(fig2, fullfile(diagDir, 'spectral_method_comparison_bulk.png'), 'Resolution', 200);
exportgraphics(fig3, fullfile(diagDir, 'spectral_method_comparison_single_seg.png'), 'Resolution', 200);
exportgraphics(fig4, fullfile(diagDir, 'spectral_method_comparison_ztest.png'), 'Resolution', 200);
fprintf('Figures saved to %s\n', diagDir);
