function theta = xyz_heading_series(compass_deg, fs, smoothHours)
% XYZ_HEADING_SERIES  Per-sample magnetic heading of the Vector's +x axis from
% its own compass, smoothed by a circular moving mean.
%
%   theta = xyz_heading_series(compass_deg, fs, smoothHours)
%
% Used instead of the record-median compass heading when the MOUNT rotated
% during the deployment (compass step accompanied by a tilt step), so that one
% heading cannot be right for the whole record. Set per instrument with
% instr.headingSmoothHours in the config; PUV_raw_process calls this only when
% instr.heading is NaN (compass mode). First used for SOL25A/MOP654_7m, whose
% mount turned from about 17.4 to 13.9 deg magnetic on 2025-04-02 between
% 11:30 and 16:00 UTC while pitch went from -2.1 to 0.0 deg.
%
% INPUTS
%   compass_deg  compass heading of +x, degrees magnetic, one value per sample
%                (the .sen column 11, duplicated to the data rate). NaN allowed.
%   fs           sample rate (Hz)
%   smoothHours  moving-window length in hours (window = round(3600*fs*smoothHours)
%                samples, centered)
%
% OUTPUT
%   theta        smoothed heading, degrees magnetic in [0, 360), same size as
%                compass_deg. Samples whose window holds no compass value take the
%                nearest smoothed value.
%
% The mean is taken over unit vectors (cos, sin), so a heading that crosses
% 0/360 deg is averaged correctly; a plain moving median of the angle would put
% 359 and 1 deg at 180. Units: degrees throughout.

    c = cosd(compass_deg(:));
    s = sind(compass_deg(:));
    w = max(1, round(3600 * fs * smoothHours));
    cm = movmean(c, w, 'omitnan');
    sm = movmean(s, w, 'omitnan');
    theta = mod(atan2d(sm, cm), 360);
    if any(isnan(theta))
        if all(isnan(theta))
            error('xyz_heading_series:noCompass', 'No compass values to build a heading from.');
        end
        theta = fillmissing(theta, 'nearest');
    end
    theta = reshape(theta, size(compass_deg));
end
