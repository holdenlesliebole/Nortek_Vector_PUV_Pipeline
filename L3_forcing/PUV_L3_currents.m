function L3 = PUV_L3_currents(L3, L2, opts)
% PUV_L3_CURRENTS  Level 3d: tidal current decomposition.
%
%   L3 = PUV_L3_currents(L3, L2)
%   L3 = PUV_L3_currents(L3, L2, opts)
%
%   Performs tidal harmonic analysis on L2 segment-mean currents using
%   t_tide, then separates tidal and subtidal (wave-driven) components.
%   The tidal DEPTH prediction comes from NOAA CO-OPS hourly predictions at
%   opts.tideStation.
%
%   INPUTS
%     L3 - L3 struct from previous L3 stages (gets appended to)
%     L2 - L2 struct from PUV_L2_spectral (L2.LATLON is read when no
%          tideStation is given)
%     opts (optional; drivers build it with l3_currents_opts(cfg))
%       .tideStation        NOAA CO-OPS station id (char), from cfg.tideStation.
%                           Empty or absent: La Jolla 9410230 if L2.LATLON lies
%                           in the San Diego region (sd_region below), else an
%                           ERROR (PUV_L3_currents:noTideStation).
%       .allowTtideFallback false (default): a failed NOAA download is an ERROR.
%                           true: the depth prediction falls back to the t_tide
%                           fit of the record itself (tidal.depth_source 't_tide',
%                           recorded as a fallback in provenance).
%       .allowNoTides       false (default): t_tide missing from the path is an
%                           ERROR. true: warn and return L3 without tidal/subtidal.
%
%   PRODUCTS
%     L3.tidal.u, .v         - tidal current prediction at segment times
%     L3.subtidal.u, .v      - subtidal residual (uMean - tidal)
%     L3.tidal.constituents  - t_tide output struct (amplitudes, phases)
%     L3.tidal.depth_pred    - tidal depth prediction
%     L3.tidal.depth_source  - 'NOAA' (or 't_tide' with allowTtideFallback)
%     L3.tidal.station       - NOAA station id used (stamped in provenance)
%     L3.tidal.station_source - 'config' | 'default (San Diego region)'
%
%   REQUIRES
%     t_tide v1.3 on the MATLAB path (README.md, "External dependencies"),
%     and network access to api.tidesandcurrents.noaa.gov.
%
%   WHY THE ERRORS (2026-10-15). Until then this function warned and saved an
%   L3 with no tidal/subtidal fields when t_tide was absent, used NOAA La Jolla
%   9410230 for every deployment (hardcoded in the toolbox getztide2.m,
%   including Catalina, 110 km away), and fell back to t_tide silently when the
%   NOAA download failed (TOR24W/MOP586_10m sat in the catalog that way until
%   2026-10-12). The rebuild script refused the fallback; the drivers did not.
%
%   DETERMINISM (2026-10-09)
%     t_tide's default confidence intervals ('error','cboot') are Monte Carlo, and
%     its prediction keeps only constituents above the SNR threshold, so the
%     output depended on the caller's RNG state: two runs of the same record
%     differed by 0.0027-0.0065 m/s against a tidal rms of 0.003-0.012 m/s. Each
%     t_tide call (velocity and depth) now runs with rng(0,'twister'); the
%     caller's RNG state is saved before and restored after, even on error.
%     Method unchanged: 'cboot'. Seed: 0, twister. See test_l3_currents_determinism.
%
%   NOTE
%     If t_tide is not on the path, this function first tries the lab copy at
%     ~/Documents/Scripps/Research/toolbox/t_tide_v1.3.
% Author: Holden Leslie-Bole, 2026

if nargin < 3 || isempty(opts), opts = struct(); end
allowTtideFallback = isfield(opts, 'allowTtideFallback') && isequal(opts.allowTtideFallback, true);
allowNoTides       = isfield(opts, 'allowNoTides') && isequal(opts.allowNoTides, true);

%% Tide station: from the config, or La Jolla for San Diego, else an error
if isfield(opts, 'tideStation') && ~isempty(opts.tideStation)
    tideStation = char(string(opts.tideStation));
    stationSource = 'config';
