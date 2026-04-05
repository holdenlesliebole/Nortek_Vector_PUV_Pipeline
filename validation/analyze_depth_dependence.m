function results = analyze_depth_dependence(deployment_name, toolboxPath)
% ANALYZE_DEPTH_DEPENDENCE  Nonlinear shoaling amplification vs depth.
%
%   results = analyze_depth_dependence(deployment_name)
%   results = analyze_depth_dependence(deployment_name, toolboxPath)
%
%   For each instrument in a deployment, computes the frequency-dependent
%   spectral ratio (PUV / shoaled MOP) and examines how nonlinear
%   amplification varies with water depth.
%
%   Produces:
%     1. Spectral ratio vs frequency for all instruments (overlaid)
%     2. Band-averaged ratio vs depth (low/mid/high swell)
%     3. Per-segment ratio vs depth (capturing tidal depth variation)
%     4. Ursell number analysis — nonlinear parameter vs amplification
%
%   INPUTS
%     deployment_name - e.g. 'TBR23'
%     toolboxPath     - path to toolbox/ with read_MOPline2.m

if nargin < 2 || isempty(toolboxPath)
    toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
end
if ~exist('read_MOPline2', 'file')
    addpath(toolboxPath);
end

startup_puv
g = 9.81;
rho = 1025;

%% Load config and L2 data for all instruments
registry = deployment_registry();
configFn = registry(deployment_name);
cfg = configFn();

l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
nInstr = numel(cfg.instruments);

fprintf('\n============================================================\n');
fprintf(' Depth Dependence of Nonlinear Shoaling: %s\n', deployment_name);
fprintf('============================================================\n\n');

% Collect data from all instruments
allL2 = cell(nInstr, 1);
allMOP = cell(nInstr, 1);
allShoaled = cell(nInstr, 1);
instrDepths = NaN(nInstr, 1);
instrLabels = cell(nInstr, 1);
instrColors = lines(nInstr);

for k = 1:nInstr
    instr = cfg.instruments(k);
    instrLabels{k} = instr.label;
    l2File = fullfile(l2Dir, [instr.label '_L2.mat']);

    if ~isfile(l2File)
        fprintf('  [%d/%d] %s — no L2 file, skipping\n', k, nInstr, instr.label);
        continue
    end

    fprintf('  [%d/%d] Loading %s...\n', k, nInstr, instr.label);
    loaded = load(l2File, 'L2');
    L2 = loaded.L2;
    allL2{k} = L2;

    validIdx = L2.segValid;
    instrDepths(k) = median(L2.depth(validIdx), 'omitnan');

    % Load MOP data
    if isfield(L2, 'mopStation') && ~isempty(L2.mopStation)
        mopStation = L2.mopStation;
    else
        mopNum = regexp(L2.label, 'MOP(\d+)', 'tokens', 'once');
        if isempty(mopNum)
            error('analyze_depth_dependence:noStation', ...
                'Cannot determine MOP station for label: %s', L2.label);
        end
        mopStation = ['D0' mopNum{1}];
    end

    tStart = min(L2.time(validIdx));
    tEnd = max(L2.time(validIdx));
    if isempty(tStart.TimeZone), tStart.TimeZone = 'UTC'; tEnd.TimeZone = 'UTC'; end

    MOP = read_MOPline2(mopStation, tStart, tEnd);
    allMOP{k} = MOP;

    % Shoal MOP to this instrument's median depth
    freq_mop = double(MOP.frequency(:));
    omega_mop = 2*pi*freq_mop;
    h_mop = double(MOP.depth);
    h_puv = instrDepths(k);

    k_mop = get_wavenumber(omega_mop, h_mop);
    k_puv = get_wavenumber(omega_mop, h_puv);
    cg_mop = get_cg(k_mop, h_mop);
    cg_puv = get_cg(k_puv, h_puv);
    shoalFactor = cg_mop(:) ./ cg_puv(:);

    allShoaled{k} = MOP.spec1D .* shoalFactor';
end

%% Compute spectral ratios for each instrument
f_puv = allL2{1}.f;  % same freq grid for all instruments
nf = length(f_puv);
fSS = allL2{1}.params.fSS;
iSS = f_puv >= fSS(1) & f_puv <= fSS(2);

% Band definitions
iLowSwell  = f_puv >= 0.04 & f_puv < 0.08;
iMidSwell  = f_puv >= 0.08 & f_puv < 0.14;
iHighSwell = f_puv >= 0.14 & f_puv <= 0.25;
iIG        = f_puv >= 0.004 & f_puv < 0.04;

