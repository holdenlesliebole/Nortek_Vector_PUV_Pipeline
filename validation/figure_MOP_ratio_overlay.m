function figure_MOP_ratio_overlay(deployment, depthLabels, opts)
% FIGURE_MOP_RATIO_OVERLAY  Single panel comparing PUV/MOP spectral ratio
% for 17-min and 1-hour L2 at each depth, on a shared axis.
%
%   figure_MOP_ratio_overlay('TBR23', {'MOP586_5m','MOP586_7m'})
%
% Loads each L2, loads MOP data once per depth, computes the mean
% spectral ratio in the SS band, and plots all curves together. Bands
% (low/mid/high swell) are shaded; band-averaged ratios are annotated.
%
% Output: outputs/validation/seglen_compare/<deployment>/MOP_ratio_overlay_<labels>.png
% Author: Holden Leslie-Bole, 2026

if nargin < 3, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts, 'L2dir'),       opts.L2dir       = fullfile(pipelineRoot,'outputs','L2'); end
if ~isfield(opts, 'L2hourlyDir'), opts.L2hourlyDir = fullfile(pipelineRoot,'outputs','L2_hourly'); end
if ~isfield(opts, 'figDir'),      opts.figDir      = fullfile(pipelineRoot,'outputs','validation','seglen_compare', deployment); end
if ~isfield(opts, 'toolboxPath'), opts.toolboxPath = fullfile(getenv('HOME'),'Documents','Scripps','Research','toolbox'); end

if ~exist(opts.figDir, 'dir'), mkdir(opts.figDir); end
if ~exist('read_MOPline2', 'file'), addpath(opts.toolboxPath); end

if ischar(depthLabels) || isstring(depthLabels), depthLabels = cellstr(depthLabels); end

% Color per depth, line style per segment length
depthColors = {[0.20 0.45 0.85], [0.85 0.30 0.20]};   % blue=5m, red=7m
% (will swap if labels imply otherwise)
styles = struct('seg17','--','seg60','-');

fig = figure('Visible','off','Position',[100 100 1200 700]);
ax  = axes(fig);
hold(ax, 'on');

results = struct();

for iD = 1:numel(depthLabels)
    label = depthLabels{iD};
    col = depthColors{min(iD, numel(depthColors))};

    fprintf('\n=== %s ===\n', label);

    % --- Load 17-min L2 ---
    L17 = load_L2(opts.L2dir, deployment, label);
    % --- Load 1-hour L2 ---
    L60 = load_L2(opts.L2hourlyDir, deployment, label);

    % Load MOP once per depth (use 17-min L2 to set time bounds; both cover the deployment)
    MOP = load_MOP_for(L17);

    % Ratio for each
    [f17, r17, n17, bands17] = compute_mean_ratio(L17, MOP);
    [f60, r60, n60, bands60] = compute_mean_ratio(L60, MOP);

    % Plot
    plot(ax, f17, r17, styles.seg17, 'Color', col, 'LineWidth', 1.4, ...
        'DisplayName', sprintf('%s — 17-min L2 (N=%d hrs)', tex_label(label), n17));
    plot(ax, f60, r60, styles.seg60, 'Color', col, 'LineWidth', 1.6, ...
        'DisplayName', sprintf('%s — 1-hour L2 (N=%d hrs)', tex_label(label), n60));

    results.(matlab.lang.makeValidName(label)).bands17 = bands17;
    results.(matlab.lang.makeValidName(label)).bands60 = bands60;

    fprintf('  17-min  Low/Mid/High = %.3f / %.3f / %.3f   Overall = %.3f\n', ...
        bands17.low, bands17.mid, bands17.high, bands17.overall);
    fprintf('  1-hour  Low/Mid/High = %.3f / %.3f / %.3f   Overall = %.3f\n', ...
        bands60.low, bands60.mid, bands60.high, bands60.overall);
end

% Clipped y-axis to focus on signal (ratios spike at band edges where MOP energy is small)
fSS = [0.04, 0.25];
xlim(ax, fSS);
ylim(ax, [0.75 1.5]);
ylim_now = ylim(ax);

