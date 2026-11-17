function cfg = Solana_config(deployment_name)
% SOLANA_CONFIG  Deployment configs for post-NN24 Solana Beach deployments.
%
%   cfg = Solana_config('SOL24')
%
%   All deployments are single-instrument, flat layout, continuous 2 Hz.
%   Located at MOP 654.5, ~7m depth, co-located with EA400 Echologger.
%
%   Note: SOL24 uses ENU coordinate system. SOL25A, SOL25B and SOL26A use XYZ.
%
%   For the winter 2023-24 Solana instruments (MOP651/654, Nov 2023 - Jan 2024),
%   see SOL23_config.m (previously part of NN24).
% Author: Holden Leslie-Bole, 2026

    cfg.name      = deployment_name;
    cfg.fs        = 2;  % Hz
    cfg.outputDir = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.qcOpts.Tvalid = [9 26];  % San Diego coastal; matches the canonical L1 (rerun_*_2026_07_11 injection)
    cfg.tideStation = '9410230';  % NOAA CO-OPS La Jolla (Scripps Institution Wharf), harmonic station; tidal depth in PUV_L3_currents. Same station every catalog L3 used through 2026-10-15 (then hardcoded in toolbox getztide2.m)

    % Approximate lat/lon for Solana Beach MOP 654.5 at 7m depth
    sol_latlon = [32.991, -117.279];

    k = 0;

    switch deployment_name

        case 'SOL24'
            % NOTE: ENU coordinate system
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/Solana20241204-20250220';
            k = k + 1;
            cfg.instruments(k).label          = 'MOP654_7m';
            cfg.instruments(k).filePrefix     = 'MOP65403';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0654';
            cfg.instruments(k).mopLine        = 654.5;
            cfg.instruments(k).depth_nominal  = 7;
            cfg.instruments(k).serialNum      = 17036;
            cfg.instruments(k).latlon         = sol_latlon;
            cfg.instruments(k).heading        = NaN;   % ENU — heading not used
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.89;      % meters (89 cm from notes)

        case 'SOL25A'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/Solana20250305-20250517';
            k = k + 1;
            cfg.instruments(k).label          = 'MOP654_7m';
            cfg.instruments(k).filePrefix     = '7M65402';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0654';
            cfg.instruments(k).mopLine        = 654.5;
            cfg.instruments(k).depth_nominal  = 7;
            cfg.instruments(k).serialNum      = 17036;
            cfg.instruments(k).latlon         = sol_latlon;
            cfg.instruments(k).heading        = NaN;   % compass (XYZ), time-varying: see headingSmoothHours
            % The mount turned during the 2025-04-02 storm: raw .sen (7M65402_2.sen) compass
            % 17.2-17.6 deg until ~11:30 UTC, 13.7-14.2 deg from ~16:00 UTC to the end, with
            % pitch -2.1 -> 0.0 deg over the same hours, so the mount moved, not the compass.
            % Recovery log 13.1 deg magnetic (DeploymentNotes2024-2025.xls 'All Data' row 7,
            % S/N 17036: "+X onshore, 13.1deg magnetic using new compass on 6/24/2025").
            % A single median left the first four weeks ~3.6 deg off (fixed 2026-10-16).
            cfg.instruments(k).headingSmoothHours = 1;   % per-sample compass heading, 1 h circular mean
            cfg.instruments(k).clockDrift     = NaN;   % log: "unknown, clock stopped"; battery died 2025-05-17 (row 7); depth vs NOAA tide lag 0 h, r 0.996 (2026-10-16)
            cfg.instruments(k).doffp          = 0.81;      % meters (81 cm from notes)

        case 'SOL25B'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/Solana20251205-20260225';
            k = k + 1;
            cfg.instruments(k).label          = 'MOP654_7m';
            cfg.instruments(k).filePrefix     = '7M65402';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0654';
            cfg.instruments(k).mopLine        = 654.5;
            cfg.instruments(k).depth_nominal  = 7;
            cfg.instruments(k).serialNum      = 17042;
            cfg.instruments(k).latlon         = sol_latlon;
            cfg.instruments(k).heading        = NaN;   % auto-compute (XYZ)
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 1.00;      % meters (100 cm from notes, deploy 12/8/2025)

        case 'SOL26A'
            % DeploymentNotes2025-2026.xls 'All Data' rows 40-42, S/N 15277:
            % "02/25/2026 - 05/07/2026", 2 Hz; recovery "5sec faster than internet time."
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/Solana20260225-20260508';
            k = k + 1;
            cfg.instruments(k).label          = 'MOP654_7m';
            cfg.instruments(k).filePrefix     = '7M_65402';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0654';
            cfg.instruments(k).mopLine        = 654.5;
            cfg.instruments(k).depth_nominal  = 7;
            cfg.instruments(k).serialNum      = 15277;
            cfg.instruments(k).latlon         = [32.99064, -117.27897];  % row 37 (S/N 17042, same site), carried to row 40 by ditto marks
            cfg.instruments(k).heading        = NaN;   % compass (XYZ); row 40 logs no heading
            cfg.instruments(k).clockDrift     = NaN;   % 5 s fast at recovery (row 42); not applied, as for SOL25B
            cfg.instruments(k).doffp          = 0.77;  % row 40: "77cm sand to PUV pressure port." (72 cm at the 2026-03-26 inspection, row 41; 80 cm on recovery, row 42)

        otherwise
            error('Solana_config:unknown', ...
                'Unknown deployment: %s. Available: SOL24, SOL25A, SOL25B, SOL26A', deployment_name);
    end
end
