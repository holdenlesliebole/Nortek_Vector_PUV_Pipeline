function cfg = NN24_config()
% NN24_CONFIG  Deployment configuration for Nortek November 2023-2024 (winter).
%
%   cfg = NN24_config()
%
%   Deployment: Nov 2023 - Feb 2024, Torrey Pines and Solana Beach.
%   Multiple MOP lines, 5m-15m depth range.
%
%   Source: DeploymentNotes2023-2024.xls, sheet 'All Data'
%   File prefixes verified against raw data on lab server.
%   LosPen instruments excluded (different site, not needed for Paper 1).
%
%   Notes on rawDataRoot:
%     Because NN24 spans multiple deployment folders (different recovery
%     dates), rawDataRoot is set to the common parent directory. Each
%     instrument's rawSubfolder includes the deployment folder name.
%
%   Clock drift parsing:
%     "X sec faster than internet time" -> X seconds
%     Battery depleted / blank / ambiguous -> NaN
%
%   Heading parsing:
%     "+X onshore, XX.Xdeg. magnetic." -> XX.X degrees

    cfg.name        = 'NN24';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz

    k = 0;

    % ---- Torrey Pines MOP 580, 5m ----
    % Deployed 11/14/2023 - 05/10/2024 (but battery depleted)
    % NOTE: File prefix is 'TORREY02' (unusual naming convention)
    k = k + 1;
    cfg.instruments(k).label          = 'MOP580_5m';
    cfg.instruments(k).filePrefix     = 'TORREY02';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240118', 'MOP580-5m17047');
    cfg.instruments(k).mopStation     = 'D0580';
    cfg.instruments(k).mopLine        = 580;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 17047;
    cfg.instruments(k).latlon         = [32.92514, -117.26221];
    cfg.instruments(k).heading        = 76.5;      % magnetic, degrees
    cfg.instruments(k).clockDrift     = NaN;       % battery depleted, no value
    cfg.instruments(k).doffp          = 0.60;      % meters (60 cm from notes)

    % ---- Torrey Pines MOP 580, 7m ----
    % Deployed 11/14/2023 - 01/18/2024
    k = k + 1;
    cfg.instruments(k).label          = 'MOP580_7m';
    cfg.instruments(k).filePrefix     = '7M580_17042';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240118', 'MOP580_7m17042');
    cfg.instruments(k).mopStation     = 'D0580';
    cfg.instruments(k).mopLine        = 580;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 17042;
    cfg.instruments(k).latlon         = [32.92505, -117.26320];
    cfg.instruments(k).heading        = 79.4;      % magnetic, degrees
    cfg.instruments(k).clockDrift     = NaN;       % blank in notes
    cfg.instruments(k).doffp          = 0.90;      % meters (90 cm from notes)

    % ---- Torrey Pines MOP 586, 5m ----
    % Deployed 11/14/2023 - 2/13/2024 (stopped logging 01/17/2024)
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_5m';
    cfg.instruments(k).filePrefix     = '5M_58602';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240213', 'MOP586-5m17043');
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 17043;
    cfg.instruments(k).latlon         = [32.93056, -117.26319];
    cfg.instruments(k).heading        = 68.2;      % magnetic, degrees
    cfg.instruments(k).clockDrift     = 5.0;       % 5 sec faster than internet time
    cfg.instruments(k).doffp          = 0.65;      % meters (65 cm from notes)

    % ---- Torrey Pines MOP 586, 7m ----
    % Deployed 11/14/2023 - 01/18/2024
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_7m';
    cfg.instruments(k).filePrefix     = '7M_58602';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240118', 'MOP586-7m16739');
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 16739;
    cfg.instruments(k).latlon         = [32.93048, -117.26420];
    cfg.instruments(k).heading        = 77.2;      % magnetic, degrees
    cfg.instruments(k).clockDrift     = 6.0;       % 6 sec faster than internet time
    cfg.instruments(k).doffp          = 0.67;      % meters (67 cm from notes)

    % ---- Torrey Pines MOP 586, 10m ----
    % Deployed 11/14/2023 - 01/18/2024
    % NOTE: Single deployment file (no _N suffix in file prefix)
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_10m';
    cfg.instruments(k).filePrefix     = '10M586_16306';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240118', 'MOP586_10m16306');
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 10;
    cfg.instruments(k).serialNum      = 16306;
    cfg.instruments(k).latlon         = [32.93035, -117.26572];
    cfg.instruments(k).heading        = 75.3;      % magnetic, degrees
    cfg.instruments(k).clockDrift     = NaN;       % blank in notes
    cfg.instruments(k).doffp          = 1.00;      % meters (100 cm from notes)

    % ---- Torrey Pines MOP 586, 15m ----
    % Deployed 11/14/2023 - 02/13/2024
    % NOTE: Heading shifted ~3deg during 12/28 storm event.
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_15m';
    cfg.instruments(k).filePrefix     = '15M58602';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240213', 'MOP586-15m15277');
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 15;
    cfg.instruments(k).serialNum      = 15277;
    cfg.instruments(k).latlon         = [32.93005, -117.26950];
    cfg.instruments(k).heading        = 40.0;      % magnetic, degrees
    cfg.instruments(k).clockDrift     = NaN;       % "2 week clock drift!?" - ambiguous
    cfg.instruments(k).doffp          = 1.00;      % meters (100 cm from notes)

    % ---- Solana Beach MOP 651, 5m ----
    % Deployed 11/15/2023 - 01/28/2024
    % NOTE: Flat deployment (no subfolders). Battery depleted.
    % Found and recovered 12/08/2025 (two years later).
    k = k + 1;
    cfg.instruments(k).label          = 'MOP651_5m';
    cfg.instruments(k).filePrefix     = '5M_65102';
    cfg.instruments(k).rawSubfolder   = 'Solana20231115-20240128MOP651';
    cfg.instruments(k).mopStation     = 'D0651';
    cfg.instruments(k).mopLine        = 651;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 17045;
    cfg.instruments(k).latlon         = [32.98754, -117.27687];
    cfg.instruments(k).heading        = 96.7;      % magnetic, degrees
    cfg.instruments(k).clockDrift     = NaN;       % battery depleted, no value
    cfg.instruments(k).doffp          = 0.88;      % meters (88 cm from notes)

    % ---- Solana Beach MOP 651, 7m ----
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
    cfg.instruments(k).heading        = 56.0;      % magnetic, degrees
    cfg.instruments(k).clockDrift     = NaN;       % blank in notes
    cfg.instruments(k).doffp          = 1.09;      % meters (109 cm from notes)

    % ---- Solana Beach MOP 654.5, 7m ----
    % Deployed 11/16/2023 - 01/18/2024
    k = k + 1;
    cfg.instruments(k).label          = 'MOP654_7m';
    cfg.instruments(k).filePrefix     = '7M654_17036';
    cfg.instruments(k).rawSubfolder   = fullfile('Solana20231116-20240118', 'MOP654_7m17036');
    cfg.instruments(k).mopStation     = 'D0654';   % MOP 654.5 rounded to D0654
    cfg.instruments(k).mopLine        = 654.5;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 17036;
    cfg.instruments(k).latlon         = [32.99064, -117.27897];
    cfg.instruments(k).heading        = 69.6;      % magnetic, degrees
    cfg.instruments(k).clockDrift     = NaN;       % blank in notes
    cfg.instruments(k).doffp          = 1.08;      % meters (108 cm from notes)

end
