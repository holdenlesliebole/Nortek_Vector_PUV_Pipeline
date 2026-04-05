function cfg = TOR24W_config()
% TOR24W_CONFIG  Torrey Pines winter 2024-2025 (Nov 2024 - Feb 2025).
%
%   cfg = TOR24W_config()
%
%   Deployment: Torrey20241125-20250220
%   4 instruments: MOP586 5m/7m/10m/15m (no MOP580 this deployment)
%   All XYZ coordinate system, subfolder layout.

    cfg.name        = 'TOR24W';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/Torrey20241125-20250220';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz

    k = 0;

    % ---- MOP 586, 5m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_5m';
    cfg.instruments(k).filePrefix     = '5M_58602';
    cfg.instruments(k).rawSubfolder   = 'MOP586-5m16739';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 16739;
    cfg.instruments(k).latlon         = [32.930, -117.264];
    cfg.instruments(k).heading        = NaN;   % auto-compute from .sen
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.77;      % meters (77 cm from notes)

    % ---- MOP 586, 7m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_7m';
    cfg.instruments(k).filePrefix     = '7M_58602';
    cfg.instruments(k).rawSubfolder   = 'MOP586-7m16310';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 16310;
    cfg.instruments(k).latlon         = [32.930, -117.265];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.63;      % meters (63 cm from notes)

    % ---- MOP 586, 10m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_10m';
    cfg.instruments(k).filePrefix     = '10M58602';
    cfg.instruments(k).rawSubfolder   = 'MOP586-10m16737';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 10;
    cfg.instruments(k).serialNum      = 16737;
    cfg.instruments(k).latlon         = [32.930, -117.266];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.78;      % meters (78 cm from notes)

    % ---- MOP 586, 15m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_15m';
    cfg.instruments(k).filePrefix     = '15M58602';
    cfg.instruments(k).rawSubfolder   = 'MOP586-15m16737';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 15;
    cfg.instruments(k).serialNum      = 16737;
    cfg.instruments(k).latlon         = [32.930, -117.270];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.75;      % meters (75 cm from notes)

end
