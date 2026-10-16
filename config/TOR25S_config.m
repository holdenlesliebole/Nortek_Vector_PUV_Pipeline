function cfg = TOR25S_config()
% TOR25S_CONFIG  Torrey Pines spring 2025 (Mar-Jun 2025).
%
%   cfg = TOR25S_config()
%
%   This deployment spans two server folders:
%     - Torrey20250305-20250512: 10m and 15m in subfolders
%     - Torrey20250326-20250601: 5m in flat layout (deployed 3 weeks later)
%
%   7m instrument failed (<1 day of data) — excluded from config.
%   10m and 15m ran 68 days (battery died early; predicted 99 days).
%   5m and Solana 7m still deployed as of June 2025; recovery ~6/24/2025.
%
%   rawDataRoot points to the parent /Volumes/group/PUV_data/Vector/ to
%   accommodate both folders.
%
%   All XYZ coordinate system.
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'TOR25S';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.qcOpts.Tvalid = [9 26];  % San Diego coastal; matches the canonical L1 (rerun_*_2026_07_11 injection)
    cfg.tideStation = '9410230';  % NOAA CO-OPS La Jolla (Scripps Institution Wharf), harmonic station; tidal depth in PUV_L3_currents. Same station every catalog L3 used through 2026-10-15 (then hardcoded in toolbox getztide2.m)
    cfg.fs          = 2;  % Hz

    k = 0;

    % ---- MOP 586, 5m ----
    % Flat layout in Torrey20250326-20250601/
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_5m';
    cfg.instruments(k).knownFailed    = 'no valid pressure data; pipe bent, kelp blockage; docs/deployment_database_overview.md (TOR25S MOP586_5m row)';
    cfg.instruments(k).filePrefix     = '5M_58602';
    cfg.instruments(k).rawSubfolder   = 'Torrey20250326-20250601';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 15033;
    cfg.instruments(k).latlon         = [32.93056, -117.26319];   % surveyed; DeploymentNotes2024-2025.xls 'All Data' "Torrey Pines 5m MOP586 PUV Vector" -- same jetted pipe reused, was [32.930 -117.264] (98 m off)
    cfg.instruments(k).heading        = NaN;   % auto-compute from .sen
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.63;      % meters (63 cm, redeploy 3/26/2025)

    % ---- MOP 586, 10m ----
    % Subfolder in Torrey20250305-20250512/
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_10m';
    cfg.instruments(k).filePrefix     = '10M58603';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20250305-20250512', 'MOP586-10m16737');
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 10;
    cfg.instruments(k).serialNum      = 16737;
    cfg.instruments(k).latlon         = [32.93035, -117.26572];   % surveyed; DeploymentNotes2024-2025.xls 'All Data' "Torrey Pines 10m MOP586 PUV Vector" -- same jetted pipe reused, was [32.930 -117.266] (47 m off)
    cfg.instruments(k).heading        = NaN;   % auto-compute. compass median 235.9 kept. NOT DISPUTED: the only log value, DeploymentNotes2024-2025.xls 'All Data' row 36, S/N 16737: "+X onshore, 286.6deg magnetic using new compass on 6/5/2025.", puts waves 44 deg off the shore-normal (compass: 6.4 deg; reciprocal: from shore). PUV-only check, see shared/heading_disputed_records.m
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.86;      % meters (86 cm, redeploy 3/5/2025)

    % ---- MOP 586, 15m ----
    % Subfolder in Torrey20250305-20250512/
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_15m';
    cfg.instruments(k).filePrefix     = '15M58603';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20250305-20250512', 'MOP586-15m17047');
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 15;
    cfg.instruments(k).serialNum      = 17047;
    cfg.instruments(k).latlon         = [32.93005, -117.26950];   % surveyed; DeploymentNotes2024-2025.xls 'All Data' "Torrey Pines 15m MOP586 PUV Vector" -- same jetted pipe reused, was [32.930 -117.270] (47 m off)
    cfg.instruments(k).heading        = NaN;   % auto-compute. DISPUTED (|log - compass| > 10 deg; value left on the compass median; reported via shared/heading_disputed_records.m): DeploymentNotes2024-2025.xls 'All Data' row 40, S/N 17047: "+X onshore, 34.2deg magnetic using new compass on 6/5/2025."; compass median 46.1
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.80;      % meters (80 cm, redeploy 3/5/2025)

    % 7m instrument failed after <1 day — no usable data. Excluded.

end
