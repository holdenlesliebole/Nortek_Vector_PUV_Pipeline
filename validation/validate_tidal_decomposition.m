function validate_tidal_decomposition(L3, L2)
% VALIDATE_TIDAL_DECOMPOSITION  Compare t_tide depth prediction against
% the Scripps Pier NOAA tide gauge (station 9410230).
%
%   validate_tidal_decomposition(L3, L2)
%
%   Downloads observed and predicted tides from the NOAA API for the
%   deployment time period, then compares against the L3 t_tide depth
%   prediction to:
%     1. Verify t_tide is extracting the correct tidal constituents
%     2. Check for clock offset (UTC vs local time)
%     3. Quantify residual (non-tidal depth variation from waves, setup, etc.)
%
%   REQUIRES
%     getztide2.m on the MATLAB path (in toolbox/)

toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
if ~exist('getztide2', 'file')
    addpath(toolboxPath);
end

validIdx = L3.segValid;

%% Get time range
t = L2.time;
if isempty(t.TimeZone)
    t_for_noaa = t;  % assume UTC for NOAA query
else
    t_for_noaa = t;
end

t1 = min(t(validIdx));
t2 = max(t(validIdx));

% Convert to datenum for getztide2
dn1 = datenum(t1);
dn2 = datenum(t2);

%% Download NOAA data (chunked into 30-day requests to avoid API timeout)
fprintf('Downloading NOAA tide gauge data (Scripps Pier, 9410230)...\n');

chunkDays = 30;
noaa_pred_time = {};
noaa_pred_hgt = [];
noaa_obs_time = {};
noaa_obs_hgt = [];
hasObs = true;

dn_cur = dn1;
while dn_cur < dn2
    dn_end = min(dn_cur + chunkDays, dn2);

    try
        [pt, ph] = getztide2(dn_cur, dn_end, 'gmt', 'msl', 'predictions');
        noaa_pred_time = [noaa_pred_time; pt]; %#ok<AGROW>
        noaa_pred_hgt = [noaa_pred_hgt; double(ph)]; %#ok<AGROW>
    catch ME
        fprintf('  Warning: prediction chunk failed (%s–%s): %s\n', ...
            datestr(dn_cur, 'mm/dd'), datestr(dn_end, 'mm/dd'), ME.message);
    end

    if hasObs
        try
            [ot, oh] = getztide2(dn_cur, dn_end, 'gmt', 'msl', 'hourly_height');
            noaa_obs_time = [noaa_obs_time; ot]; %#ok<AGROW>
            noaa_obs_hgt = [noaa_obs_hgt; double(oh)]; %#ok<AGROW>
        catch
            hasObs = false;
        end
    end

    dn_cur = dn_end;
end

if isempty(noaa_pred_hgt)
    warning('No NOAA data retrieved. Check internet connection.');
    return
end

% Remove duplicate timestamps from chunk overlaps
[noaa_pred_time, iU] = unique(noaa_pred_time);
noaa_pred_hgt = noaa_pred_hgt(iU);
if hasObs
    [noaa_obs_time, iU] = unique(noaa_obs_time);
    noaa_obs_hgt = noaa_obs_hgt(iU);
end

fprintf('  Predictions: %d hourly records\n', length(noaa_pred_hgt));
if hasObs
    fprintf('  Observations: %d hourly records\n', length(noaa_obs_hgt));
end

