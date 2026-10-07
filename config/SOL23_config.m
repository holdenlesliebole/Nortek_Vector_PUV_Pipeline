function cfg = SOL23_config()
% SOL23_CONFIG  Solana Beach winter 2023-2024 (Nov 2023 - Jan 2024).
%
%   cfg = SOL23_config()
%
%   Deployment: Nov 2023 - Jan 2024, 3 instruments at MOP651 and MOP654.5.
%   Part of the El Nino and Beach Nourishment campaign, previously bundled
%   as NN24 with the Torrey Pines instruments.
%
%   MOP651_5m failed (battery depleted, pipe bent, recovered 12/08/2025).
%
%   Source: DeploymentNotes2023-2024.xls, sheet 'All Data'
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'SOL23';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.qcOpts.Tvalid = [9 26];  % San Diego coastal; matches the canonical L1 (rerun_*_2026_07_11 injection)
    cfg.fs          = 2;  % Hz

    k = 0;

    % ---- MOP 651, 5m ----
    % Deployed 11/15/2023 - 01/28/2024
    % Battery depleted. Found and recovered 12/08/2025 with bent pipe.
    k = k + 1;
    cfg.instruments(k).label          = 'MOP651_5m';
    cfg.instruments(k).filePrefix     = '5M_65102';
    cfg.instruments(k).rawSubfolder   = 'Solana20231115-20240128MOP651';
    cfg.instruments(k).mopStation     = 'D0651';
    cfg.instruments(k).mopLine        = 651;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 17045;
    cfg.instruments(k).latlon         = [32.98754, -117.27687];
    cfg.instruments(k).heading        = 96.7;      % magnetic; DeploymentNotes2023-2024.xls 'All Data' row 64, S/N 17045: "+X onshore, 96.7deg. magnetic."
    cfg.instruments(k).clockDrift     = NaN;       % battery depleted
    cfg.instruments(k).doffp          = 0.88;

    % ---- MOP 651, 7m ----
    % Deployed 11/16/2023 - 01/18/2024
    k = k + 1;
    cfg.instruments(k).label          = 'MOP651_7m';
    cfg.instruments(k).filePrefix     = '7M651_16310';
    cfg.instruments(k).rawSubfolder   = fullfile('Solana20231116-20240118', 'MOP651_7m16310');
    cfg.instruments(k).mopStation     = 'D0651';
    cfg.instruments(k).mopLine        = 651;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 16310;
    cfg.instruments(k).latlon         = [32.98734, -117.27816];
    cfg.instruments(k).heading        = 56.0;      % magnetic; DeploymentNotes2023-2024.xls 'All Data' row 67, S/N 16310: "+X onshore, 56.0deg. magnetic." (diver; onboard compass reads 64.0 before the 12/28/2023 storm)
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 1.09;

    % ---- MOP 654.5, 7m ----
    % Deployed 11/16/2023 - 01/18/2024
    k = k + 1;
    cfg.instruments(k).label          = 'MOP654_7m';
    cfg.instruments(k).filePrefix     = '7M654_17036';
    cfg.instruments(k).rawSubfolder   = fullfile('Solana20231116-20240118', 'MOP654_7m17036');
    cfg.instruments(k).mopStation     = 'D0654';
    cfg.instruments(k).mopLine        = 654.5;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 17036;
    cfg.instruments(k).latlon         = [32.99064, -117.27897];
    cfg.instruments(k).heading        = 69.6;      % magnetic; DeploymentNotes2023-2024.xls 'All Data' row 70, S/N 17036: "+X onshore, 69.6deg. magnetic." (diver; onboard compass reads 79.3 before the tip logged in row 72, "Started to slightly tilt around 12 28 2023 22:04")
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 1.08;

end
