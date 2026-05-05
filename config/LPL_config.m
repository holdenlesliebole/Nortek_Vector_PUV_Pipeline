function cfg = LPL_config(deployment_name)
% LPL_CONFIG  Deployment configs for Los Penasquitos Lagoon (~8m depth).
%
%   cfg = LPL_config('LPL23')
%
%   All deployments are single-instrument, flat layout, continuous 2 Hz.
%   Deployed for S. Giddings (see .hdr comments).
%
%   Note: LPL24 and LPL25A use ENU coordinate system (instrument compass
%   rotation applied internally). LPL23 and LPL25B use XYZ.
%
%   Parameters from DeploymentNotes:
%     heading   = NaN (auto-computed from .sen for XYZ; not needed for ENU)
%     clockDrift = NaN (unknown unless filled from DeploymentNotes)
%     doffp     = NaN (fill from DeploymentNotes before running L2)
%     latlon    = approximate site center (sufficient for mag declination)
% Author: Holden Leslie-Bole, 2026

    cfg.name      = deployment_name;
    cfg.fs        = 2;  % Hz
    cfg.outputDir = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');

    % Approximate lat/lon for LPL site at 8m depth
    lpl_latlon = [32.933, -117.270];

    k = 0;

    switch deployment_name

        case 'LPL23'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/LPL20231205-20240213';
            k = k + 1;
            cfg.instruments(k).label          = 'LPL_8m';
            cfg.instruments(k).filePrefix     = 'LPL-8M02';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0591';  % confirmed from Brian's email: "LPL MOP591 8m"
            cfg.instruments(k).mopLine        = 591;
            cfg.instruments(k).depth_nominal  = 8;
            cfg.instruments(k).serialNum      = 15032;
            cfg.instruments(k).latlon         = lpl_latlon;
            cfg.instruments(k).heading        = NaN;   % auto-compute (XYZ)
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.88;      % meters (88 cm from notes)

        case 'LPL24'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/LPL20241211-20250221';
            k = k + 1;
            cfg.instruments(k).label          = 'LPL_8m';
            cfg.instruments(k).filePrefix     = 'LPL-8M02';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0591';  % confirmed from Brian's email: "LPL MOP591 8m"
            cfg.instruments(k).mopLine        = 591;
            cfg.instruments(k).depth_nominal  = 8;
            cfg.instruments(k).serialNum      = 12412;
            cfg.instruments(k).latlon         = lpl_latlon;
            cfg.instruments(k).heading        = NaN;   % ENU — heading not used
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.75;      % meters (75 cm from notes)

        case 'LPL25A'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/LPL20250305-20250601';
            k = k + 1;
            cfg.instruments(k).label          = 'LPL_8m';
            cfg.instruments(k).filePrefix     = 'LPL-8M02';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0591';  % confirmed from Brian's email: "LPL MOP591 8m"
            cfg.instruments(k).mopLine        = 591;
            cfg.instruments(k).depth_nominal  = 8;
            cfg.instruments(k).serialNum      = 12412;
            cfg.instruments(k).latlon         = lpl_latlon;
            cfg.instruments(k).heading        = NaN;   % ENU — heading not used
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.85;      % meters (85 cm from notes)

        case 'LPL25B'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/LPL20251208-20260225';
            k = k + 1;
            cfg.instruments(k).label          = 'LPL_8m';
            cfg.instruments(k).filePrefix     = 'LPL-8M02';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0591';  % confirmed from Brian's email: "LPL MOP591 8m"
            cfg.instruments(k).mopLine        = 591;
            cfg.instruments(k).depth_nominal  = 8;
            cfg.instruments(k).serialNum      = 12412;
            cfg.instruments(k).latlon         = lpl_latlon;
            cfg.instruments(k).heading        = NaN;   % auto-compute (XYZ)
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.80;      % meters (~80 cm from notes, deploy 12/8/2025)

        otherwise
            error('LPL_config:unknown', ...
                'Unknown deployment: %s. Available: LPL23, LPL24, LPL25A, LPL25B', deployment_name);
    end
end
