function results = analyze_spectral_shape(L2, toolboxPath)
% ANALYZE_SPECTRAL_SHAPE  Test MOP spectral shape bias hypothesis.
%
%   *** DEPRECATED 2026-07-25 — ITS SHAPE METRICS ARE ARTIFACT-CONTAMINATED.
%   *** Use compare_shape_matched.m instead.
%
%   Line 110 interpolates MOP's ~20 coarse frequency bins UP onto the PUV's
%   3601-point grid (74x resolution mismatch), then measures half-power
%   bandwidth and Goda Qp on the fine grid (lines 136-143). Linear
%   interpolation between coarse bin centres manufactures a broad, smooth
%   model peak and depresses int(S^2 df) -- the numerator of Qp. Both metrics
%   are therefore biased in the direction of the hypothesis this function was
%   written to test.
%
%   Quantified: a PUV spectrum compared against a degraded copy of ITSELF
%   through this path returns 68.3% apparent bandwidth narrowing and a Qp
%   ratio of 1.225 (TBR23/MOP586_7m, 1382 segments) -- exceeding the entire
%   effect that was reported as a finding. See validation/test_resolution_artifact.m.
%
%   The fix is to bin the PUV spectrum DOWN onto the model's native bins
%   (shared/bin_spectrum_to_grid.m) so the resolution bias applies identically
%   to both sides and cancels in every ratio.
%
%   Kept for provenance and side-by-side auditing; compare_shape_matched.m
%   reports these legacy metrics alongside the corrected ones. Do not use its
%   Qp/bandwidth/peak-density outputs for any new claim.
%
%   Write-up: PUV_paper/docs/findings_resolution_artifact_2026-07-24.md
%
%   results = analyze_spectral_shape(L2)
%
%   Tests whether the PUV-MOP spectral difference is explained by the MOP
%   model having a broader, flatter spectral peak than the in-situ PUV
%   measurement.
%
%   Diagnostics:
%     1. Spectral bandwidth comparison (Qp peakedness parameter)
%     2. Peak energy density ratio vs bandwidth difference
%     3. Normalized spectral shape comparison (shape vs total energy)
%     4. Excess vs peak period — does bias depend on wave type?
% Author: Holden Leslie-Bole, 2026

if nargin < 2 || isempty(toolboxPath)
    toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
end
if ~exist('read_MOPline2', 'file')
    addpath(toolboxPath);
end

g = 9.81;

%% Load MOP
if isfield(L2, 'mopStation') && ~isempty(L2.mopStation)
    mopStation = L2.mopStation;
else
    mopNum = regexp(L2.label, 'MOP(\d+)', 'tokens', 'once');
    if isempty(mopNum)
        error('analyze_spectral_shape:noStation', ...
            'Cannot determine MOP station for label: %s', L2.label);
    end
    mopStation = ['D0' mopNum{1}];
end

validIdx = L2.segValid;
tStart = min(L2.time(validIdx));
tEnd   = max(L2.time(validIdx));
if isempty(tStart.TimeZone), tStart.TimeZone = 'UTC'; tEnd.TimeZone = 'UTC'; end

fprintf('Loading MOP data for %s...\n', mopStation);
MOP = read_MOPline2(mopStation, tStart, tEnd);

h_mop = double(MOP.depth);
h_puv = median(L2.depth(validIdx), 'omitnan');

% Shoal MOP
freq_mop = double(MOP.frequency(:));
fbw = double(MOP.fbw(:));
omega_mop = 2*pi*freq_mop;
k_mop = get_wavenumber(omega_mop, h_mop);
k_puv = get_wavenumber(omega_mop, h_puv);
cg_mop_h = get_cg(k_mop, h_mop);
cg_puv_h = get_cg(k_puv, h_puv);
shoalFactor = cg_mop_h(:) ./ cg_puv_h(:);
spec_shoaled = MOP.spec1D .* shoalFactor';

%% Match times
t_mop = MOP.time;
L2_time = L2.time;
if isempty(L2_time.TimeZone) && ~isempty(t_mop.TimeZone)
    L2_time.TimeZone = t_mop.TimeZone;
end

validTimes = find(validIdx);
matched_puv = NaN(length(t_mop), 1);
for t = 1:length(t_mop)
    dt = abs(L2_time(validTimes) - t_mop(t));
    [minDt, iMin] = min(dt);
    if minDt < minutes(30)
        matched_puv(t) = validTimes(iMin);
    end
