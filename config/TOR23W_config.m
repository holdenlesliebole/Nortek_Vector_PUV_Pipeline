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
    cfg.tideStation = '9410230';  % NOAA CO-OPS La Jolla (Scripps Institution Wharf), harmonic station; tidal depth in PUV_L3_currents. Same station every catalog L3 used through 2026-10-15 (then hardcoded in toolbox getztide2.m)
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
    cfg.instruments(k).heading        = 76.5;      % magnetic; DeploymentNotes2023-2024.xls 'All Data' row 9, S/N 17047: "+X onshore, 76.5deg. magnetic."
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
    cfg.instruments(k).heading        = 79.4;      % magnetic; DeploymentNotes2023-2024.xls 'All Data' row 14, S/N 17042: "+X onshore, 79.4deg. magnetic."
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.90;

    % ---- MOP 586, 5m ----
    % Deployed 11/14/2023 - 02/13/2024 (stopped logging 01/17/2024)
    % Beam steps (HLB ruling 2026-11-14; docs/SPEC_L1_beam_step_correction_2026-11-13.md sec. 12):
    % 15 double-step samples (k = +2, beam 2), 2023-12-29 05:54 to 13:50 UTC, cannot be corrected
    % because Delta is not estimable from |k| = 2 edges alone. Flag them unconfirmed so L2 gaps
    % them. They lie in invalid storm hours of the toppled frame: no L2 or L3 number changes.
    cfg.instruments(k).beamStep.flagWhenNoDelta = true;

    k = k + 1;
    cfg.instruments(k).label          = 'MOP586_5m';
    cfg.instruments(k).filePrefix     = '5M_58602';
    cfg.instruments(k).rawSubfolder   = fullfile('Torrey20231114-20240213', 'MOP586-5m17043');
    cfg.instruments(k).mopStation     = 'D0586';
    cfg.instruments(k).mopLine        = 586;
    cfg.instruments(k).depth_nominal  = 5;
    cfg.instruments(k).serialNum      = 17043;
    cfg.instruments(k).latlon         = [32.93056, -117.26319];
    cfg.instruments(k).heading        = 68.2;      % magnetic; DeploymentNotes2023-2024.xls 'All Data' row 20, S/N 17043: "+X onshore, 68.2deg. magnetic."
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
    cfg.instruments(k).heading        = 77.2;      % magnetic; DeploymentNotes2023-2024.xls 'All Data' row 31, S/N 16739: "+X onshore, 77.2deg. magnetic."
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
    cfg.instruments(k).heading        = 75.3;      % magnetic; DeploymentNotes2023-2024.xls 'All Data' row 42, S/N 16306: "+X onshore, 75.3deg. magnetic."
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 1.00;
    % Velocity cutoff (HLB decision 2026-11-13; docs/SPEC_L1_beam_step_correction_2026-11-13.md
    % sec. 11 item 4). From L2 segment 1097 (0-based; midpoint 2023-12-30 15:29:59.5 UTC) the
    % velocity passes L1 QC but is implausible: wave velocity Ub(10 m)/Ub(15 m) reads 0.39 in all
    % 26 paired hours, against 1.30-1.46 (5-95%, median 1.38, 1,029 hours) before, during a storm
    % (morphology_ml deep_transport_map step 2 plan sec. 11.2). Pressure had already failed.
    % L2 treats the velocity as gaps from this time on; pressure is untouched.
    % MOVED 2026-11-19 (HLB) from 15:29 to 03:00 UTC: the same ratio rule on the six paired hours
    % of 30 December gives 1.31-1.38 for segments centred 00:30-02:30 and 0.24-0.27 for 04:30-06:30
    % (03:30 unpaired), so the failure starts between 03:00 and 04:00. 03:00 keeps the last good
    % one-hour segment (02:00-03:00) whole. Paper_2/docs/RESULTS_puv_alt_rerun_2026-11-19.md;
    % rebuild scripts/rebuild_tor23w10m_cutoff_2026_11_19.m.
    cfg.instruments(k).velInvalidFrom = datetime(2023,12,30,3,0,0, 'TimeZone', 'UTC');

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
    cfg.instruments(k).heading        = 40.0;      % magnetic; DeploymentNotes2023-2024.xls 'All Data' row 53, S/N 15277: "+X onshore, 40.0deg. magnetic."
    cfg.instruments(k).clockDrift     = NaN;       % "2 week clock drift!?" - ambiguous
    cfg.instruments(k).doffp          = 1.00;

end
