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

%% Interpolate tidal predictions back to actual segment times
L3.tidal.u = NaN(nSeg, 1);
L3.tidal.v = NaN(nSeg, 1);
L3.subtidal.u = NaN(nSeg, 1);
L3.subtidal.v = NaN(nSeg, 1);
L3.tidal.depth_pred = NaN(nSeg, 1);

% Interpolate from regular grid to segment times
L3.tidal.u(validIdx) = interp1(t_reg, u_tidal_reg, t(validIdx), 'linear', NaN);
L3.tidal.v(validIdx) = interp1(t_reg, v_tidal_reg, t(validIdx), 'linear', NaN);
L3.tidal.depth_pred(validIdx) = interp1(t_reg, d_tidal_reg, t(validIdx), 'linear', NaN);

% Subtidal = observed - tidal
L3.subtidal.u(validIdx) = uMean(validIdx) - L3.tidal.u(validIdx);
L3.subtidal.v(validIdx) = vMean(validIdx) - L3.tidal.v(validIdx);

% Store constituents
L3.tidal.vel_constituents = tidestruc_vel;
L3.tidal.depth_constituents = tidestruc_depth;
L3.tidal.mean_depth = d_mean;

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
