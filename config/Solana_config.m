function cfg = Solana_config(deployment_name)
% SOLANA_CONFIG  Deployment configs for post-NN24 Solana Beach deployments.
%
%   cfg = Solana_config('SOL24')
%
%   All deployments are single-instrument, flat layout, continuous 2 Hz.
%   Located at MOP 654.5, ~7m depth, co-located with EA400 Echologger.
%
%   Note: SOL24 uses ENU coordinate system. SOL25A and SOL25B use XYZ.
%
%   For NN24-era Solana instruments (MOP651/654, Nov 2023 - Jan 2024),
%   see NN24_config.m.

    cfg.name      = deployment_name;
    cfg.fs        = 2;  % Hz
    cfg.outputDir = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');

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
            cfg.instruments(k).doffp          = NaN;

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
            cfg.instruments(k).heading        = NaN;   % auto-compute (XYZ)
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = NaN;

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
            cfg.instruments(k).doffp          = NaN;

        otherwise
            error('Solana_config:unknown', ...
                'Unknown deployment: %s. Available: SOL24, SOL25A, SOL25B', deployment_name);
    end
end
