function results = compare_directional_spread(L2, toolboxPath)
% COMPARE_DIRECTIONAL_SPREAD  Compare PUV and MOP directional spreading.
%
%   results = compare_directional_spread(L2)
%   results = compare_directional_spread(L2, toolboxPath)
%
%   Computes the first-harmonic directional spread from PUV a1/b1
%   coefficients and MOP a1/b1, then examines:
%     1. Mean directional spread vs frequency (PUV vs MOP)
%     2. Spread narrowing from 10m to PUV depth
%     3. Relationship between spread narrowing and spectral amplification
%
%   The hypothesis: if directional narrowing during shoaling concentrates
%   energy into a narrower angular window, the 1D frequency spectrum
%   (energy density per Hz) increases even without changes in total energy.
%   MOP may underestimate this narrowing at shallow depths.
%
%   COORDINATE NOTES
%     PUV a1/b1 are computed from cross-spectra of pressure with velocity
%     components that have been rotated to shore-normal coordinates (+x
%     onshore, +y alongshore north). The rotation is orthogonal, so
%     r1 = sqrt(a1^2 + b1^2) and the spread sigma1 = sqrt(2*(1-r1))
%     are invariant to rotation and can be compared directly with MOP.
%     However, the PUV *direction* from atan2(b1,a1) is relative to
%     shore-normal, NOT compass bearing. To recover compass direction
%     from PUV, add L2.shorenormal to the atan2 result. The mean
%     direction comparison (Figure 3) accounts for this offset.
% Author: Holden Leslie-Bole, 2026

if nargin < 2 || isempty(toolboxPath)
    toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
end
if ~exist('read_MOPline2', 'file')
    addpath(toolboxPath);
end

g = 9.81;

%% Load MOP data
if isfield(L2, 'mopStation') && ~isempty(L2.mopStation)
    mopStation = L2.mopStation;
