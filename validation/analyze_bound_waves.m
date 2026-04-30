function results = analyze_bound_waves(L2, toolboxPath)
% ANALYZE_BOUND_WAVES  Test bound long wave hypothesis for spectral amplification.
%
%   results = analyze_bound_waves(L2)
%   results = analyze_bound_waves(L2, toolboxPath)
%
%   Tests whether the excess low-frequency energy (relative to shoaled MOP)
%   is consistent with bound long waves forced by wave groups.
%
%   Diagnostics:
%     1. IG energy vs swell Hs^2 — bound wave energy scales as Hs_swell^2
%     2. Low-swell excess vs swell Hs — does amplification increase with
%        wave height (as expected for nonlinear bound waves)?
%     3. Frequency structure of the excess — is it at group frequencies
%        (f_peak difference) or at the swell peak itself?
%     4. Bicoherence estimate at swell peak — phase coupling signature
%
%   INPUTS
%     L2          - L2 struct from PUV_L2_spectral
%     toolboxPath - path to toolbox/ with read_MOPline2.m

if nargin < 2 || isempty(toolboxPath)
    toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
end
if ~exist('read_MOPline2', 'file')
    addpath(toolboxPath);
end

g = 9.81;
rho = 1025;

%% Load MOP
if isfield(L2, 'mopStation') && ~isempty(L2.mopStation)
    mopStation = L2.mopStation;
