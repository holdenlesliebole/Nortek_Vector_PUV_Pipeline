function results = compare_PUV_MOP(L2, toolboxPath)
% COMPARE_PUV_MOP  Compare PUV L2 wave parameters against MOP model data.
%
%   results = compare_PUV_MOP(L2)
%   results = compare_PUV_MOP(L2, toolboxPath)
%
%   Loads hourly MOP wave model data (at 10 m depth) from the CDIP THREDDS
%   server, shoals the spectrum to the PUV instrument depth, and computes
%   comparison statistics and scatter plots.
%
%   MOP is treated as the reference: significant divergence indicates a
%   potential issue with PUV processing, not with the model.
%
%   INPUTS
%     L2          - L2 struct from PUV_L2_spectral (loaded from *_L2.mat)
%     toolboxPath - (optional) path to toolbox/ containing read_MOPline2.m
%                   Default: ~/Documents/Scripps/Research/toolbox
%
%   OUTPUT
%     results - struct with fields:
%       .time_hourly  - datetime vector (hourly, common grid)
%       .Hs_puv       - PUV Hs interpolated to hourly grid (m)
%       .Hs_mop       - MOP Hs shoaled to instrument depth (m)
%       .Tm_puv       - PUV mean period (Tm02) interpolated to hourly grid (s)
%       .Tm_mop       - MOP mean period (1/fm) at 10 m (s)
%       .Ef_puv       - PUV energy flux interpolated to hourly grid (W/m)
%       .Ef_mop       - MOP energy flux shoaled to instrument depth (W/m)
%       .stats        - struct with R2, RMSE, bias, N for each variable
%       .MOP          - raw MOP struct from read_MOPline2
%
%   REQUIRES
%     read_MOPline2.m (in toolbox/), get_wavenumber.m, get_cg.m on MATLAB path
%
%   NOTES
%     - MOP spectra are at 10 m depth and have non-uniform frequency spacing.
%       Integration uses the MOP bandwidth vector (fbw), not constant df.
%     - Shoaling uses linear wave theory: S(f,h) = S(f,10) * Cg(10) / Cg(h)
%     - PUV 17-min segments are interpolated to the MOP hourly grid for comparison.
% Author: Holden Leslie-Bole, 2026

%% ======================== SETUP ========================
if nargin < 2 || isempty(toolboxPath)
    toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
end

% Ensure read_MOPline2 is accessible
if ~exist('read_MOPline2', 'file')
    if isfolder(toolboxPath)
        addpath(toolboxPath);
        fprintf('Added toolbox to path: %s\n', toolboxPath);
    else
        error('compare_PUV_MOP:noToolbox', ...
            'Cannot find read_MOPline2. Provide toolboxPath or add toolbox/ to MATLAB path.');
    end
end

% Extract MOP station from L2 metadata
% L2.label is e.g. 'MOP580_5m' → station is 'D0580'
if isfield(L2, 'mopStation') && ~isempty(L2.mopStation)
    mopStation = L2.mopStation;
else
    mopNum = regexp(L2.label, 'MOP(\d+)', 'tokens', 'once');
    if isempty(mopNum)
        error('compare_PUV_MOP:noStation', ...
            'Cannot determine MOP station for label: %s', L2.label);
    end
    mopStation = ['D0' mopNum{1}];
end

rho = 1025;  % kg/m^3
g   = 9.81;  % m/s^2

%% ======================== LOAD MOP DATA ========================
% Use valid PUV time range
validIdx = L2.segValid;
tStart = min(L2.time(validIdx));
tEnd   = max(L2.time(validIdx));

% Ensure UTC timezone for THREDDS compatibility
if isempty(tStart.TimeZone)
    tStart.TimeZone = 'UTC';
    tEnd.TimeZone   = 'UTC';
end

fprintf('Loading MOP data for %s: %s to %s\n', mopStation, tStart, tEnd);
MOP = read_MOPline2(mopStation, tStart, tEnd);