else
    mopNum = regexp(L2.label, 'MOP(\d+)', 'tokens', 'once');
    if isempty(mopNum)
        error('compare_directional_spread:noStation', ...
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
freq_mop = double(MOP.frequency(:));
nFreq_mop = length(freq_mop);
nTimes_mop = length(MOP.time);

fprintf('  MOP depth: %.1f m, PUV depth: %.1f m\n', h_mop, h_puv);

%% Compute MOP directional spread at 10m depth
% MOP a1, b1 are [nTimes x nFreq]
% Directional spread: sigma1 = sqrt(2*(1 - r1)) where r1 = sqrt(a1^2 + b1^2)
mop_a1 = double(MOP.a1);  % [nTimes x nFreq]
mop_b1 = double(MOP.b1);

mop_r1 = sqrt(mop_a1.^2 + mop_b1.^2);
mop_spread_rad = sqrt(2 * max(1 - mop_r1, 0));  % radians
mop_spread_deg = rad2deg(mop_spread_rad);  % degrees

% Mean spread across all times (per frequency)
mop_mean_spread = mean(mop_spread_deg, 1, 'omitnan');  % [1 x nFreq]

% Mean direction from MOP
mop_meandir = atan2d(mean(mop_b1, 1, 'omitnan'), mean(mop_a1, 1, 'omitnan'));

%% Compute PUV directional spread
% L2.a1 and L2.b1 are [nf x nSeg]
f_puv = L2.f;
nf_puv = length(f_puv);

puv_a1 = L2.a1(:, validIdx);  % [nf x nValid]
puv_b1 = L2.b1(:, validIdx);

puv_r1 = sqrt(puv_a1.^2 + puv_b1.^2);
puv_spread_rad = sqrt(2 * max(1 - puv_r1, 0));
puv_spread_deg = rad2deg(puv_spread_rad);

% Mean spread across all valid segments (per frequency)
puv_mean_spread = mean(puv_spread_deg, 2, 'omitnan');  % [nf x 1]

% Mean direction from PUV
puv_meandir = atan2d(mean(puv_b1, 2, 'omitnan'), mean(puv_a1, 2, 'omitnan'));

%% Match PUV segments to MOP hours for per-hour comparison
t_mop = MOP.time;
L2_time = L2.time;
if isempty(L2_time.TimeZone) && ~isempty(t_mop.TimeZone)
    L2_time.TimeZone = t_mop.TimeZone;
end

validTimes = find(validIdx);
matched_puv = NaN(nTimes_mop, 1);
for t = 1:nTimes_mop
    dt = abs(L2_time(validTimes) - t_mop(t));
    [minDt, iMin] = min(dt);
    if minDt < minutes(30)
        matched_puv(t) = validTimes(iMin);
    end
end
hasMatch = ~isnan(matched_puv);
matchedMopIdx = find(hasMatch);
fprintf('  %d matched hours\n', sum(hasMatch));

%% Compute per-hour energy-weighted spread and spectral ratio
fSS = L2.params.fSS;
iSS_puv = f_puv >= fSS(1) & f_puv <= fSS(2);
iSS_mop = freq_mop >= fSS(1) & freq_mop <= fSS(2);

% Frequency band for "swell peak" spread comparison
iSwellPeak_puv = f_puv >= 0.05 & f_puv <= 0.10;
iSwellPeak_mop = freq_mop >= 0.05 & freq_mop <= 0.10;

hourly_puv_spread = NaN(length(matchedMopIdx), 1);
hourly_mop_spread = NaN(length(matchedMopIdx), 1);
hourly_spread_ratio = NaN(length(matchedMopIdx), 1);
hourly_Hs_ratio = NaN(length(matchedMopIdx), 1);

% Also shoal MOP for Hs ratio
omega_mop = 2*pi*freq_mop;
k_mop_h = get_wavenumber(omega_mop, h_mop);
k_puv_h = get_wavenumber(omega_mop, h_puv);
cg_mop_h = get_cg(k_mop_h, h_mop);
cg_puv_h = get_cg(k_puv_h, h_puv);
shoalFactor = cg_mop_h(:) ./ cg_puv_h(:);
spec_shoaled = MOP.spec1D .* shoalFactor';
fbw = double(MOP.fbw(:));

for i = 1:length(matchedMopIdx)
    mi = matchedMopIdx(i);
    pi_idx = matched_puv(mi);

    % PUV energy-weighted spread at swell peak
    puv_S = L2.S_eta(iSwellPeak_puv, pi_idx);
    puv_sp = puv_spread_deg(iSwellPeak_puv, validTimes == pi_idx);
    if isempty(puv_sp), continue; end
    E_sum = sum(puv_S(puv_S > 0));
    if E_sum > 0
        hourly_puv_spread(i) = sum(puv_sp(puv_S > 0) .* puv_S(puv_S > 0)) / E_sum;
    end

    % MOP energy-weighted spread at swell peak (at 10m)
    mop_S = MOP.spec1D(mi, iSS_mop);
    mop_sp = mop_spread_deg(mi, iSwellPeak_mop);
    mop_Speak = MOP.spec1D(mi, iSwellPeak_mop);
    E_sum_mop = sum(mop_Speak(mop_Speak > 0));
    if E_sum_mop > 0
        hourly_mop_spread(i) = sum(mop_sp(mop_Speak > 0) .* mop_Speak(mop_Speak > 0)) / E_sum_mop;
    end

    % Spread narrowing ratio (MOP/PUV > 1 means PUV is narrower)
    if hourly_puv_spread(i) > 0
        hourly_spread_ratio(i) = hourly_mop_spread(i) / hourly_puv_spread(i);
    end

    % Hs ratio (PUV/MOP)
    Hs_puv = L2.Hs(pi_idx);
    m0_mop = sum(spec_shoaled(mi, iSS_mop) .* fbw(iSS_mop)');
    Hs_mop = 4 * sqrt(max(m0_mop, 0));
    if Hs_mop > 0
        hourly_Hs_ratio(i) = Hs_puv / Hs_mop;
    end
end

%% Print results
fprintf('\n=== Directional Spread Comparison: %s (%s) ===\n', L2.label, L2.deploymentName);
fprintf('  MOP depth: %.1f m | PUV depth: %.1f m\n\n', h_mop, h_puv);

fprintf('  Energy-weighted swell-peak spread (0.05-0.10 Hz):\n');
fprintf('    MOP (10m):  median = %.1f deg,  mean = %.1f deg\n', ...
    median(hourly_mop_spread, 'omitnan'), mean(hourly_mop_spread, 'omitnan'));
fprintf('    PUV (%.1fm): median = %.1f deg,  mean = %.1f deg\n', ...
    h_puv, median(hourly_puv_spread, 'omitnan'), mean(hourly_puv_spread, 'omitnan'));

good = ~isnan(hourly_spread_ratio) & ~isnan(hourly_Hs_ratio);
if sum(good) > 20
    fprintf('    Spread narrowing (MOP/PUV): median = %.3f\n', ...
        median(hourly_spread_ratio(good)));
    fprintf('    → PUV spread is %.1f%% %s than MOP\n', ...
        abs(1 - median(hourly_spread_ratio(good))) * 100, ...
        char((median(hourly_spread_ratio(good)) > 1) * 'narrower' + ...
             (median(hourly_spread_ratio(good)) <= 1) * 'wider   '));

    R = corrcoef(hourly_spread_ratio(good), hourly_Hs_ratio(good));
    fprintf('\n  Spread narrowing vs Hs amplification:\n');
    fprintf('    R = %.3f, R^2 = %.3f (N = %d)\n', R(1,2), R(1,2)^2, sum(good));
    if R(1,2) > 0.1
        fprintf('    → Positive correlation: hours with narrower PUV spread have higher Hs ratio\n');
    elseif R(1,2) < -0.1
        fprintf('    → Negative correlation: unexpected\n');
    else
        fprintf('    → No significant correlation\n');
    end
end

% Per-frequency spread and direction comparison
% Convert PUV direction to compass bearing for display
puv_compass_dir_all = mod(L2.shorenormal + 180 + puv_meandir, 360);

fprintf('\n  Mean directional spread and direction by frequency:\n');
fprintf('  %-8s  %-8s  %-8s  %-10s  %-10s  %-10s\n', ...
    'f (Hz)', 'MOP sp', 'PUV sp', 'Narrowing', 'MOP dir', 'PUV dir');
fprintf('  %s\n', repmat('-', 1, 62));
printFreqs = [0.05, 0.06, 0.07, 0.08, 0.10, 0.12, 0.15, 0.20, 0.25];
for pf = printFreqs
    [~, iMop] = min(abs(freq_mop - pf));
    [~, iPuv] = min(abs(f_puv - pf));
    mopSpread = mop_mean_spread(iMop);
    puvSpread = puv_mean_spread(iPuv);
    narrowing = mopSpread / puvSpread;
    mopDir = mod(mop_meandir(iMop), 360);
    puvDir = puv_compass_dir_all(iPuv);
    fprintf('  %-8.3f  %-8.1f  %-8.1f  %-10.3f  %-10.1f  %-10.1f\n', ...
        pf, mopSpread, puvSpread, narrowing, mopDir, puvDir);
end

%% ======================== FIGURES ========================

%% Figure 1: Mean spread vs frequency
fig1 = figure('Position', [100 100 900 500], 'Name', 'Spread vs frequency');

subplot(2,1,1)
plot(freq_mop, mop_mean_spread, 'r-', 'LineWidth', 2, 'DisplayName', ...
    sprintf('MOP (%.0fm)', h_mop)); hold on
plot(f_puv(iSS_puv), puv_mean_spread(iSS_puv), 'b-', 'LineWidth', 2, ...
    'DisplayName', sprintf('PUV (%.1fm)', h_puv));
xlabel('Frequency (Hz)');
ylabel('Directional spread (deg)');
title(sprintf('%s — %s: Mean directional spread', L2.deploymentName, L2.label));
legend('Location', 'northwest');
xlim([0.04 0.25]); grid on;

subplot(2,1,2)
% Narrowing ratio vs frequency
narrowing_interp = interp1(freq_mop, mop_mean_spread, f_puv, 'linear', NaN);
ratio_spread = narrowing_interp(:) ./ puv_mean_spread;
plot(f_puv(iSS_puv), ratio_spread(iSS_puv), 'k-', 'LineWidth', 2); hold on
yline(1, 'k--');
xlabel('Frequency (Hz)');
ylabel('Spread ratio (MOP / PUV)');
title('Directional narrowing (>1 = PUV narrower than MOP)');
xlim([0.04 0.25]); grid on;

%% Figure 2: Spread narrowing vs Hs amplification (scatter)
fig2 = figure('Position', [100 100 600 500], 'Name', 'Narrowing vs amplification');

good = ~isnan(hourly_spread_ratio) & ~isnan(hourly_Hs_ratio) & ...
       hourly_spread_ratio > 0.3 & hourly_spread_ratio < 3;
scatter(hourly_spread_ratio(good), hourly_Hs_ratio(good), 8, 'filled', ...
    'MarkerFaceAlpha', 0.2);
hold on;

% Binned trend
spreadEdges = 0.5:0.1:2.5;
spreadCenters = spreadEdges(1:end-1) + 0.05;
binnedHsRatio = NaN(length(spreadCenters), 1);
for i = 1:length(spreadCenters)
    mask = hourly_spread_ratio >= spreadEdges(i) & hourly_spread_ratio < spreadEdges(i+1) & ...
           ~isnan(hourly_Hs_ratio);
    if sum(mask) > 5
        binnedHsRatio(i) = mean(hourly_Hs_ratio(mask));
    end
end
goodBin = ~isnan(binnedHsRatio);
plot(spreadCenters(goodBin), binnedHsRatio(goodBin), 'r-o', 'LineWidth', 2, ...
    'MarkerFaceColor', 'r', 'MarkerSize', 6);

xline(1, 'k--'); yline(1, 'k--');
xlabel('Spread narrowing ratio (MOP_{10m} / PUV)');
ylabel('Hs ratio (PUV / MOP_{shoaled})');
title(sprintf('%s — %s: Does directional narrowing explain Hs amplification?', ...
    L2.deploymentName, L2.label));
legend('Hourly', 'Binned mean', 'Location', 'northwest');
grid on;

%% Figure 3: Mean direction comparison
% Convert PUV direction from shore-normal frame to compass bearing.
% PUV a1/b1 are in shore-normal coords (+x onshore, +y alongshore north).
% atan2(b1,a1) gives angle relative to onshore direction.
% Compass bearing = shorenormal + 180 + atan2(b1,a1), wrapped to [0,360).
% The +180 accounts for "coming from" convention.
puv_compass_dir = mod(L2.shorenormal + 180 + puv_meandir, 360);

fig3 = figure('Position', [100 100 900 400], 'Name', 'Mean direction');

plot(freq_mop, mod(mop_meandir, 360), 'r-', 'LineWidth', 2, 'DisplayName', ...
    sprintf('MOP (%.0fm)', h_mop)); hold on
plot(f_puv(iSS_puv), puv_compass_dir(iSS_puv), 'b-', 'LineWidth', 2, ...
    'DisplayName', sprintf('PUV (%.1fm)', h_puv));
yline(mod(L2.shorenormal + 180, 360), 'k:', 'LineWidth', 1, 'DisplayName', ...
    sprintf('Shore normal (%.0f°)', mod(L2.shorenormal + 180, 360)));
xlabel('Frequency (Hz)');
ylabel('Mean direction (deg compass, coming from)');
title(sprintf('%s — %s: Mean wave direction', L2.deploymentName, L2.label));
legend('Location', 'best');
xlim([0.04 0.25]); ylim([200 320]); grid on;

%% Save
diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end

exportgraphics(fig1, fullfile(diagDir, sprintf('%s_%s_spread_comparison.png', ...
    L2.deploymentName, L2.label)), 'Resolution', 200);
exportgraphics(fig2, fullfile(diagDir, sprintf('%s_%s_narrowing_vs_amplification.png', ...
    L2.deploymentName, L2.label)), 'Resolution', 200);
exportgraphics(fig3, fullfile(diagDir, sprintf('%s_%s_mean_direction.png', ...
    L2.deploymentName, L2.label)), 'Resolution', 200);
fprintf('\n  Figures saved to %s\n', diagDir);

%% Store results
results.label = L2.label;
results.deployment = L2.deploymentName;
results.h_mop = h_mop;
results.h_puv = h_puv;
results.freq_mop = freq_mop;
results.f_puv = f_puv;
results.mop_mean_spread = mop_mean_spread;
results.puv_mean_spread = puv_mean_spread;
results.hourly_puv_spread = hourly_puv_spread;
results.hourly_mop_spread = hourly_mop_spread;
results.hourly_spread_ratio = hourly_spread_ratio;
results.hourly_Hs_ratio = hourly_Hs_ratio;

end