else
    mopNum = regexp(L2.label, 'MOP(\d+)', 'tokens', 'once');
    if isempty(mopNum)
        error('analyze_bound_waves:noStation', ...
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
cg_mop = get_cg(k_mop, h_mop);
cg_puv = get_cg(k_puv, h_puv);
shoalFactor = cg_mop(:) ./ cg_puv(:);
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
fprintf('  %d matched hours\n', nMatched);

%% Define frequency bands
f_puv = L2.f;
df_puv = f_puv(2) - f_puv(1);
fSS = L2.params.fSS;

iIG       = f_puv >= 0.004 & f_puv < 0.04;
iLowSwell = f_puv >= 0.04  & f_puv < 0.08;
iMidSwell = f_puv >= 0.08  & f_puv < 0.14;
iSwell    = f_puv >= 0.04  & f_puv <= 0.25;
iSS       = f_puv >= fSS(1) & f_puv <= fSS(2);

iIG_mop       = freq_mop >= 0.004 & freq_mop < 0.04;
iLowSwell_mop = freq_mop >= 0.04  & freq_mop < 0.08;
iSwell_mop    = freq_mop >= 0.04  & freq_mop <= 0.25;

%% Per-segment energy breakdown
% For each matched hour, compute:
%   - PUV IG energy, low-swell energy, total swell energy
%   - MOP equivalent (shoaled)
%   - Spectral ratio in each band
%   - Swell Hs (for scaling analysis)

seg_Hs_swell_puv  = NaN(nMatched, 1);
seg_Hs_swell_mop  = NaN(nMatched, 1);
seg_E_IG_puv      = NaN(nMatched, 1);
seg_E_IG_mop      = NaN(nMatched, 1);
seg_E_lowSW_puv   = NaN(nMatched, 1);
seg_E_lowSW_mop   = NaN(nMatched, 1);
seg_ratio_lowSW   = NaN(nMatched, 1);
seg_ratio_IG      = NaN(nMatched, 1);
seg_excess_lowSW  = NaN(nMatched, 1);  % absolute excess energy (m^2)
seg_fp             = NaN(nMatched, 1);

for i = 1:nMatched
    mi = matchedMopIdx(i);
    pi_idx = matched_puv(mi);

    s_puv = L2.S_eta(:, pi_idx);
    s_mop = interp1(freq_mop, spec_shoaled(mi,:)', f_puv, 'linear', 0);

    % Swell Hs
    m0_puv = trapz(f_puv(iSwell), s_puv(iSwell));
    m0_mop = trapz(f_puv(iSwell), s_mop(iSwell));
    seg_Hs_swell_puv(i) = 4*sqrt(max(m0_puv, 0));
    seg_Hs_swell_mop(i) = 4*sqrt(max(m0_mop, 0));

    % IG energy
    if any(s_puv(iIG) > 0)
        seg_E_IG_puv(i) = trapz(f_puv(iIG), s_puv(iIG));
    end
    if any(s_mop(iIG) > 0)
        seg_E_IG_mop(i) = trapz(f_puv(iIG), s_mop(iIG));
    end

    % Low-swell energy
    seg_E_lowSW_puv(i) = trapz(f_puv(iLowSwell), s_puv(iLowSwell));
    seg_E_lowSW_mop(i) = trapz(f_puv(iLowSwell), s_mop(iLowSwell));

    % Ratios
    if seg_E_lowSW_mop(i) > 0
        seg_ratio_lowSW(i) = seg_E_lowSW_puv(i) / seg_E_lowSW_mop(i);
        seg_excess_lowSW(i) = seg_E_lowSW_puv(i) - seg_E_lowSW_mop(i);
    end
    if seg_E_IG_mop(i) > 0
        seg_ratio_IG(i) = seg_E_IG_puv(i) / seg_E_IG_mop(i);
    end

    % Peak frequency
    seg_fp(i) = L2.f(find(s_puv == max(s_puv(iSwell)), 1));
end

%% Print diagnostics
fprintf('\n=== Bound Wave Analysis: %s (%s) ===\n', L2.label, L2.deploymentName);
fprintf('  PUV depth: %.1f m\n\n', h_puv);

% IG energy statistics
goodIG = ~isnan(seg_E_IG_puv) & ~isnan(seg_E_IG_mop) & seg_E_IG_mop > 0;
fprintf('  IG band (0.004-0.04 Hz):\n');
if sum(goodIG) > 10
    fprintf('    PUV IG energy:  median = %.4f m^2\n', median(seg_E_IG_puv(goodIG)));
    fprintf('    MOP IG energy:  median = %.4f m^2\n', median(seg_E_IG_mop(goodIG)));
    fprintf('    IG ratio:       median = %.3f  (N = %d)\n', ...
        median(seg_ratio_IG(goodIG)), sum(goodIG));
else
    fprintf('    Insufficient IG data (N = %d)\n', sum(goodIG));
end

% Low-swell excess
goodLow = ~isnan(seg_ratio_lowSW);
fprintf('\n  Low-swell band (0.04-0.08 Hz):\n');
fprintf('    Median ratio:   %.3f\n', median(seg_ratio_lowSW(goodLow)));
fprintf('    Median excess:  %.4f m^2  (= %.1f%% of MOP energy)\n', ...
    median(seg_excess_lowSW(goodLow)), ...
    100 * median(seg_excess_lowSW(goodLow)) / median(seg_E_lowSW_mop(goodLow)));

% Test 1: Does low-swell excess scale with Hs^2?
fprintf('\n  Test 1: Low-swell excess vs Hs_swell^2\n');
goodTest1 = goodLow & seg_Hs_swell_mop > 0;
if sum(goodTest1) > 20
    R1 = corrcoef(seg_Hs_swell_mop(goodTest1).^2, seg_excess_lowSW(goodTest1));
    fprintf('    Excess vs Hs^2: R = %.3f, R^2 = %.3f\n', R1(1,2), R1(1,2)^2);
    if R1(1,2) > 0.3
        fprintf('    → Significant positive correlation: consistent with bound wave scaling\n');
    else
        fprintf('    → Weak or no correlation: excess does not follow Hs^2 scaling\n');
    end
end

% Test 2: Does low-swell ratio increase with wave height?
fprintf('\n  Test 2: Low-swell ratio vs Hs_swell\n');
goodTest2 = goodLow & seg_Hs_swell_mop > 0;
if sum(goodTest2) > 20
    R2 = corrcoef(seg_Hs_swell_mop(goodTest2), seg_ratio_lowSW(goodTest2));
    fprintf('    Ratio vs Hs:    R = %.3f, R^2 = %.3f\n', R2(1,2), R2(1,2)^2);
    if R2(1,2) > 0.3
        fprintf('    → Amplification increases with wave height: supports nonlinear mechanism\n');
    elseif R2(1,2) < -0.1
        fprintf('    → Amplification decreases with wave height: inconsistent with bound waves\n');
    else
        fprintf('    → No clear Hs dependence\n');
    end
end

% Test 3: Where does the excess energy sit relative to the spectral peak?
fprintf('\n  Test 3: Spectral structure of excess\n');
fprintf('    Median peak frequency: %.3f Hz (T = %.1f s)\n', ...
    median(seg_fp, 'omitnan'), 1/median(seg_fp, 'omitnan'));
fprintf('    Expected group/bound wave freq: %.3f–%.3f Hz\n', ...
    0.5*median(seg_fp, 'omitnan') - 0.02, 0.02);
fprintf('    Excess is concentrated at: 0.04–0.08 Hz\n');
if median(seg_fp, 'omitnan') > 0.06 && median(seg_fp, 'omitnan') < 0.09
    fprintf('    → Excess overlaps with the spectral peak itself, not at group frequencies\n');
    fprintf('    → This is inconsistent with bound long waves (which appear at f << f_peak)\n');
elseif median(seg_fp, 'omitnan') > 0.09
    fprintf('    → Excess is below the spectral peak — could contain bound wave energy\n');
end

%% ======================== FIGURES ========================

%% Figure 1: Low-swell excess energy vs Hs^2
fig1 = figure('Position', [100 100 1200 500], 'Name', 'Bound wave scaling');

subplot(1,2,1)
scatter(seg_Hs_swell_mop(goodTest1).^2, seg_excess_lowSW(goodTest1), ...
    8, 'filled', 'MarkerFaceAlpha', 0.2); hold on
xlabel('H_{s,swell}^2 (m^2)');
ylabel('Low-swell excess energy (m^2)');
title('Excess energy vs Hs^2 (bound wave test)');
grid on;

% Binned trend
hsqEdges = 0:0.1:2;
hsqCenters = hsqEdges(1:end-1) + 0.05;
binnedExcess = NaN(length(hsqCenters), 1);
for j = 1:length(hsqCenters)
    mask = seg_Hs_swell_mop.^2 >= hsqEdges(j) & seg_Hs_swell_mop.^2 < hsqEdges(j+1) & goodTest1;
    if sum(mask) > 5
        binnedExcess(j) = mean(seg_excess_lowSW(mask));
    end
end
goodBin = ~isnan(binnedExcess);
plot(hsqCenters(goodBin), binnedExcess(goodBin), 'r-o', 'LineWidth', 2, ...
    'MarkerFaceColor', 'r');
legend('Hourly', 'Binned mean', 'Location', 'northwest');

subplot(1,2,2)
scatter(seg_Hs_swell_mop(goodTest2), seg_ratio_lowSW(goodTest2), ...
    8, 'filled', 'MarkerFaceAlpha', 0.2); hold on
yline(1, 'k--');
xlabel('H_{s,swell} (m)');
ylabel('Low-swell ratio (PUV/MOP)');
title('Amplification ratio vs wave height');
ylim([0 3]); grid on;

% Binned trend
hsEdges = 0.2:0.1:1.6;
hsCenters = hsEdges(1:end-1) + 0.05;
binnedRatio = NaN(length(hsCenters), 1);
for j = 1:length(hsCenters)
    mask = seg_Hs_swell_mop >= hsEdges(j) & seg_Hs_swell_mop < hsEdges(j+1) & goodTest2;
    if sum(mask) > 5
        binnedRatio(j) = mean(seg_ratio_lowSW(mask));
    end
end
goodBin = ~isnan(binnedRatio);
plot(hsCenters(goodBin), binnedRatio(goodBin), 'r-o', 'LineWidth', 2, ...
    'MarkerFaceColor', 'r');
legend('Hourly', 'Binned mean', 'Location', 'northeast');

sgtitle(sprintf('%s — %s: Bound wave scaling tests (h=%.1fm)', ...
    L2.deploymentName, L2.label, h_puv), 'FontWeight', 'bold');

%% Figure 2: Mean spectral excess (PUV - MOP) in physical units
fig2 = figure('Position', [100 100 800 500], 'Name', 'Mean spectral excess');

% Compute mean PUV and MOP spectra
meanPUV = mean(L2.S_eta(:, validIdx), 2, 'omitnan');

% Mean shoaled MOP interpolated to PUV grid
meanMOP = zeros(length(f_puv), 1);
nMopUsed = 0;
for i = 1:nMatched
    mi = matchedMopIdx(i);
    s_mop = interp1(freq_mop, spec_shoaled(mi,:)', f_puv, 'linear', 0);
    meanMOP = meanMOP + s_mop;
    nMopUsed = nMopUsed + 1;
end
meanMOP = meanMOP / max(nMopUsed, 1);

subplot(2,1,1)
plot(f_puv, meanPUV, 'b-', 'LineWidth', 2, 'DisplayName', sprintf('PUV (%.1fm)', h_puv));
hold on
plot(f_puv, meanMOP, 'r-', 'LineWidth', 2, 'DisplayName', sprintf('MOP shoaled (%.1fm)', h_puv));
xlabel('Frequency (Hz)');
ylabel('S_\eta (m^2/Hz)');
title('Mean spectra');
legend('Location', 'northeast');
xlim([0.01 0.3]); grid on;

subplot(2,1,2)
% Normalize to percent of total energy, then difference
puvPct = meanPUV / trapz(f_puv, meanPUV) * 100;
mopPct = meanMOP / trapz(f_puv, meanMOP) * 100;
excessPct = puvPct - mopPct;
area(f_puv, max(excessPct, 0), 'FaceColor', [0.3 0.6 1.0], 'FaceAlpha', 0.5, ...
    'EdgeColor', 'b', 'DisplayName', 'PUV excess'); hold on
area(f_puv, min(excessPct, 0), 'FaceColor', [1.0 0.5 0.3], 'FaceAlpha', 0.5, ...
    'EdgeColor', 'r', 'DisplayName', 'MOP excess');
yline(0, 'k-');
xlabel('Frequency (Hz)');
ylabel('\Delta energy (% / Hz)');
title('Normalized spectral difference (PUV − MOP)');
legend('Location', 'northeast');
xlim([0.01 0.3]); grid on;

sgtitle(sprintf('%s — %s: Spectral excess structure', ...
    L2.deploymentName, L2.label), 'FontWeight', 'bold');

%% Save
diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end

exportgraphics(fig1, fullfile(diagDir, sprintf('%s_%s_bound_wave_scaling.png', ...
    L2.deploymentName, L2.label)), 'Resolution', 200);
exportgraphics(fig2, fullfile(diagDir, sprintf('%s_%s_spectral_excess.png', ...
    L2.deploymentName, L2.label)), 'Resolution', 200);
fprintf('\n  Figures saved to %s\n', diagDir);

%% Store results
results.label = L2.label;
results.deployment = L2.deploymentName;
results.h_puv = h_puv;
results.seg_Hs_swell_puv = seg_Hs_swell_puv;
results.seg_Hs_swell_mop = seg_Hs_swell_mop;
results.seg_E_IG_puv = seg_E_IG_puv;
results.seg_E_IG_mop = seg_E_IG_mop;
results.seg_ratio_lowSW = seg_ratio_lowSW;
results.seg_excess_lowSW = seg_excess_lowSW;
results.seg_ratio_IG = seg_ratio_IG;
results.meanPUV = meanPUV;
results.meanMOP = meanMOP;
results.f = f_puv;

end