end
hasMatch = ~isnan(matched_puv);
matchedMopIdx = find(hasMatch);
nMatched = sum(hasMatch);
fprintf('  %d matched hours\n\n', nMatched);

%% Frequency grids
f_puv = L2.f;
fSS = L2.params.fSS;
iSS_puv = f_puv >= fSS(1) & f_puv <= fSS(2);
iSS_mop = freq_mop >= fSS(1) & freq_mop <= fSS(2);
df_puv = f_puv(2) - f_puv(1);

%% Per-hour: spectral peakedness and shape metrics
% Goda peakedness parameter: Qp = (2/m0^2) * integral(f * S^2 df)
% Higher Qp = narrower, more peaked spectrum

seg_Qp_puv    = NaN(nMatched, 1);
seg_Qp_mop    = NaN(nMatched, 1);
seg_peakS_puv = NaN(nMatched, 1);  % peak spectral density
seg_peakS_mop = NaN(nMatched, 1);
seg_m0_puv    = NaN(nMatched, 1);
seg_m0_mop    = NaN(nMatched, 1);
seg_Hs_ratio  = NaN(nMatched, 1);
seg_fp_puv    = NaN(nMatched, 1);
seg_fp_mop    = NaN(nMatched, 1);
seg_Tp_mop    = NaN(nMatched, 1);
seg_bw_puv    = NaN(nMatched, 1);  % spectral bandwidth (half-power width)
seg_bw_mop    = NaN(nMatched, 1);

