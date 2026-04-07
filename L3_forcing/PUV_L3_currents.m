function L3 = PUV_L3_currents(L3, L2)
% PUV_L3_CURRENTS  Level 3d: tidal current decomposition.
%
%   L3 = PUV_L3_currents(L3, L2)
%
%   Performs tidal harmonic analysis on L2 segment-mean currents using
%   t_tide, then separates tidal and subtidal (wave-driven) components.
%
%   INPUTS
%     L3 - L3 struct from previous L3 stages (gets appended to)
%     L2 - L2 struct from PUV_L2_spectral
%
%   PRODUCTS
%     L3.tidal.u, .v         - tidal current prediction at segment times
%     L3.subtidal.u, .v      - subtidal residual (uMean - tidal)
%     L3.tidal.constituents  - t_tide output struct (amplitudes, phases)
%     L3.tidal.depth_pred    - tidal depth prediction
%
%   REQUIRES
%     t_tide.m on the MATLAB path
%
%   NOTE
%     t_tide needs the t_tide toolbox directory on the path. If not found,
%     this function will attempt to add it from a known location.

%% Ensure t_tide is available
if ~exist('t_tide', 'file')
    % Try known locations
    ttidePaths = {
        fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', ...
            'summer 2021 Maldives research', 'old code', 't_tide_v1')
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
        warning('PUV_L3_currents:noTtide', ...
            't_tide not found. Skipping tidal decomposition.');
        return
    end
end

validIdx = L3.segValid;
nSeg = length(L3.time);

%% Prepare input time series
% t_tide needs evenly-spaced data. L2 segments are non-overlapping 17-min
% windows, so they're approximately evenly spaced when valid. However,
% gaps (invalid segments) create holes.
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
u_filled = fillmissing(u_reg', 'linear');
v_filled = fillmissing(v_reg', 'linear');
d_filled = fillmissing(d_reg', 'linear');

% Start time for t_tide
t0 = t_reg(1);
if ~isempty(t0.TimeZone)
    startVec = datevec(datetime(t0, 'TimeZone', ''));
else
    startVec = datevec(t0);
end

fprintf('  Running t_tide on currents (%d points, dt=%.2f hr)...\n', nReg, dt_hr);

%% Run t_tide on velocities (complex input: u + iv)
try
    % Complex velocity for tidal analysis
    z_vel = u_filled + 1i * v_filled;

    [tidestruc_vel, vel_pred] = t_tide(z_vel, ...
        'interval', dt_hr, ...
        'start time', startVec, ...
        'output', 'none');  % suppress text output

    u_tidal_reg = real(vel_pred);
    v_tidal_reg = imag(vel_pred);

    fprintf('    Velocity: %d constituents resolved\n', length(tidestruc_vel.freq));

catch ME
    warning('PUV_L3_currents:ttideFailed', ...
        't_tide velocity analysis failed: %s', ME.message);
    u_tidal_reg = zeros(nReg, 1);
    v_tidal_reg = zeros(nReg, 1);
    tidestruc_vel = struct();
end

%% Run t_tide on depth (for tidal elevation)
try
    % Remove mean depth before analysis
    d_mean = mean(d_filled, 'omitnan');
    d_anom = d_filled - d_mean;

    [tidestruc_depth, d_pred] = t_tide(d_anom, ...
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

%% Try NOAA tide gauge for depth tidal signal (better than t_tide for depth)
toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
if ~exist('getztide2', 'file'), addpath(toolboxPath); end

useNOAA = false;
if exist('getztide2', 'file')
    try
        fprintf('  Downloading NOAA tide predictions (Scripps Pier)...\n');
        dn1 = datenum(t_reg(1));
        dn2 = datenum(t_reg(end));

        noaa_time_all = {};
        noaa_hgt_all = [];
        dn_cur = dn1;
        while dn_cur < dn2
            dn_end = min(dn_cur + 30, dn2);
            [nt, nh] = getztide2(dn_cur, dn_end, 'gmt', 'msl', 'predictions');
            noaa_time_all = [noaa_time_all; nt]; %#ok<AGROW>
            noaa_hgt_all = [noaa_hgt_all; double(nh)]; %#ok<AGROW>
            dn_cur = dn_end;
        end

        [noaa_time_all, iU] = unique(noaa_time_all);
        noaa_hgt_all = noaa_hgt_all(iU);

        noaa_dt = datetime(noaa_time_all, 'InputFormat', 'yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
        % NOAA is relative to MSL; add mean depth to get total water column
        d_tidal_noaa = interp1(noaa_dt, noaa_hgt_all, t_reg', 'linear', NaN) + d_mean;

        useNOAA = true;
        fprintf('    NOAA tidal predictions loaded (%d records)\n', length(noaa_hgt_all));
    catch ME
        fprintf('    NOAA download failed: %s — using t_tide for depth\n', ME.message);
    end
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

% NaN out unreliable tidal current predictions
unreliable = validIdx & ~L3.tidal.reliable;
L3.tidal.u(unreliable) = NaN;
L3.tidal.v(unreliable) = NaN;

% Subtidal = observed - tidal (only where tidal prediction is reliable)
L3.subtidal.u(validIdx) = uMean(validIdx) - L3.tidal.u(validIdx);
L3.subtidal.v(validIdx) = vMean(validIdx) - L3.tidal.v(validIdx);

% Store constituents
L3.tidal.vel_constituents = tidestruc_vel;
L3.tidal.depth_constituents = tidestruc_depth;
L3.tidal.mean_depth = d_mean;

nReliable = sum(L3.tidal.reliable(validIdx));
nValid = sum(validIdx);
fprintf('    Tidal currents reliable: %d/%d segments (%.0f%%)\n', ...
    nReliable, nValid, 100*nReliable/nValid);

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
