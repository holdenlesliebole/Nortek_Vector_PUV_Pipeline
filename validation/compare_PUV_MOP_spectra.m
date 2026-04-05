function compare_PUV_MOP_spectra(L2, nExamples, toolboxPath)
% COMPARE_PUV_MOP_SPECTRA  Overlay PUV and shoaled MOP spectra.
%
%   compare_PUV_MOP_spectra(L2)
%   compare_PUV_MOP_spectra(L2, nExamples, toolboxPath)
%
%   Selects representative segments spanning the Hs range and plots:
%     - PUV surface elevation spectrum (S_eta from pressure correction)
%     - MOP spectrum shoaled to PUV depth
%     - Kp transfer function and fCut overlay
%     - Spectral ratio (PUV/MOP) to isolate frequency-dependent bias
%
%   Also computes average spectral ratio across all matched hours to show
%   the systematic frequency-dependent bias pattern.
%
%   INPUTS
%     L2          - L2 struct from PUV_L2_spectral
%     nExamples   - number of example spectra to plot (default 6)
%     toolboxPath - path to toolbox/ with read_MOPline2.m

if nargin < 2 || isempty(nExamples), nExamples = 6; end
if nargin < 3 || isempty(toolboxPath)
    toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
end
if ~exist('read_MOPline2', 'file')
    addpath(toolboxPath);
end

g = 9.81;
rho = 1025;

%% Load MOP data
if isfield(L2, 'mopStation') && ~isempty(L2.mopStation)
    mopStation = L2.mopStation;