if isempty(MOP.time)
    error('compare_PUV_MOP:noMOPdata', 'No MOP data returned for the requested time range.');
end

fprintf('  MOP: %d hourly records, depth = %.1f m\n', length(MOP.time), MOP.depth);

%% ======================== SHOAL MOP TO PUV DEPTH ========================
% MOP spectra are at 10 m depth. Shoal to mean PUV instrument depth.
h_mop = double(MOP.depth);               % 10 m
h_puv = median(L2.depth(validIdx));       % median instrument depth from L2
fprintf('  Shoaling MOP from %.1f m to %.1f m (PUV median depth)\n', h_mop, h_puv);

freq   = double(MOP.frequency(:));  % [nFreq x 1]
fbw    = double(MOP.fbw(:));        % non-uniform bandwidth
nFreq  = length(freq);
nTimes = length(MOP.time);

% Compute shoaling coefficient for each frequency (vectorized)
omega = 2 * pi * freq;
k_mop = get_wavenumber(omega, h_mop);
k_puv = get_wavenumber(omega, h_puv);
cg_mop = get_cg(k_mop, h_mop);
cg_puv = get_cg(k_puv, h_puv);

% Shoaling factor: energy conservation → S(h) = S(10) * Cg(10) / Cg(h)
shoalFactor = cg_mop(:) ./ cg_puv(:);  % [nFreq x 1]

% Apply shoaling to all time steps
% MOP.spec1D is [nTimes x nFreq]
spec_shoaled = MOP.spec1D .* shoalFactor';  % broadcast [nTimes x nFreq]

%% ======================== MOP BULK PARAMS AT PUV DEPTH ========================
% Frequency band: match L2 sea-swell band [0.04, 0.25] Hz
fSS = L2.params.fSS;
iSS = freq >= fSS(1) & freq <= fSS(2);

% Hs from shoaled spectrum
Hs_mop = zeros(nTimes, 1);
Ef_mop = zeros(nTimes, 1);

