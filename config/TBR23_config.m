function cfg = TBR23_config()
% TBR23_CONFIG  Deployment configuration for Torrey Black's Rock Summer 2023.
%
%   cfg = TBR23_config()
%
%   Deployment: May-August 2023, Torrey Pines State Beach
%   MOP lines 580 and 586, each with 5m and 7m instruments.
%
%   Source: TBR23_Notes.xlsx (lat/lon, heading, clock drift, doffp)
%   File prefixes verified against raw data on lab server.
%
%   Serial numbers: Taken from raw data folder names. Note that the file
%   prefix numbers (e.g., 58602) may be Nortek probe IDs rather than
%   instrument serial numbers. The folder-name serials (e.g., 17042) match
%   redeployments in the TOR23W winter deployment notes.
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'TBR23';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/Torrey20230503-20230816';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz

    k = 0;

    % ---- MOP 580, 5m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP580_5m';
    cfg.instruments(k).filePrefix     = '5m_16739_MOP580';
    cfg.instruments(k).rawSubfolder   = 'MOP580-5m16739';
    cfg.instruments(k).mopStation     = 'D0580';
    cfg.instruments(k).mopLine        = 580;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 16739;
    cfg.instruments(k).latlon         = [32.92515, -117.26257];
    cfg.instruments(k).heading        = 270.7361;  % magnetic, degrees
    cfg.instruments(k).clockDrift     = 16.6;      % seconds
    cfg.instruments(k).doffp          = 0.77;      % meters, pressure sensor height above bed

    % ---- MOP 580, 7m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP580_7m';
    cfg.instruments(k).filePrefix     = '7M_58002_MOP580';
    cfg.instruments(k).rawSubfolder   = 'MOP580-7m58002';
    cfg.instruments(k).mopStation     = 'D0580';
    cfg.instruments(k).mopLine        = 580;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 58002;     % possibly probe ID, not instrument S/N
    cfg.instruments(k).latlon         = [32.92505, -117.26361];
    cfg.instruments(k).heading        = 83.6136;   % magnetic, degrees
    cfg.instruments(k).clockDrift     = 9.8;       % seconds
    cfg.instruments(k).doffp          = 0.77;      % meters

    % ---- MOP 586, 5m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_5m';
    cfg.instruments(k).filePrefix     = '5M_58602_MOP586';
    cfg.instruments(k).rawSubfolder   = 'MOP586-5m17042';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 17042;     % from folder name; file prefix uses 58602
    cfg.instruments(k).latlon         = [32.93051, -117.26342];
    cfg.instruments(k).heading        = 84.9583;   % magnetic, degrees
    cfg.instruments(k).clockDrift     = 4.4;       % seconds
    cfg.instruments(k).doffp          = 0.76;      % meters

    % ---- MOP 586, 7m ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_7m';
    cfg.instruments(k).filePrefix     = '7M_58602_MOP586';
    cfg.instruments(k).rawSubfolder   = 'MOP586-7m58602';
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 58602;     % possibly probe ID, not instrument S/N
    cfg.instruments(k).latlon         = [32.93047, -117.26464];
    cfg.instruments(k).heading        = 270.7776;  % magnetic, degrees
    cfg.instruments(k).clockDrift     = 11.3;      % seconds
    cfg.instruments(k).doffp          = 0.75;      % meters

end