%% Convert NOAA times to datetime
noaa_pred_dt = datetime(noaa_pred_time, 'InputFormat', 'yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
noaa_pred_hgt = double(noaa_pred_hgt);

if hasObs
    noaa_obs_dt = datetime(noaa_obs_time, 'InputFormat', 'yyyy-MM-dd HH:mm', 'TimeZone', 'UTC');
    noaa_obs_hgt = double(noaa_obs_hgt);
end

%% Align PUV depth with NOAA
% PUV depth = total water column (bed to surface)
% NOAA = water level relative to MSL
% They differ by the mean depth (distance from MSL to bed)
% We compare the ANOMALIES (deviations from mean)

puv_depth = L2.depth(validIdx);
puv_time = t(validIdx);
if isempty(puv_time.TimeZone)
    puv_time.TimeZone = 'UTC';  % assume UTC
end

puv_depth_anom = puv_depth - mean(puv_depth, 'omitnan');

% Interpolate NOAA to PUV times
noaa_pred_at_puv = interp1(noaa_pred_dt, noaa_pred_hgt, puv_time, 'linear', NaN);

% Also interpolate t_tide prediction
ttide_pred = L3.tidal.depth_pred(validIdx) - L3.tidal.mean_depth;

%% Cross-correlation for phase check
% If PUV clock is in UTC, the cross-correlation peak should be at lag=0
% If in Pacific time, peak should be at lag ~+7-8 hours
good = ~isnan(puv_depth_anom) & ~isnan(noaa_pred_at_puv);

fprintf('\n=== Tidal Validation: %s (%s) ===\n', L3.label, L3.deploymentName);
fprintf('  PUV mean depth: %.2f m\n', mean(puv_depth, 'omitnan'));

if sum(good) > 100
    % Direct correlation at zero lag
    R_zero = corrcoef(puv_depth_anom(good), noaa_pred_at_puv(good));
    fprintf('  PUV depth anomaly vs NOAA prediction: R = %.3f (at zero lag)\n', R_zero(1,2));

    % Cross-correlation to find optimal lag
    maxLag_samples = round(12 / hours(median(diff(puv_time))));  % ±12 hours
    [xcf, lags] = xcorr(puv_depth_anom(good) - mean(puv_depth_anom(good)), ...
                        noaa_pred_at_puv(good) - mean(noaa_pred_at_puv(good)), ...
                        maxLag_samples, 'coeff');
    [maxXcf, iMax] = max(xcf);
    optimalLag_hr = lags(iMax) * hours(median(diff(puv_time)));

    fprintf('  Optimal lag: %.1f hours (R = %.3f)\n', optimalLag_hr, maxXcf);

    if abs(optimalLag_hr) < 1
        fprintf('  --> PUV clock appears to be in UTC (lag < 1 hr)\n');
    elseif abs(optimalLag_hr - 7) < 1.5 || abs(optimalLag_hr - 8) < 1.5
        fprintf('  --> PUV clock may be in Pacific time (lag ~%.0f hr)\n', optimalLag_hr);
    elseif abs(optimalLag_hr + 7) < 1.5 || abs(optimalLag_hr + 8) < 1.5
        fprintf('  --> PUV clock may be in Pacific time (lag ~%.0f hr)\n', optimalLag_hr);
    else
        fprintf('  --> Unexpected lag — check clock convention\n');
    end

    % t_tide vs NOAA comparison
    good_tt = ~isnan(ttide_pred) & ~isnan(noaa_pred_at_puv);
    if sum(good_tt) > 100
        R_ttide = corrcoef(ttide_pred(good_tt), noaa_pred_at_puv(good_tt));
        rmse_ttide = sqrt(mean((ttide_pred(good_tt) - noaa_pred_at_puv(good_tt)).^2));
        fprintf('\n  t_tide prediction vs NOAA prediction:\n');
        fprintf('    R = %.3f, RMSE = %.3f m\n', R_ttide(1,2), rmse_ttide);
        if R_ttide(1,2) > 0.95
            fprintf('    --> PASS: t_tide matches NOAA well\n');
        elseif R_ttide(1,2) > 0.8
            fprintf('    --> OK: reasonable agreement, some residual\n');
        else
            fprintf('    --> CHECK: poor agreement — may indicate clock offset or data issues\n');
        end
    end
end

%% Diagnostic figure
fig = figure('Position', [50 50 1400 700], 'Color', 'w');

% Panel 1: Time series comparison
subplot(2,1,1)
plot(noaa_pred_dt, noaa_pred_hgt, 'r-', 'LineWidth', 1, 'DisplayName', 'NOAA prediction');
hold on
if hasObs
    plot(noaa_obs_dt, noaa_obs_hgt, 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5, ...
        'DisplayName', 'NOAA observed');
end
plot(puv_time, puv_depth_anom, 'b.', 'MarkerSize', 2, 'DisplayName', 'PUV depth anomaly');
plot(puv_time, ttide_pred, 'g-', 'LineWidth', 1, 'DisplayName', 't\_tide prediction');
xlabel('Time'); ylabel('Water level anomaly (m)');
title(sprintf('%s — %s: Tidal depth comparison', L3.deploymentName, L3.label));
legend('Location', 'best'); grid on;
xlim([puv_time(1) puv_time(end)]);

% Panel 2: Scatter
subplot(2,2,3)
scatter(noaa_pred_at_puv(good), puv_depth_anom(good), 4, 'filled', 'MarkerFaceAlpha', 0.2);
hold on; plot([-1 1], [-1 1], 'k--');
xlabel('NOAA prediction (m)'); ylabel('PUV depth anomaly (m)');
title(sprintf('PUV vs NOAA (R=%.3f)', R_zero(1,2)));
axis equal; grid on;

subplot(2,2,4)
if sum(good_tt) > 10
    scatter(noaa_pred_at_puv(good_tt), ttide_pred(good_tt), 4, 'filled', 'MarkerFaceAlpha', 0.2);
    hold on; plot([-1 1], [-1 1], 'k--');
    xlabel('NOAA prediction (m)'); ylabel('t\_tide prediction (m)');
    title(sprintf('t\\_tide vs NOAA (R=%.3f)', R_ttide(1,2)));
    axis equal; grid on;
end

sgtitle(sprintf('%s — %s: Tidal validation (Scripps Pier gauge)', ...
    L3.deploymentName, L3.label), 'FontWeight', 'bold');

diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end
exportgraphics(fig, fullfile(diagDir, sprintf('%s_%s_tidal_validation.png', ...
    L3.deploymentName, L3.label)), 'Resolution', 200);
fprintf('\n  Figure saved.\n');

end
