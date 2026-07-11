function cfg = TOR23W_config()
% TOR23W_CONFIG  Torrey Pines winter 2023-2024 (Nov 2023 - Feb 2024).
%
%   cfg = TOR23W_config()
%
%   Deployment: Nov 2023 - Feb 2024, 6 instruments across MOP580 and MOP586
%   at 5m to 15m depth. Part of the El Nino and Beach Nourishment campaign,
%   previously bundled as NN24 with the Solana Beach instruments.
%
%   Source: DeploymentNotes2023-2024.xls, sheet 'All Data'
%
%   Notes on rawDataRoot:
%     Spans multiple deployment folders (different recovery dates), so
%     rawDataRoot is set to the common parent directory. Each instrument's
%     rawSubfolder includes the deployment folder name.
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'TOR23W';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector';

    % San Diego coastal water-temperature range (deg C): the thermistor-failure
    % discriminant. Catches the subtle within-bounds sensor-block failures (a December
    % reading below ~9 C at Torrey Pines is not real water) without mis-flagging genuine
    % seasonal/upwelling temperatures. See docs/PUV_Pipeline_Guide.pdf sec 5.
    cfg.qcOpts.Tvalid = [9 26];
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz

    k = 0;

    % ---- MOP 580, 5m ----
    % Deployed 11/14/2023 - 05/10/2024 (battery depleted)
    k = k + 1;
    cfg.instruments(k).label          = 'MOP580_5m';
    cfg.instruments(k).filePrefix     = 'TORREY02';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240118', 'MOP580-5m17047');
    cfg.instruments(k).mopStation     = 'D0580';
    cfg.instruments(k).mopLine        = 580;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 17047;
    cfg.instruments(k).latlon         = [32.92514, -117.26221];
    cfg.instruments(k).heading        = 76.5;
    cfg.instruments(k).clockDrift     = NaN;       % battery depleted
    cfg.instruments(k).doffp          = 0.60;

    % ---- MOP 580, 7m ----
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
    cfg.instruments(k).heading        = 79.4;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.90;

    % ---- MOP 586, 5m ----
    % Deployed 11/14/2023 - 02/13/2024 (stopped logging 01/17/2024)
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_5m';
    cfg.instruments(k).filePrefix     = '5M_58602';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240213', 'MOP586-5m17043');
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 17043;
    cfg.instruments(k).latlon         = [32.93056, -117.26319];
    cfg.instruments(k).heading        = 68.2;
    cfg.instruments(k).clockDrift     = 5.0;       % 5 sec faster than internet time
    cfg.instruments(k).doffp          = 0.65;

    % ---- MOP 586, 7m ----
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
    cfg.instruments(k).heading        = 77.2;
    cfg.instruments(k).clockDrift     = 6.0;       % 6 sec faster than internet time
    cfg.instruments(k).doffp          = 0.67;

    % ---- MOP 586, 10m ----
    % Deployed 11/14/2023 - 01/18/2024
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_10m';
    cfg.instruments(k).filePrefix     = '10M586_16306';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240118', 'MOP586_10m16306');
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 10;
    cfg.instruments(k).serialNum      = 16306;
    cfg.instruments(k).latlon         = [32.93035, -117.26572];
    cfg.instruments(k).heading        = 75.3;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 1.00;

    % ---- MOP 586, 15m ----
    % Deployed 11/14/2023 - 02/13/2024
    % Heading shifted ~3deg during 12/28 storm event.
    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_15m';
    cfg.instruments(k).filePrefix     = '15M58602';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240213', 'MOP586-15m15277');
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 15;
    cfg.instruments(k).serialNum      = 15277;
    cfg.instruments(k).latlon         = [32.93005, -117.26950];
    cfg.instruments(k).heading        = 40.0;
    cfg.instruments(k).clockDrift     = NaN;       % "2 week clock drift!?" - ambiguous
    cfg.instruments(k).doffp          = 1.00;

end
