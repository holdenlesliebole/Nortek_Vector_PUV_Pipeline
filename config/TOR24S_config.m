function cfg = TOR24S_config()
% TOR24S_CONFIG  Torrey Pines spring 2024 (Feb-May 2024).
%
%   cfg = TOR24S_config()
%
%   Deployment: Torrey20240228-20240510
%   5 instruments: MOP580-7m, MOP586 5m/7m/10m/15m
%   All XYZ coordinate system, subfolder layout.

    cfg.name        = 'TOR24S';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/Torrey20240228-20240510';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz

    k = 0;

    % ---- MOP 580, 7m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP580_7m';
    cfg.instruments(k).filePrefix     = '7M_58002';
    cfg.instruments(k).rawSubfolder   = 'MOP580-7m17042';
    cfg.instruments(k).mopStation     = 'D0580';
    cfg.instruments(k).mopLine        = 580;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 17042;
    cfg.instruments(k).latlon         = [32.925, -117.264];
    cfg.instruments(k).heading        = NaN;   % auto-compute from .sen
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.72;      % meters (72 cm, redeploy 2/28/2024)

    % ---- MOP 586, 5m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_5m';
    cfg.instruments(k).filePrefix     = '5M_58602';
    cfg.instruments(k).rawSubfolder   = 'MOP586-5m16737';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 16737;
    cfg.instruments(k).latlon         = [32.930, -117.264];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.63;      % meters (63 cm, redeploy 2/28/2024)

    % ---- MOP 586, 7m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_7m';
    cfg.instruments(k).filePrefix     = '7M_58602';
    cfg.instruments(k).rawSubfolder   = 'MOP586-7m16739';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 16739;
    cfg.instruments(k).latlon         = [32.930, -117.265];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.70;      % meters (70 cm, redeploy 2/28/2024)

    % ---- MOP 586, 10m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_10m';
    cfg.instruments(k).filePrefix     = '10M58602';
    cfg.instruments(k).rawSubfolder   = 'MOP586-10m15033';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 10;
    cfg.instruments(k).serialNum      = 15033;
    cfg.instruments(k).latlon         = [32.930, -117.266];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.79;      % meters (79 cm, redeploy 2/28/2024)

    % ---- MOP 586, 15m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_15m';
    cfg.instruments(k).filePrefix     = '15M58602';
    cfg.instruments(k).rawSubfolder   = 'MOP586-15m15277';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 15;
    cfg.instruments(k).serialNum      = 15277;
    cfg.instruments(k).latlon         = [32.930, -117.270];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.74;      % meters (74 cm, redeploy 2/28/2024)

end