bandNames = {'IG (0.004-0.04)', 'Low swell (0.04-0.08)', ...
             'Mid swell (0.08-0.14)', 'High swell (0.14-0.25)'};
bandMasks = {iIG, iLowSwell, iMidSwell, iHighSwell};
nBands = 4;

% Store results
meanRatios = NaN(nf, nInstr);
bandRatios = NaN(nBands, nInstr);

% Per-segment data for scatter analysis
segDepth_all = [];
segRatioLow_all = [];
segRatioMid_all = [];
segHs_all = [];
segUrsell_all = [];
segInstr_all = [];

for k = 1:nInstr
    if isempty(allL2{k}), continue; end
    L2 = allL2{k};
    MOP = allMOP{k};
    spec_shoaled = allShoaled{k};
    freq_mop = double(MOP.frequency(:));
    fbw = double(MOP.fbw(:));

    validIdx = L2.segValid;
    validTimes = find(validIdx);

    % Match PUV to MOP times
    t_mop = MOP.time;
    L2_time = L2.time;
    if isempty(L2_time.TimeZone) && ~isempty(t_mop.TimeZone)
        L2_time.TimeZone = t_mop.TimeZone;
    end

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

    % Accumulate spectral ratios
    ratioSum = zeros(nf, 1);
    ratioCount = zeros(nf, 1);

    for t = 1:length(matchedMopIdx)
        mi = matchedMopIdx(t);
        pi_idx = matched_puv(mi);

        s_puv = L2.S_eta(:, pi_idx);
        s_mop_interp = interp1(freq_mop, spec_shoaled(mi,:)', f_puv, 'linear', 0);

        goodBins = s_puv > 0 & s_mop_interp > 0 & iSS;
        ratio = s_puv ./ s_mop_interp;
        ratioSum(goodBins) = ratioSum(goodBins) + ratio(goodBins);
        ratioCount(goodBins) = ratioCount(goodBins) + 1;

        % Per-segment statistics
        segH = L2.depth(pi_idx);
        segHsVal = L2.Hs(pi_idx);

        % Low-swell ratio for this segment
        lowBins = s_puv > 0 & s_mop_interp > 0 & iLowSwell;
        midBins = s_puv > 0 & s_mop_interp > 0 & iMidSwell;

        if sum(lowBins) > 2 && sum(midBins) > 2
            segRatioLow = mean(ratio(lowBins));
            segRatioMid = mean(ratio(midBins));

            % Ursell number: Ur = (Hs * L^2) / h^3
            % Use peak wavelength from MOP
            Tp = L2.Tp(pi_idx);
            if ~isnan(Tp) && Tp > 0
                omega_p = 2*pi / Tp;
                k_p = get_wavenumber(omega_p, segH);
                Lp = 2*pi / k_p;
                Ur = segHsVal * Lp^2 / segH^3;
            else
                Ur = NaN;
            end

            segDepth_all(end+1,1) = segH;
            segRatioLow_all(end+1,1) = segRatioLow;
            segRatioMid_all(end+1,1) = segRatioMid;
            segHs_all(end+1,1) = segHsVal;
            segUrsell_all(end+1,1) = Ur;
            segInstr_all(end+1,1) = k;
        end
    end

    mRatio = ratioSum ./ max(ratioCount, 1);
    mRatio(ratioCount < 10) = NaN;
    meanRatios(:, k) = mRatio;

    % Band-averaged ratios
    for b = 1:nBands
        mask = bandMasks{b} & ~isnan(mRatio);
        if any(mask)
            bandRatios(b, k) = mean(mRatio(mask));
        end
    end
end

%% Print results table
fprintf('\n=== Band-Averaged Spectral Ratios vs Depth ===\n');
fprintf('  %-14s  %6s  %8s  %8s  %8s  %8s\n', ...
    'Instrument', 'Depth', 'IG', 'Low SW', 'Mid SW', 'High SW');
fprintf('  %s\n', repmat('-', 1, 60));
for k = 1:nInstr
    if isnan(instrDepths(k)), continue; end
    fprintf('  %-14s  %5.1fm  %8.4f  %8.4f  %8.4f  %8.4f\n', ...
        instrLabels{k}, instrDepths(k), ...
        bandRatios(1,k), bandRatios(2,k), bandRatios(3,k), bandRatios(4,k));
end

% Ursell number statistics
fprintf('\n=== Ursell Number Statistics ===\n');
for k = 1:nInstr
    mask = segInstr_all == k;
    if sum(mask) == 0, continue; end
    fprintf('  %-14s  h=%.1fm  Ur: median=%.1f  mean=%.1f  range=[%.1f, %.1f]\n', ...
        instrLabels{k}, instrDepths(k), ...
        median(segUrsell_all(mask), 'omitnan'), ...
        mean(segUrsell_all(mask), 'omitnan'), ...
        min(segUrsell_all(mask)), max(segUrsell_all(mask)));
end

% Correlation between Ursell number and low-swell ratio
goodUr = ~isnan(segUrsell_all) & ~isnan(segRatioLow_all) & segUrsell_all < 200;
if sum(goodUr) > 20
    R = corrcoef(segUrsell_all(goodUr), segRatioLow_all(goodUr));
    fprintf('\n  Ursell vs low-swell ratio: R=%.3f, R^2=%.3f (N=%d)\n', ...
        R(1,2), R(1,2)^2, sum(goodUr));
end

%% ======================== FIGURES ========================

%% Figure 1: Spectral ratio vs frequency for all instruments
fig1 = figure('Position', [50 50 900 500], 'Name', 'Spectral ratio vs frequency');

for k = 1:nInstr
    if all(isnan(meanRatios(:,k))), continue; end
    plot(f_puv, meanRatios(:,k), '-', 'LineWidth', 2, 'Color', instrColors(k,:), ...
        'DisplayName', sprintf('%s (%.1fm)', instrLabels{k}, instrDepths(k)));
    hold on;
end
yline(1, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
xlabel('Frequency (Hz)');
ylabel('S_{PUV} / S_{MOP,shoaled}');
title(sprintf('%s: Mean spectral ratio by instrument depth', deployment_name));
legend('Location', 'northeast');
xlim([0.03 0.28]); grid on;

%% Figure 2: Band-averaged ratio vs depth
fig2 = figure('Position', [50 50 700 500], 'Name', 'Band ratio vs depth');

validInstr = ~isnan(instrDepths);
depthsValid = instrDepths(validInstr);
markers = {'o', 's', 'd', '^'};
bandColors = [0.2 0.6 1.0; 0.1 0.4 0.8; 0.8 0.3 0.1; 0.9 0.5 0.2];

for b = 1:nBands
    scatter(depthsValid, bandRatios(b, validInstr), 100, bandColors(b,:), ...
        'filled', markers{b}, 'DisplayName', bandNames{b});
    hold on;

    % Fit line if enough points
    bVals = bandRatios(b, validInstr)';
    goodFit = ~isnan(bVals);
    if sum(goodFit) >= 3
        p = polyfit(depthsValid(goodFit), bVals(goodFit), 1);
        hLine = sort(depthsValid(goodFit));
        plot(hLine, polyval(p, hLine), '-', 'Color', bandColors(b,:), ...
            'LineWidth', 1.5, 'HandleVisibility', 'off');
    end
end

yline(1, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
xlabel('Total water depth H (m)');
ylabel('Mean spectral ratio (PUV / MOP)');
title(sprintf('%s: Nonlinear amplification vs depth', deployment_name));
legend('Location', 'northeast');
grid on;

% Add instrument labels
for k = 1:nInstr
    if ~validInstr(k), continue; end
    text(instrDepths(k), bandRatios(2,k) + 0.015, instrLabels{k}, ...
        'FontSize', 7, 'HorizontalAlignment', 'center');
end

%% Figure 3: Per-segment low-swell ratio vs depth (tidal variation)
fig3 = figure('Position', [50 50 1200 500], 'Name', 'Segment ratio vs depth');

subplot(1,2,1)
for k = 1:nInstr
    mask = segInstr_all == k;
    if sum(mask) == 0, continue; end
    scatter(segDepth_all(mask), segRatioLow_all(mask), 4, instrColors(k,:), ...
        'filled', 'MarkerFaceAlpha', 0.15, 'DisplayName', instrLabels{k});
    hold on;
end
yline(1, 'k--', 'HandleVisibility', 'off');
xlabel('Segment depth H (m)');
ylabel('Low-swell ratio (0.04–0.08 Hz)');
title('Per-segment: depth includes tidal variation');
legend('Location', 'northeast');
ylim([0 3]); grid on;

% Bin by depth and plot mean trend
subplot(1,2,2)
depthEdges = 4:0.5:10;
depthCenters = depthEdges(1:end-1) + 0.25;
binnedRatio = NaN(length(depthCenters), 1);
binnedStd = NaN(length(depthCenters), 1);
binnedN = zeros(length(depthCenters), 1);

for i = 1:length(depthCenters)
    mask = segDepth_all >= depthEdges(i) & segDepth_all < depthEdges(i+1) & ...
           ~isnan(segRatioLow_all);
    if sum(mask) > 5
        binnedRatio(i) = mean(segRatioLow_all(mask));
        binnedStd(i) = std(segRatioLow_all(mask));
        binnedN(i) = sum(mask);
    end
end

goodBins = ~isnan(binnedRatio);
errorbar(depthCenters(goodBins), binnedRatio(goodBins), ...
    binnedStd(goodBins) ./ sqrt(binnedN(goodBins)), ...
    'ko-', 'LineWidth', 2, 'MarkerFaceColor', 'k', 'MarkerSize', 8);
hold on;
yline(1, 'k--');
xlabel('Depth bin center (m)');
ylabel('Mean low-swell ratio');
title('Depth-binned mean (0.5m bins, \pm SE)');
grid on;

% Annotate with sample counts
for i = find(goodBins)'
    text(depthCenters(i), binnedRatio(i) + 0.03, sprintf('n=%d', binnedN(i)), ...
        'FontSize', 7, 'HorizontalAlignment', 'center');
end

sgtitle(sprintf('%s: Low-swell amplification vs depth (per-segment)', deployment_name), ...
    'FontWeight', 'bold');

%% Figure 4: Ursell number vs low-swell ratio
fig4 = figure('Position', [50 50 700 500], 'Name', 'Ursell vs ratio');

for k = 1:nInstr
    mask = segInstr_all == k & ~isnan(segUrsell_all) & segUrsell_all < 200;
    if sum(mask) == 0, continue; end
    scatter(segUrsell_all(mask), segRatioLow_all(mask), 6, instrColors(k,:), ...
        'filled', 'MarkerFaceAlpha', 0.15, 'DisplayName', instrLabels{k});
    hold on;
end
yline(1, 'k--', 'HandleVisibility', 'off');
xlabel('Ursell number  Ur = H_s L_p^2 / h^3');
ylabel('Low-swell spectral ratio');
title(sprintf('%s: Wave nonlinearity vs spectral amplification', deployment_name));
legend('Location', 'northeast');
xlim([0 150]); ylim([0 3]); grid on;

% Bin by Ursell and show trend
urEdges = 0:10:150;
urCenters = urEdges(1:end-1) + 5;
urRatio = NaN(length(urCenters), 1);

for i = 1:length(urCenters)
    mask = segUrsell_all >= urEdges(i) & segUrsell_all < urEdges(i+1) & ...
           ~isnan(segRatioLow_all);
    if sum(mask) > 10
        urRatio(i) = mean(segRatioLow_all(mask));
    end
end
goodUr = ~isnan(urRatio);
plot(urCenters(goodUr), urRatio(goodUr), 'k-', 'LineWidth', 3, ...
    'DisplayName', 'Binned mean');

%% Save all figures
diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end

exportgraphics(fig1, fullfile(diagDir, sprintf('%s_spectral_ratio_all_instruments.png', deployment_name)), 'Resolution', 200);
exportgraphics(fig2, fullfile(diagDir, sprintf('%s_band_ratio_vs_depth.png', deployment_name)), 'Resolution', 200);
exportgraphics(fig3, fullfile(diagDir, sprintf('%s_segment_ratio_vs_depth.png', deployment_name)), 'Resolution', 200);
exportgraphics(fig4, fullfile(diagDir, sprintf('%s_ursell_vs_ratio.png', deployment_name)), 'Resolution', 200);
fprintf('\n  Figures saved to %s\n', diagDir);

%% Store results
results.deployment = deployment_name;
results.instrLabels = instrLabels;
results.instrDepths = instrDepths;
results.meanRatios = meanRatios;
results.bandRatios = bandRatios;
results.bandNames = bandNames;
results.f = f_puv;
results.segDepth = segDepth_all;
results.segRatioLow = segRatioLow_all;
results.segRatioMid = segRatioMid_all;
results.segHs = segHs_all;
results.segUrsell = segUrsell_all;
results.segInstr = segInstr_all;

end