for t = 1:nTimes
    % Hs: 4 * sqrt(integral of S * df)
    m0 = sum(spec_shoaled(t, iSS) .* fbw(iSS)');
    Hs_mop(t) = 4 * sqrt(max(m0, 0));

    % Energy flux at PUV depth
    Ef_mop(t) = rho * g * sum(cg_puv(iSS)' .* spec_shoaled(t, iSS) .* fbw(iSS)');
end

% Mean period from MOP (1/fm avoids peak-frequency binning artifacts)
Tm_mop = 1 ./ double(MOP.fm);

%% ======================== INTERPOLATE PUV TO HOURLY ========================
% PUV has 17-min resolution; MOP is hourly. Interpolate PUV to MOP times.
t_puv = L2.time(validIdx);
t_mop = MOP.time;

% Ensure consistent timezone
if isempty(t_puv.TimeZone) && ~isempty(t_mop.TimeZone)
    t_puv.TimeZone = t_mop.TimeZone;
elseif ~isempty(t_puv.TimeZone) && isempty(t_mop.TimeZone)
    t_mop.TimeZone = t_puv.TimeZone;
end

Hs_puv_hourly = interp1(t_puv, L2.Hs(validIdx),   t_mop, 'linear');
Tm_puv_hourly = interp1(t_puv, L2.Tm02(validIdx), t_mop, 'linear');
Ef_puv_hourly = interp1(t_puv, L2.Ef(validIdx),   t_mop, 'linear');

%% ======================== STATISTICS ========================
results.time_hourly = t_mop;
results.Hs_puv = Hs_puv_hourly;
results.Hs_mop = Hs_mop;
results.Tm_puv = Tm_puv_hourly;
results.Tm_mop = Tm_mop;
results.Ef_puv = Ef_puv_hourly;
results.Ef_mop = Ef_mop;
results.MOP    = MOP;
results.h_puv  = h_puv;
results.h_mop  = h_mop;

% Compute stats for each variable
vars = {'Hs', 'Tm', 'Ef'};
units = {'m', 's', 'W/m'};
for v = 1:numel(vars)
    vname = vars{v};
    x = results.([vname '_mop']);
    y = results.([vname '_puv']);
    good = ~isnan(x) & ~isnan(y);

    if sum(good) < 10
        results.stats.(vname) = struct('R2', NaN, 'RMSE', NaN, ...
            'bias', NaN, 'N', sum(good), 'skill', NaN);
        continue
    end

    xg = x(good);
    yg = y(good);
    R = corrcoef(xg, yg);
    results.stats.(vname).R2   = R(1,2)^2;
    results.stats.(vname).RMSE = sqrt(mean((yg - xg).^2));
    results.stats.(vname).bias = mean(yg - xg);
    results.stats.(vname).N    = sum(good);
    % Willmott skill score
    results.stats.(vname).skill = 1 - sum((yg-xg).^2) / ...
        sum((abs(yg - mean(xg)) + abs(xg - mean(xg))).^2);
end

%% ======================== PRINT SUMMARY ========================
fprintf('\n--- PUV vs MOP Comparison: %s (%s) ---\n', L2.label, L2.deploymentName);
fprintf('  PUV depth: %.1f m | MOP depth: %.1f m (shoaled)\n', h_puv, h_mop);
fprintf('  Time range: %s to %s\n', tStart, tEnd);
fprintf('  %-6s  %8s  %8s  %8s  %8s  %6s\n', 'Var', 'R2', 'RMSE', 'Bias', 'Skill', 'N');
fprintf('  %s\n', repmat('-', 1, 52));
for v = 1:numel(vars)
    s = results.stats.(vars{v});
    fprintf('  %-6s  %8.3f  %8.3f  %+8.3f  %8.3f  %6d\n', ...
        [vars{v} ' (' units{v} ')'], s.R2, s.RMSE, s.bias, s.skill, s.N);
end

%% ======================== SCATTER PLOTS ========================
fig = figure('Position', [100 100 1400 400], 'Name', ...
    sprintf('PUV vs MOP: %s %s', L2.deploymentName, L2.label));

varLabels = {'Hs (m)', 'Tm (s)', 'Ef (W/m)'};

for v = 1:3
    subplot(1, 3, v);
    x = results.([vars{v} '_mop']);
    y = results.([vars{v} '_puv']);
    good = ~isnan(x) & ~isnan(y);

    scatter(x(good), y(good), 8, 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;

    % 1:1 line
    lims = [min([x(good); y(good)]), max([x(good); y(good)])];
    h1 = plot(lims, lims, 'k--', 'LineWidth', 1);

    % Best fit
    h2 = [];
    if sum(good) > 10
        p = polyfit(x(good), y(good), 1);
        h2 = plot(lims, polyval(p, lims), 'r-', 'LineWidth', 1);
    end

    xlabel(sprintf('MOP %s', varLabels{v}));
    ylabel(sprintf('PUV %s', varLabels{v}));
    title(sprintf('%s — %s', varLabels{v}, L2.label));
    axis equal; grid on;
    s = results.stats.(vars{v});
    text(0.05, 0.92, sprintf('R^2=%.3f\nRMSE=%.3f\nbias=%+.3f', ...
        s.R2, s.RMSE, s.bias), 'Units', 'normalized', 'FontSize', 8, ...
        'VerticalAlignment', 'top');

    % Legend
    if ~isempty(h2)
        legend([h1, h2], {'1:1', 'Best fit'}, 'Location', 'southeast', 'FontSize', 7);
    end
end

sgtitle(sprintf('%s — %s: PUV vs MOP (shoaled %.1f m to %.1f m)', ...
    L2.deploymentName, L2.label, h_mop, h_puv), 'FontWeight', 'bold');

% Save figure
diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end
figFile = fullfile(diagDir, sprintf('%s_%s_PUV_vs_MOP.png', ...
    L2.deploymentName, L2.label));
exportgraphics(fig, figFile, 'Resolution', 200);
fprintf('  Figure saved: %s\n', figFile);

end