else
    if ~isfield(L2, 'LATLON') || numel(L2.LATLON) < 2 || ~sd_region(L2.LATLON)
        ll = 'none'; if isfield(L2, 'LATLON'), ll = mat2str(double(L2.LATLON(:)'), 7); end
        error('PUV_L3_currents:noTideStation', ...
            ['No tide station for this deployment (LATLON %s is outside the San Diego region ' ...
             'where La Jolla 9410230 is the default). Set cfg.tideStation to a NOAA CO-OPS ' ...
             'harmonic station near the site; see docs/NEW_DEPLOYMENT.md.'], ll);
    end
    tideStation = '9410230';   % NOAA La Jolla (Scripps Institution Wharf)
    stationSource = 'default (San Diego region)';
end

%% Ensure t_tide is available
if ~exist('t_tide', 'file')
    % Try known locations
    ttidePaths = {
        fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', ...
            'toolbox', 't_tide_v1.3')
    };
    found = false;
    for p = 1:length(ttidePaths)
        if isfolder(ttidePaths{p})
            addpath(ttidePaths{p});
            found = true;
            fprintf('  Added t_tide to path: %s\n', ttidePaths{p});
            break
        end
    end
    if ~found
        if allowNoTides
            warning('PUV_L3_currents:noTtide', ...
                't_tide not found; opts.allowNoTides = true, so L3 is returned WITHOUT tidal/subtidal fields.');
            return
        end
        error('PUV_L3_currents:noTtide', ...
            ['t_tide is not on the MATLAB path, so the tidal/subtidal decomposition cannot run. ' ...
             'Install t_tide v1.3 (README.md, "External dependencies") and add it to the path. ' ...
             'To build an L3 without tides on purpose, pass opts.allowNoTides = true.']);
    end
end

validIdx = L3.segValid;
nSeg = length(L3.time);

%% Prepare input time series
% t_tide needs evenly-spaced data. L2 segments are non-overlapping
% 1-hour windows aligned to UTC top-of-hour, so they're approximately
% evenly spaced when valid. However, gaps (invalid segments) create
% holes.
%
% Strategy: interpolate mean currents onto a regular grid at the segment
% spacing, run t_tide, then evaluate tidal prediction at actual segment times.

t = L2.time;
uMean = L2.uMean;
vMean = L2.vMean;
depth = L2.depth;

% Segment spacing
dt = median(diff(t(validIdx)));
dt_hr = hours(dt);

% Create regular time grid spanning the deployment
t_reg = t(find(validIdx, 1, 'first')) : dt : t(find(validIdx, 1, 'last'));
nReg = length(t_reg);

% Ensure timezone consistency
if isempty(t.TimeZone) && ~isempty(t_reg.TimeZone)
    t.TimeZone = t_reg.TimeZone;
end

% Interpolate onto regular grid
u_reg = interp1(t(validIdx), uMean(validIdx), t_reg, 'linear', NaN);
v_reg = interp1(t(validIdx), vMean(validIdx), t_reg, 'linear', NaN);
d_reg = interp1(t(validIdx), depth(validIdx), t_reg, 'linear', NaN);

% Fill NaN gaps with linear interpolation for t_tide
% (t_tide can handle some gaps but performs better with continuous data)
u_filled = fillmissing(u_reg', 'linear', 'EndValues', 'nearest');
v_filled = fillmissing(v_reg', 'linear', 'EndValues', 'nearest');
d_filled = fillmissing(d_reg', 'linear', 'EndValues', 'nearest');

% Start time for t_tide
t0 = t_reg(1);
if ~isempty(t0.TimeZone)
    startVec = datevec(datetime(t0, 'TimeZone', ''));
else
    startVec = datevec(t0);
end

% Fit the tidal current only where velocity exists. The grid spans the
% PRESSURE-valid segments, and a segment can carry pressure with dead velocity
% (uMean NaN), so the grid can start or end in a long velocity gap. Any fill
% there invents data (linear extrapolation a ramp, 'nearest' a constant), and
% both bias the harmonic fit. Interior gaps inside the span are still filled
% linearly. Predictions outside the span are NaN.
vIdx = find(isfinite(u_reg) & isfinite(v_reg));
if isempty(vIdx), vSpan = []; else, vSpan = vIdx(1):vIdx(end); end
u_tidal_reg = NaN(nReg, 1);
v_tidal_reg = NaN(nReg, 1);
if ~isempty(vSpan)
    tv0 = t_reg(vSpan(1));
    if ~isempty(tv0.TimeZone), tv0 = datetime(tv0, 'TimeZone', ''); end
    startVecV = datevec(tv0);
end

fprintf('  Running t_tide on currents (%d of %d points, dt=%.2f hr)...\n', numel(vSpan), nReg, dt_hr);

%% Run t_tide on velocities (complex input: u + iv)
try
    if isempty(vSpan), error('no finite velocity on the grid'); end
    % Complex velocity for tidal analysis
    z_vel = u_filled(vSpan) + 1i * v_filled(vSpan);

    [tidestruc_vel, vel_pred] = ttide_seeded(z_vel, ...
        'interval', dt_hr, ...
        'start time', startVecV, ...
        'output', 'none');  % suppress text output

    u_tidal_reg(vSpan) = real(vel_pred);
    v_tidal_reg(vSpan) = imag(vel_pred);

    fprintf('    Velocity: %d constituents resolved\n', length(tidestruc_vel.freq));

catch ME
    warning('PUV_L3_currents:ttideFailed', ...
        't_tide velocity analysis failed: %s', ME.message);
    u_tidal_reg(vSpan) = 0;
    v_tidal_reg(vSpan) = 0;
    tidestruc_vel = struct();
end

%% Run t_tide on depth (for tidal elevation)
try
    % Remove mean depth before analysis
    d_mean = mean(d_filled, 'omitnan');
    d_anom = d_filled - d_mean;

    [tidestruc_depth, d_pred] = ttide_seeded(d_anom, ...
        'interval', dt_hr, ...
        'start time', startVec, ...
        'output', 'none');

    d_tidal_reg = d_pred + d_mean;  % add mean back

    fprintf('    Depth: %d constituents resolved\n', length(tidestruc_depth.freq));

catch ME
    warning('PUV_L3_currents:ttideDepthFailed', ...
        't_tide depth analysis failed: %s', ME.message);
    d_tidal_reg = d_filled;
    tidestruc_depth = struct();
end

%% NOAA tide predictions for the depth tidal signal (better than t_tide for depth)
useNOAA = false;
try
    fprintf('  Downloading NOAA tide predictions (station %s, %s)...\n', tideStation, stationSource);
    dn1 = datenum(t_reg(1));
    dn2 = datenum(t_reg(end));

    noaa_time_all = {};
    noaa_hgt_all = [];
    dn_cur = dn1;
    while dn_cur < dn2
        dn_end = min(dn_cur + 30, dn2);
        [nt, nh] = noaa_tide_predictions(tideStation, dn_cur, dn_end);
        noaa_time_all = [noaa_time_all; nt]; %#ok<AGROW>
        noaa_hgt_all = [noaa_hgt_all; double(nh)]; %#ok<AGROW>
        dn_cur = dn_end;
    end

    [noaa_time_all, iU] = unique(noaa_time_all);
    noaa_hgt_all = noaa_hgt_all(iU);

    noaa_dt = datetime(noaa_time_all, 'InputFormat', 'yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');

    % Strip timezone for interpolation (PUV times are UTC but untagged)
    noaa_dt_notz = datetime(noaa_dt, 'TimeZone', '');
    t_reg_notz = t_reg;
    if ~isempty(t_reg_notz.TimeZone)
        t_reg_notz = datetime(t_reg_notz, 'TimeZone', '');
    end

    % NOAA is relative to MSL; add mean depth to get total water column
    d_tidal_noaa = interp1(noaa_dt_notz, noaa_hgt_all, t_reg_notz', 'linear', NaN) + d_mean;

    useNOAA = true;
    fprintf('    NOAA tidal predictions loaded (%d records)\n', length(noaa_hgt_all));
catch ME
    if ~allowTtideFallback
        error('PUV_L3_currents:noaaFailed', ...
            ['NOAA tide predictions for station %s failed (%s). L3 not built: the t_tide ' ...
             'depth fallback is refused unless opts.allowTtideFallback = true.'], tideStation, ME.message);
    end
    fprintf('    NOAA download failed: %s -- using t_tide for depth (opts.allowTtideFallback)\n', ME.message);
end

%% Identify data gaps for quality flagging
% Flag tidal predictions as unreliable near large data gaps
% where t_tide's interpolated input degrades the harmonic fit.
gap_flag = false(nReg, 1);
isNaN_orig = isnan(u_reg);  % original NaN pattern before filling
gapMinSamples = round(6 / dt_hr);  % gaps > 6 hours are flagged

% Find gap regions and extend flag by gapMinSamples on each side
inGap = false;
gapStart = 0;
for j = 1:nReg
    if isNaN_orig(j)
        if ~inGap
            gapStart = j;
            inGap = true;
        end
    else
        if inGap
            gapLen = j - gapStart;
            if gapLen >= gapMinSamples
                flagStart = max(1, gapStart - gapMinSamples);
                flagEnd = min(nReg, j + gapMinSamples);
                gap_flag(flagStart:flagEnd) = true;
            end
            inGap = false;
        end
    end
end
if inGap && (nReg + 1 - gapStart) >= gapMinSamples      % a gap that runs to the end
    gap_flag(max(1, gapStart - gapMinSamples):nReg) = true;
end

%% Interpolate tidal predictions back to actual segment times
L3.tidal.u = NaN(nSeg, 1);
L3.tidal.v = NaN(nSeg, 1);
L3.subtidal.u = NaN(nSeg, 1);
L3.subtidal.v = NaN(nSeg, 1);
L3.tidal.depth_pred = NaN(nSeg, 1);
L3.tidal.reliable = false(nSeg, 1);

% Interpolate from regular grid to segment times
L3.tidal.u(validIdx) = interp1(t_reg, u_tidal_reg, t(validIdx), 'linear', NaN);
L3.tidal.v(validIdx) = interp1(t_reg, v_tidal_reg, t(validIdx), 'linear', NaN);

% Use NOAA for depth if available, otherwise t_tide
if useNOAA
    L3.tidal.depth_pred(validIdx) = interp1(t_reg, d_tidal_noaa, t(validIdx), 'linear', NaN);
    L3.tidal.depth_source = 'NOAA';
else
    L3.tidal.depth_pred(validIdx) = interp1(t_reg, d_tidal_reg, t(validIdx), 'linear', NaN);
    L3.tidal.depth_source = 't_tide';
end

% Reliability flag: false near large data gaps where t_tide current
% predictions are unreliable (depth from NOAA is always reliable)
gap_at_seg = interp1(t_reg, double(~gap_flag), t(validIdx), 'nearest', 0);
L3.tidal.reliable(validIdx) = gap_at_seg > 0.5;

% Subtidal = observed - tidal
% Note: near data gaps, tidal.reliable = false indicates the t_tide
% current prediction may have artifacts. The values are kept (not NaN'd)
% so the subtidal residual is always available, but users should check
% tidal.reliable before interpreting tidal current details near gaps.
L3.subtidal.u(validIdx) = uMean(validIdx) - L3.tidal.u(validIdx);
L3.subtidal.v(validIdx) = vMean(validIdx) - L3.tidal.v(validIdx);

% Store constituents
L3.tidal.vel_constituents = tidestruc_vel;
L3.tidal.depth_constituents = tidestruc_depth;
L3.tidal.mean_depth = d_mean;
L3.tidal.ttide_rng = 'rng(0,''twister'') set before and restored after each t_tide call (ttide_seeded)';   % stamped in L3 provenance
L3.tidal.station = tideStation;            % NOAA CO-OPS id; stamped in L3 provenance
L3.tidal.station_source = stationSource;

nReliable = sum(L3.tidal.reliable(validIdx));
nValid = sum(validIdx);

%% Detailed diagnostic output
fprintf('\n  L3d current decomposition — detailed diagnostics:\n');
fprintf('    Depth source: %s\n', L3.tidal.depth_source);
fprintf('    Mean depth: %.2f m\n', d_mean);

% Depth tidal signal
dp = L3.tidal.depth_pred(validIdx);
fprintf('    Tidal depth prediction:\n');
fprintf('      min = %.2f m, max = %.2f m, range = %.2f m\n', ...
    min(dp, [], 'omitnan'), max(dp, [], 'omitnan'), ...
    max(dp, [], 'omitnan') - min(dp, [], 'omitnan'));
fprintf('      NaN count: %d / %d\n', sum(isnan(dp)), length(dp));

% Spot-check: print first 5 and last 5 tidal depth values with times
fprintf('    First 5 tidal depth values:\n');
vt = find(validIdx);
for j = 1:min(5, length(vt))
    fprintf('      %s  depth=%.3f m  tidal_pred=%.3f m\n', ...
        datestr(L2.time(vt(j)), 'yyyy-mm-dd HH:MM'), ...
        L2.depth(vt(j)), L3.tidal.depth_pred(vt(j)));
end
fprintf('    Last 5 tidal depth values:\n');
for j = max(1, length(vt)-4):length(vt)
    fprintf('      %s  depth=%.3f m  tidal_pred=%.3f m\n', ...
        datestr(L2.time(vt(j)), 'yyyy-mm-dd HH:MM'), ...
        L2.depth(vt(j)), L3.tidal.depth_pred(vt(j)));
end

% Correlation between PUV depth and tidal prediction
goodD = ~isnan(dp) & ~isnan(L2.depth(validIdx));
if sum(goodD) > 20
    R_depth = corrcoef(L2.depth(vt(goodD)), dp(goodD));
    fprintf('    PUV depth vs tidal pred: R = %.4f\n', R_depth(1,2));
end

% Velocity tidal signal
fprintf('    Tidal currents:\n');
fprintf('      u: range [%+.4f, %+.4f] m/s\n', ...
    min(L3.tidal.u, [], 'omitnan'), max(L3.tidal.u, [], 'omitnan'));
fprintf('      v: range [%+.4f, %+.4f] m/s\n', ...
    min(L3.tidal.v, [], 'omitnan'), max(L3.tidal.v, [], 'omitnan'));
fprintf('      Reliable segments: %d/%d (%.0f%%)\n', nReliable, nValid, 100*nReliable/nValid);

% Subtidal residual
fprintf('    Subtidal residual:\n');
fprintf('      u mean = %+.4f m/s (cross-shore, - = offshore)\n', mean(L3.subtidal.u, 'omitnan'));
fprintf('      v mean = %+.4f m/s (alongshore, + = north)\n', mean(L3.subtidal.v, 'omitnan'));
fprintf('      u std  = %.4f m/s\n', std(L3.subtidal.u, 'omitnan'));
fprintf('      v std  = %.4f m/s\n', std(L3.subtidal.v, 'omitnan'));

%% Summary
fprintf('  L3d current decomposition:\n');
fprintf('    Tidal u: range [%+.4f, %+.4f] m/s\n', ...
    min(L3.tidal.u, [], 'omitnan'), max(L3.tidal.u, [], 'omitnan'));
fprintf('    Tidal v: range [%+.4f, %+.4f] m/s\n', ...
    min(L3.tidal.v, [], 'omitnan'), max(L3.tidal.v, [], 'omitnan'));
fprintf('    Subtidal u: mean = %+.4f m/s (cross-shore residual)\n', ...
    mean(L3.subtidal.u, 'omitnan'));
fprintf('    Subtidal v: mean = %+.4f m/s (alongshore residual)\n', ...
    mean(L3.subtidal.v, 'omitnan'));
fprintf('    Tidal depth range: %.2f m\n', ...
    max(L3.tidal.depth_pred, [], 'omitnan') - min(L3.tidal.depth_pred, [], 'omitnan'));

end


function tf = sd_region(latlon)
% San Diego County open coast and bays, where NOAA La Jolla 9410230 is the
% default tide station: lat 32.50-33.45 N, lon 117.70-117.05 W (Mexican border
% to San Onofre). Every San Diego deployment in the registry lies inside it;
% Santa Catalina Island (lon about -118.3 to -118.6) lies outside.
lat = latlon(1); lon = latlon(2);
tf = lat >= 32.50 && lat <= 33.45 && lon >= -117.70 && lon <= -117.05;
end


function [ts, pred] = ttide_seeded(varargin)
% t_tide with a fixed RNG stream (seed 0, twister) so its Monte Carlo error
% estimate, and hence the SNR-selected prediction, is reproducible. The caller's
% RNG state is restored on exit, including when t_tide throws.
saved = rng;
restore = onCleanup(@() rng(saved));
rng(0, 'twister');
[ts, pred] = t_tide(varargin{:});
end