% Band shading (no legend entries)
patch(ax, [0.04 0.08 0.08 0.04], [ylim_now(1) ylim_now(1) ylim_now(2) ylim_now(2)], ...
    [0.6 0.7 0.9], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility','off');
patch(ax, [0.14 0.25 0.25 0.14], [ylim_now(1) ylim_now(1) ylim_now(2) ylim_now(2)], ...
    [0.9 0.7 0.6], 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'HandleVisibility','off');

% Reference line at ratio = 1 (no legend entry)
plot(ax, fSS, [1 1], 'k:', 'LineWidth', 1.0, 'HandleVisibility','off');

% Band labels just above the bottom
yTxt = ylim_now(1) + 0.05*(ylim_now(2) - ylim_now(1));
text(ax, 0.06,  yTxt, 'low swell',  'HorizontalAlignment','center', 'FontSize', 10, 'FontWeight','bold');
text(ax, 0.11,  yTxt, 'mid swell',  'HorizontalAlignment','center', 'FontSize', 10, 'FontWeight','bold');
text(ax, 0.195, yTxt, 'high swell', 'HorizontalAlignment','center', 'FontSize', 10, 'FontWeight','bold');

xlabel(ax, 'Frequency (Hz)');
ylabel(ax, 'PUV / shoaled MOP spectral ratio');
title(ax, sprintf('%s — segment-length effect on PUV/MOP spectral bias', deployment));
legend(ax, 'Location', 'northeast');
grid(ax, 'on');

% Embedded annotation: band-averaged ratios per (depth, segment length)
fnames = fieldnames(results);
header = sprintf('Band-mean ratio (low / mid / high | overall)');
hdr1 = sprintf('%-11s %-26s %-26s', '', '17-min L2', '1-hour L2');
annotLines = {header; hdr1};
for iD = 1:numel(fnames)
    r = results.(fnames{iD});
    annotLines{end+1} = sprintf('%-11s  %.3f/%.3f/%.3f | %.3f      %.3f/%.3f/%.3f | %.3f', ...
        tex_label(depthLabels{iD}), ...
        r.bands17.low, r.bands17.mid, r.bands17.high, r.bands17.overall, ...
        r.bands60.low, r.bands60.mid, r.bands60.high, r.bands60.overall);  %#ok<AGROW>
end
% Annotation in lower-mid axes region (clear of the low-band spike and legend)
text(ax, 0.5, 0.22, strjoin(annotLines, newline), ...
    'Units', 'normalized', ...
    'FontName','Courier', 'FontSize', 9, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'BackgroundColor', [1 1 1 0.92], 'EdgeColor', 'k', 'Margin', 5);

outFile = fullfile(opts.figDir, sprintf('MOP_ratio_overlay_%s.png', strjoin(depthLabels,'_')));
exportgraphics(fig, outFile, 'Resolution', 220);
close(fig);
fprintf('\nFigure saved: %s\n', outFile);
end


% ============================================================
function L2 = load_L2(rootDir, deployment, label)
S = load(fullfile(rootDir, deployment, [label '_L2.mat']));
L2 = S.L2;
end


function MOP = load_MOP_for(L2)
mopStation = L2.mopStation;
validIdx = L2.segValid;
tStart = min(L2.time(validIdx));
tEnd   = max(L2.time(validIdx));
if isempty(tStart.TimeZone), tStart.TimeZone = 'UTC'; tEnd.TimeZone = 'UTC'; end
fprintf('  Loading MOP data for %s...\n', mopStation);
MOP = read_MOPline2(mopStation, tStart, tEnd);
end


function [f_puv, meanRatio, nMatch, bands] = compute_mean_ratio(L2, MOP)
% Replicates the core ratio logic from compare_PUV_MOP_spectra.m
validIdx = L2.segValid;
h_mop = double(MOP.depth);
h_puv = median(L2.depth(validIdx));

freq_mop = double(MOP.frequency(:));
omega_mop = 2*pi*freq_mop;
k_mop_h = get_wavenumber(omega_mop, h_mop);
k_puv_h = get_wavenumber(omega_mop, h_puv);
cg_mop_h = get_cg(k_mop_h, h_mop);
cg_puv_h = get_cg(k_puv_h, h_puv);
shoalFactor = cg_mop_h(:) ./ cg_puv_h(:);
spec_shoaled = MOP.spec1D .* shoalFactor';

t_mop = MOP.time;
L2_time = L2.time;
if isempty(L2_time.TimeZone) && ~isempty(t_mop.TimeZone)
    L2_time.TimeZone = t_mop.TimeZone;
elseif ~isempty(L2_time.TimeZone) && isempty(t_mop.TimeZone)
    t_mop.TimeZone = L2_time.TimeZone;
end

matched_puv = NaN(length(t_mop), 1);
validTimes = find(validIdx);
for t = 1:length(t_mop)
    dt = abs(L2_time(validTimes) - t_mop(t));
    [minDt, iMin] = min(dt);
    if minDt < minutes(30)
        matched_puv(t) = validTimes(iMin);
    end
end
hasMatch = ~isnan(matched_puv);
nMatch = sum(hasMatch);

f_puv = L2.f;
fSS = L2.params.fSS;
iSS_puv = f_puv >= fSS(1) & f_puv <= fSS(2);

ratioSum = zeros(length(f_puv), 1);
ratioCount = zeros(length(f_puv), 1);
matchedMopIdx = find(hasMatch);
for t = 1:length(matchedMopIdx)
    mi = matchedMopIdx(t);
    pi_idx = matched_puv(mi);
    s_puv = L2.S_eta(:, pi_idx);
    s_mop_interp = interp1(freq_mop, spec_shoaled(mi, :)', f_puv, 'linear', 0);
    goodBins = s_puv > 0 & s_mop_interp > 0 & iSS_puv;
    ratio = s_puv ./ s_mop_interp;
    ratioSum(goodBins) = ratioSum(goodBins) + ratio(goodBins);
    ratioCount(goodBins) = ratioCount(goodBins) + 1;
end
meanRatio = ratioSum ./ max(ratioCount, 1);
meanRatio(ratioCount < 10) = NaN;

% Band-averaged
bands.low     = band_mean(meanRatio, f_puv, [0.04 0.08]);
bands.mid     = band_mean(meanRatio, f_puv, [0.08 0.14]);
bands.high    = band_mean(meanRatio, f_puv, [0.14 0.25]);
bands.overall = band_mean(meanRatio, f_puv, fSS);
end


function r = band_mean(ratio, f, bnd)
ix = f >= bnd(1) & f <= bnd(2) & ~isnan(ratio);
if any(ix)
    r = mean(ratio(ix));
else
    r = NaN;
end
end