else
    mopNum = regexp(L2.label, 'MOP(\d+)', 'tokens', 'once');
    if isempty(mopNum)
        error('compare_PUV_MOP_spectra:noStation', ...
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
h_puv = median(L2.depth(validIdx));

%% Shoal MOP spectra to PUV depth
freq_mop = double(MOP.frequency(:));
fbw      = double(MOP.fbw(:));
omega_mop = 2*pi*freq_mop;

k_mop_h = get_wavenumber(omega_mop, h_mop);
k_puv_h = get_wavenumber(omega_mop, h_puv);
cg_mop_h = get_cg(k_mop_h, h_mop);
cg_puv_h = get_cg(k_puv_h, h_puv);
shoalFactor = cg_mop_h(:) ./ cg_puv_h(:);

% MOP.spec1D is [nTimes x nFreq]
spec_shoaled = MOP.spec1D .* shoalFactor';

%% Match PUV segments to nearest MOP hour
t_mop = MOP.time;

% Ensure all datetime arrays have consistent timezone
L2_time = L2.time;
if isempty(L2_time.TimeZone) && ~isempty(t_mop.TimeZone)
    L2_time.TimeZone = t_mop.TimeZone;
elseif ~isempty(L2_time.TimeZone) && isempty(t_mop.TimeZone)
    t_mop.TimeZone = L2_time.TimeZone;
end

% For each MOP hour, find the nearest valid PUV segment within 30 min
matched_puv = NaN(length(t_mop), 1);  % index into valid segments
validTimes = find(validIdx);

for t = 1:length(t_mop)
    dt = abs(L2_time(validTimes) - t_mop(t));
    [minDt, iMin] = min(dt);
    if minDt < minutes(30)
        matched_puv(t) = validTimes(iMin);  % index into full L2 arrays
    end
end

hasMatch = ~isnan(matched_puv);
fprintf('  %d/%d MOP hours matched to PUV segments\n', sum(hasMatch), length(t_mop));

%% Compute average spectral ratio across all matched hours
% Interpolate MOP spectrum onto PUV frequency grid for ratio calculation
f_puv = L2.f;
fSS = L2.params.fSS;
iSS_puv = f_puv >= fSS(1) & f_puv <= fSS(2);

% Accumulate ratios
ratioSum = zeros(length(f_puv), 1);
ratioCount = zeros(length(f_puv), 1);

matchedMopIdx = find(hasMatch);
for t = 1:length(matchedMopIdx)
    mi = matchedMopIdx(t);
    pi_idx = matched_puv(mi);

    % PUV spectrum for this segment
    s_puv = L2.S_eta(:, pi_idx);

    % MOP spectrum interpolated to PUV freq grid
    s_mop_interp = interp1(freq_mop, spec_shoaled(mi, :)', f_puv, 'linear', 0);

    % Only compute ratio where both are positive and within SS band
    goodBins = s_puv > 0 & s_mop_interp > 0 & iSS_puv;
    ratio = s_puv ./ s_mop_interp;
    ratioSum(goodBins) = ratioSum(goodBins) + ratio(goodBins);
    ratioCount(goodBins) = ratioCount(goodBins) + 1;
end

meanRatio = ratioSum ./ max(ratioCount, 1);
meanRatio(ratioCount < 10) = NaN;

%% Print spectral ratio diagnostics
fprintf('\n=== Spectral Ratio Diagnostics: %s — %s ===\n', L2.deploymentName, L2.label);
fprintf('  Median PUV depth: %.2f m\n', h_puv);
fprintf('  Sensor height (doffp): %.2f m\n', L2.doffp);
fprintf('  Matched hours: %d / %d MOP records\n', sum(hasMatch), length(t_mop));
fprintf('  Median fCut: %.3f Hz\n', median(L2.fCut(validIdx), 'omitnan'));

fprintf('\n  %-10s  %-12s  %-12s  %-8s\n', 'f (Hz)', 'Mean Ratio', 'Kp', 'N');
fprintf('  %s\n', repmat('-', 1, 48));

% Compute Kp at median depth for the table
omega_tab = 2*pi*f_puv(2:end);
k_tab = get_wavenumber(omega_tab, h_puv);
Kp_tab = [1; cosh(k_tab(:) * L2.doffp) ./ cosh(k_tab(:) * h_puv)];

% Print at selected frequencies
printFreqs = [0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 0.22, 0.25];
for pf = printFreqs
    [~, iClose] = min(abs(f_puv - pf));
    if ~isnan(meanRatio(iClose))
        fprintf('  %-10.3f  %-12.4f  %-12.4f  %-8d\n', ...
            f_puv(iClose), meanRatio(iClose), Kp_tab(iClose), ratioCount(iClose));
    end
end

% Summary stats by band
iLowSwell  = f_puv >= 0.04 & f_puv < 0.08;
iMidSwell  = f_puv >= 0.08 & f_puv < 0.14;
iHighSwell = f_puv >= 0.14 & f_puv <= 0.25;

bandNames = {'Low swell (0.04-0.08)', 'Mid swell (0.08-0.14)', 'High swell (0.14-0.25)'};
bandMasks = {iLowSwell, iMidSwell, iHighSwell};

fprintf('\n  Band-averaged ratios:\n');
for b = 1:3
    mask = bandMasks{b} & ~isnan(meanRatio);
    if any(mask)
        fprintf('    %-26s  ratio = %.4f  (Kp range: %.3f–%.3f)\n', ...
            bandNames{b}, mean(meanRatio(mask)), min(Kp_tab(mask)), max(Kp_tab(mask)));
    end
end

% Overall bias interpretation
allValid = iSS_puv & ~isnan(meanRatio);
if any(allValid)
    overallRatio = mean(meanRatio(allValid));
    fprintf('\n  Overall SS-band mean ratio: %.4f\n', overallRatio);
    if overallRatio > 1.02
        fprintf('  → PUV systematically higher than MOP (%.1f%% excess energy)\n', ...
            (overallRatio - 1) * 100);
    elseif overallRatio < 0.98
        fprintf('  → PUV systematically lower than MOP (%.1f%% deficit)\n', ...
            (1 - overallRatio) * 100);
    else
        fprintf('  → Good agreement (within 2%%)\n');
    end

    % Check if ratio increases toward fCut
    lowRatio = mean(meanRatio(iLowSwell & ~isnan(meanRatio)));
    highRatio = mean(meanRatio(iHighSwell & ~isnan(meanRatio)));
    fprintf('  Low-to-high swell ratio trend: %.4f → %.4f\n', lowRatio, highRatio);
    if highRatio > lowRatio * 1.1
        fprintf('  → Ratio increases toward fCut — pressure correction likely over-amplifying\n');
    elseif highRatio < lowRatio * 0.9
        fprintf('  → Ratio decreases toward fCut — possible energy loss (breaking?)\n');
    else
        fprintf('  → Relatively flat ratio — bias is broadband\n');
    end
end

fprintf('\n');

%% Select example segments spanning the Hs range
Hs_valid = L2.Hs(validIdx);
Hs_sorted = sort(Hs_valid(~isnan(Hs_valid)));
percentiles = linspace(10, 90, nExamples);
targetHs = interp1(linspace(0,100,length(Hs_sorted)), Hs_sorted, percentiles);

exampleIdx = zeros(nExamples, 1);  % indices into full L2 arrays
exampleMop = zeros(nExamples, 1);  % indices into MOP time

for i = 1:nExamples
    % Find a valid PUV segment near this Hs that has a MOP match
    for mi = 1:length(matchedMopIdx)
        mIdx = matchedMopIdx(mi);
        pIdx = matched_puv(mIdx);
        if abs(L2.Hs(pIdx) - targetHs(i)) < 0.1
            exampleIdx(i) = pIdx;
            exampleMop(i) = mIdx;
            break
        end
    end
end

%% Plot individual spectral comparisons
fig1 = figure('Position', [50 50 1600 900], 'Name', ...
    sprintf('Spectral overlay: %s %s', L2.deploymentName, L2.label));

nRows = ceil(nExamples / 3);
nCols = 3;

for i = 1:nExamples
    if exampleIdx(i) == 0, continue; end

    subplot(nRows, nCols, i);

    % PUV spectrum
    s_puv = L2.S_eta(:, exampleIdx(i));
    Kp_seg = L2.Kp(:, exampleIdx(i));
    fCut_seg = L2.fCut(exampleIdx(i));
    depth_seg = L2.depth(exampleIdx(i));

    % MOP shoaled spectrum interpolated to PUV freq grid
    s_mop_interp = interp1(freq_mop, spec_shoaled(exampleMop(i), :)', f_puv, 'linear', 0);

    % Plot
    plot(f_puv, s_puv, 'b-', 'LineWidth', 1.5); hold on
    plot(f_puv, s_mop_interp, 'r-', 'LineWidth', 1.5);
    xline(fCut_seg, 'k:', 'LineWidth', 1);

    xlabel('f (Hz)'); ylabel('S_\eta (m^2/Hz)');
    title(sprintf('Hs=%.2fm, h=%.1fm, fCut=%.2fHz', ...
        L2.Hs(exampleIdx(i)), depth_seg, fCut_seg));
    legend('PUV', 'MOP (shoaled)', 'fCut', 'Location', 'northeast', 'FontSize', 7);
    xlim([0 0.35]); grid on;
end

sgtitle(sprintf('%s — %s: PUV vs shoaled MOP spectra (%.1f m)', ...
    L2.deploymentName, L2.label, h_puv), 'FontWeight', 'bold');

%% Plot mean spectral ratio
fig2 = figure('Position', [100 100 800 500], 'Name', ...
    sprintf('Mean spectral ratio: %s %s', L2.deploymentName, L2.label));

subplot(2,1,1)
plot(f_puv, meanRatio, 'b-', 'LineWidth', 2); hold on
yline(1, 'k--', 'LineWidth', 1);
xlabel('Frequency (Hz)');
ylabel('S_{PUV} / S_{MOP}');
title(sprintf('%s — %s: Mean spectral ratio (PUV / shoaled MOP)', ...
    L2.deploymentName, L2.label));
xlim([fSS(1) fSS(2)]); grid on;
legend('Mean ratio', '1:1', 'Location', 'best');
text(0.05, 0.85, sprintf('N = %d matched hours', sum(hasMatch)), ...
    'Units', 'normalized', 'FontSize', 10);

subplot(2,1,2)
% Show Kp at median depth for context
omega_puv = 2*pi*f_puv(2:end);
k_puv_val = get_wavenumber(omega_puv, h_puv);
Kp_median = [1; cosh(k_puv_val(:) * L2.doffp) ./ cosh(k_puv_val(:) * h_puv)];
plot(f_puv, Kp_median, 'k-', 'LineWidth', 2); hold on
yline(0.1, 'r--', 'KpMin = 0.1');
yline(0.15, 'r:', 'KpMin = 0.15');
yline(0.2, 'r:', 'KpMin = 0.2');
xlabel('Frequency (Hz)');
ylabel('Kp');
title('Pressure transfer function at median depth');
xlim([fSS(1) fSS(2)]); grid on;

%% Save figures
diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end

exportgraphics(fig1, fullfile(diagDir, sprintf('%s_%s_spectral_overlay.png', ...
    L2.deploymentName, L2.label)), 'Resolution', 200);
exportgraphics(fig2, fullfile(diagDir, sprintf('%s_%s_spectral_ratio.png', ...
    L2.deploymentName, L2.label)), 'Resolution', 200);
fprintf('  Figures saved to %s\n', diagDir);

end
