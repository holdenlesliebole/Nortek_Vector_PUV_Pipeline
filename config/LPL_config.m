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
    cfg.qcOpts.Tvalid = [9 26];  % San Diego coastal; matches the canonical L1 (rerun_*_2026_07_11 injection)
    cfg.tideStation = '9410230';  % NOAA CO-OPS La Jolla (Scripps Institution Wharf), harmonic station; tidal depth in PUV_L3_currents. Same station every catalog L3 used through 2026-10-15 (then hardcoded in toolbox getztide2.m)

    % Surveyed position of the Los Penasquitos offshore station. Stable across
    % 2019-2026 in the field logs (same jetted pipe reused each season):
    % DeploymentNotes{2019-2020,2020-2021,2023-2024,2024-2025,2025-2026}.xls
    % 'All Data', rows "Los Pen ... Vector". The earlier [32.933 -117.270] was
    % an eyeballed placeholder 453 m to the SW. Note this is the SAME station
    % as TorreyOffshore_config, which already carried it correctly.
    lpl_latlon = [32.934436, -117.26546];

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
            cfg.instruments(k).heading        = NaN;   % auto-compute (XYZ); compass median 82.0. NO USABLE LOG VALUE: DeploymentNotes2023-2024.xls 'All Data' row 75, "LosPen 8m Offshore PUV Vector" S/N 15032: "+X onshore, 96.7deg. magnetic." repeats Solana 5m row 64; probable template copy (see shared/heading_disputed_records.m)
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.88;      % meters (88 cm from notes). CAVEAT: DeploymentNotes2023-2024.xls 'All Data' row 75 (S/N 15032) "88cm sand to PUV pressure port on deployment." is identical to Solana 5m row 64 in this cell and the heading cell, so it may be a template copy; plausible against the record's own 78 cm (01/18/2024 inspection, row 76) and 87 cm (recovery, row 77), but unconfirmed

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