for i = 1:nMatched
    mi = matchedMopIdx(i);
    pi_idx = matched_puv(mi);

    s_puv = L2.S_eta(:, pi_idx);
    s_mop = interp1(freq_mop, spec_shoaled(mi,:)', f_puv, 'linear', 0);

    % Only SS band
    sp = s_puv(iSS_puv);
    sm = s_mop(iSS_puv);
    fp = f_puv(iSS_puv);

    % Zeroth moment
    m0p = trapz(fp, sp);
    m0m = trapz(fp, sm);
    seg_m0_puv(i) = m0p;
    seg_m0_mop(i) = m0m;

    if m0p > 0 && m0m > 0
        seg_Hs_ratio(i) = sqrt(m0p / m0m);  % Hs ratio = sqrt(m0 ratio)

        % Goda peakedness Qp
        seg_Qp_puv(i) = (2 / m0p^2) * trapz(fp, fp .* sp.^2);
        seg_Qp_mop(i) = (2 / m0m^2) * trapz(fp, fp .* sm.^2);

        % Peak spectral density
        [seg_peakS_puv(i), iPk_p] = max(sp);
        [seg_peakS_mop(i), iPk_m] = max(sm);
        seg_fp_puv(i) = fp(iPk_p);
        seg_fp_mop(i) = fp(iPk_m);

        % Half-power bandwidth
        halfPow_p = seg_peakS_puv(i) / 2;
        aboveHalf_p = sp >= halfPow_p;
        seg_bw_puv(i) = sum(aboveHalf_p) * df_puv;

        halfPow_m = seg_peakS_mop(i) / 2;
        aboveHalf_m = sm >= halfPow_m;
        seg_bw_mop(i) = sum(aboveHalf_m) * df_puv;
    end

    seg_Tp_mop(i) = 1 / double(MOP.fp(mi));
end

%% Print diagnostics
fprintf('=== Spectral Shape Analysis: %s (%s) ===\n', L2.label, L2.deploymentName);
fprintf('  PUV depth: %.1f m\n\n', h_puv);

goodQ = ~isnan(seg_Qp_puv) & ~isnan(seg_Qp_mop);

fprintf('  Goda peakedness parameter Qp:\n');
fprintf('    PUV:  median = %.2f,  mean = %.2f\n', ...
    median(seg_Qp_puv(goodQ)), mean(seg_Qp_puv(goodQ)));
fprintf('    MOP:  median = %.2f,  mean = %.2f\n', ...
    median(seg_Qp_mop(goodQ)), mean(seg_Qp_mop(goodQ)));
fprintf('    PUV/MOP Qp ratio: %.3f\n', ...
    median(seg_Qp_puv(goodQ)) / median(seg_Qp_mop(goodQ)));
if median(seg_Qp_puv(goodQ)) > median(seg_Qp_mop(goodQ))
    fprintf('    → PUV spectrum is MORE peaked than MOP\n');
else
    fprintf('    → PUV spectrum is LESS peaked than MOP\n');
end

fprintf('\n  Half-power spectral bandwidth:\n');
fprintf('    PUV:  median = %.4f Hz\n', median(seg_bw_puv(goodQ)));
fprintf('    MOP:  median = %.4f Hz\n', median(seg_bw_mop(goodQ)));
if median(seg_bw_puv(goodQ)) < median(seg_bw_mop(goodQ))
    fprintf('    → PUV peak is narrower than MOP by %.1f%%\n', ...
        100 * (1 - median(seg_bw_puv(goodQ)) / median(seg_bw_mop(goodQ))));
else
    fprintf('    → PUV peak is wider than MOP\n');
end

fprintf('\n  Peak spectral density:\n');
fprintf('    PUV:  median = %.4f m^2/Hz\n', median(seg_peakS_puv(goodQ)));
fprintf('    MOP:  median = %.4f m^2/Hz\n', median(seg_peakS_mop(goodQ)));
fprintf('    PUV/MOP peak ratio: %.3f\n', ...
    median(seg_peakS_puv(goodQ)) / median(seg_peakS_mop(goodQ)));

% Correlation: Qp difference vs Hs ratio
fprintf('\n  Peakedness difference vs Hs amplification:\n');
Qp_diff = seg_Qp_puv - seg_Qp_mop;
goodCorr = goodQ & ~isnan(seg_Hs_ratio);
if sum(goodCorr) > 20
    R = corrcoef(Qp_diff(goodCorr), seg_Hs_ratio(goodCorr));
    fprintf('    R = %.3f, R^2 = %.3f (N = %d)\n', R(1,2), R(1,2)^2, sum(goodCorr));
    if R(1,2) > 0.2
        fprintf('    → Hours when PUV is more peaked also have higher Hs ratio\n');
        fprintf('    → Supports spectral shape hypothesis\n');
    else
        fprintf('    → Weak correlation\n');
    end
end

% Test: does the ratio depend on wave period?
fprintf('\n  Low-swell ratio vs peak period:\n');
goodTp = ~isnan(seg_Tp_mop) & ~isnan(seg_Hs_ratio);
if sum(goodTp) > 20
    R = corrcoef(seg_Tp_mop(goodTp), seg_Hs_ratio(goodTp).^2);
    fprintf('    Hs_ratio^2 vs Tp: R = %.3f (N = %d)\n', R(1,2), sum(goodTp));

    % Bin by period
    tpEdges = [6 8 10 12 14 16 18 22];
    fprintf('\n    %-12s  %-12s  %-8s  %-8s\n', 'Tp range', 'Med Hs ratio', 'Med Qp_PUV', 'Med Qp_MOP');
    fprintf('    %s\n', repmat('-', 1, 48));
    for j = 1:length(tpEdges)-1
        mask = seg_Tp_mop >= tpEdges(j) & seg_Tp_mop < tpEdges(j+1) & goodCorr;
        if sum(mask) > 10
            fprintf('    %2d–%2d s       %-12.4f  %-8.2f  %-8.2f\n', ...
                tpEdges(j), tpEdges(j+1), ...
                median(seg_Hs_ratio(mask)), ...
                median(seg_Qp_puv(mask)), ...
                median(seg_Qp_mop(mask)));
        end
    end
end

%% ======================== FIGURES ========================

%% Figure 1: Mean normalized spectral shape
fig1 = figure('Position', [100 100 900 500], 'Name', 'Normalized spectral shape');

% Compute normalized mean spectra (each hour's spectrum normalized by its m0)
normPUV_sum = zeros(length(f_puv), 1);
normMOP_sum = zeros(length(f_puv), 1);
nNorm = 0;

for i = 1:nMatched
    mi = matchedMopIdx(i);
    pi_idx = matched_puv(mi);

    s_puv = L2.S_eta(:, pi_idx);
    s_mop = interp1(freq_mop, spec_shoaled(mi,:)', f_puv, 'linear', 0);

    m0p = trapz(f_puv(iSS_puv), s_puv(iSS_puv));
    m0m = trapz(f_puv(iSS_puv), s_mop(iSS_puv));

    if m0p > 0 && m0m > 0
        normPUV_sum = normPUV_sum + s_puv / m0p;
        normMOP_sum = normMOP_sum + s_mop / m0m;
        nNorm = nNorm + 1;
    end
end

normPUV = normPUV_sum / nNorm;
normMOP = normMOP_sum / nNorm;

subplot(2,1,1)
plot(f_puv, normPUV, 'b-', 'LineWidth', 2, 'DisplayName', ...
    sprintf('PUV (%.1fm)', h_puv)); hold on
plot(f_puv, normMOP, 'r-', 'LineWidth', 2, 'DisplayName', ...
    sprintf('MOP shoaled (%.1fm)', h_puv));
xlabel('Frequency (Hz)');
ylabel('S_\eta / m_0 (normalized)');
title('Mean normalized spectral shape (each spectrum normalized by its variance)');
legend('Location', 'northeast');
xlim([0.03 0.3]); grid on;

subplot(2,1,2)
shapeRatio = normPUV ./ normMOP;
shapeRatio(normMOP < max(normMOP)*0.01) = NaN;
plot(f_puv, shapeRatio, 'k-', 'LineWidth', 2); hold on
yline(1, 'k--');
xlabel('Frequency (Hz)');
ylabel('Normalized shape ratio');
title('PUV/MOP shape ratio (>1 = PUV has relatively more energy at this frequency)');
xlim([0.03 0.3]); grid on;

sgtitle(sprintf('%s — %s: Spectral shape comparison', ...
    L2.deploymentName, L2.label), 'FontWeight', 'bold');

%% Figure 2: Qp comparison and Hs ratio scatter
fig2 = figure('Position', [100 100 1200 500], 'Name', 'Peakedness');

subplot(1,3,1)
scatter(seg_Qp_mop(goodQ), seg_Qp_puv(goodQ), 8, 'filled', 'MarkerFaceAlpha', 0.2);
hold on
lims = [min([seg_Qp_mop(goodQ); seg_Qp_puv(goodQ)]), ...
        max([seg_Qp_mop(goodQ); seg_Qp_puv(goodQ)])];
plot(lims, lims, 'k--', 'LineWidth', 1);
xlabel('MOP Qp'); ylabel('PUV Qp');
title('Goda peakedness Qp');
axis equal; grid on;

subplot(1,3,2)
scatter(Qp_diff(goodCorr), seg_Hs_ratio(goodCorr), 8, 'filled', 'MarkerFaceAlpha', 0.2);
hold on; yline(1, 'k--'); xline(0, 'k--');
xlabel('\DeltaQp (PUV − MOP)');
ylabel('Hs ratio (PUV/MOP)');
title('Peakedness difference vs amplification');
grid on;

subplot(1,3,3)
scatter(seg_bw_mop(goodQ) - seg_bw_puv(goodQ), seg_Hs_ratio(goodQ), ...
    8, 'filled', 'MarkerFaceAlpha', 0.2);
hold on; yline(1, 'k--'); xline(0, 'k--');
xlabel('\DeltaBW (MOP − PUV) (Hz)');
ylabel('Hs ratio (PUV/MOP)');
title('Bandwidth difference vs amplification');
grid on;

sgtitle(sprintf('%s — %s: Spectral peakedness analysis', ...
    L2.deploymentName, L2.label), 'FontWeight', 'bold');

%% Save
diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end

exportgraphics(fig1, fullfile(diagDir, sprintf('%s_%s_normalized_shape.png', ...
    L2.deploymentName, L2.label)), 'Resolution', 200);
exportgraphics(fig2, fullfile(diagDir, sprintf('%s_%s_peakedness.png', ...
    L2.deploymentName, L2.label)), 'Resolution', 200);
fprintf('\n  Figures saved to %s\n', diagDir);

%% Store results
results.label = L2.label;
results.deployment = L2.deploymentName;
results.h_puv = h_puv;
results.seg_Qp_puv = seg_Qp_puv;
results.seg_Qp_mop = seg_Qp_mop;
results.seg_peakS_puv = seg_peakS_puv;
results.seg_peakS_mop = seg_peakS_mop;
results.seg_bw_puv = seg_bw_puv;
results.seg_bw_mop = seg_bw_mop;
results.seg_Hs_ratio = seg_Hs_ratio;
results.seg_Tp_mop = seg_Tp_mop;
results.normPUV = normPUV;
results.normMOP = normMOP;
results.f = f_puv;

end
