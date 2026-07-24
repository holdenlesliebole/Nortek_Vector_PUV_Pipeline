function cfg = TorreyOffshore_config(deployment_name)
% TORREYOFFSHORE_CONFIG  The Torrey Pines / Los Peñasquitos-mouth offshore
% station, 2014--2021.
%
%   cfg = TorreyOffshore_config('TOR15A')
%
%   One Nortek Vector sat at a single offshore station (~32.9344, -117.2654,
%   ~8--9 m) every winter from 2014 through 2021, swapped every 5--6 weeks. This
%   is the offshore station near the mouth of Los Peñasquitos Lagoon, which sits
%   within Torrey Pines State Beach (~MOP590); the lab logged it as "Torrey
%   offshore" in 2015--2018 and "Los Pen offshore" in 2019--2021 — the same
%   physical station under two names. It is NOT the MOP580/586 nearshore array
%   (TBR23, TOR2xS/W) nor the MOP582 10 m station (TOR19W/TOR20W); those are
%   different sites that happen to share the "Torrey" label.
%
%   NAMING. TOR + <season-start-year, 2 digits> + <deployment ordinal within
%   that winter, A/B/C/D>, from the PUV inventory (PandPUV2015-2025.xlsx). Only
%   the deployments actually present in the archive appear, so a season's
%   letters can have gaps (2015-16 has A, B, D; the C instrument is not in the
%   archive). The A ordinal on the single 2019-20 / 2020-21 winters
%   deliberately does NOT collide with TOR19W/TOR20W, which are the MOP582 10 m
%   station.
%
%   PROVENANCE OF RAW DATA. The 2015--2018 deployments that were also held in
%   their own top-level recopied/ folders (TOR15A/B, TOR16B, TOR17D) read from
%   there; the rest read from the multi-year CPG archive under
%   recopied/Sarah_LPL_2014-2023/<season>/Raw Data/<YYMMDD>_deployment/. Both
%   are the same station.
%
%   INGEST. Raw .VEC/.vec/.049 binary, firmware 1.21. Two firmware quirks,
%   both handled automatically (see PUV_raw_process and read_VEC):
%     1. Sample rate is 2 Hz even though the User Configuration implies 8 Hz;
%        read_VEC measures it from the records.
%     2. The clock runs from a wrong epoch (2000/2002); it is recovered from the
%        MMDDHHMM filenames via clockSource='filename' + deployYear. Recovered
%        spans match the logged deployment dates.
%
%   doffp is not recorded for the older years; 0.63 m is carried from the
%   2019-2020 notes for this station's upward-looking frame ("Pressure port
%   63cm above sand"). The Hs sensitivity is well under 1% (cosh(k*doffp)=1.0005
%   at 8 m, 14 s swell); it shifts the reported water depth one-for-one.
% Author: Holden Leslie-Bole, 2026

    server = '/Volumes/group/PUV_data/Vector/recopied';
    sarah  = fullfile(server, 'Sarah_LPL_2014-2023');

    % name -> {rawDataRoot, rawSubfolder, serial, deployYear}
    % rawSubfolder is appended to rawDataRoot (and to the local raw_cache root).
    reg = containers.Map();
    % --- deployments also held in their own top-level recopied/ folders ---
    reg('TOR15A') = {server, 'Torrey1181_2015', 1181, 2015};   % 2015-16 #1
    reg('TOR15B') = {server, 'Torrey1053_2016', 1053, 2016};   % 2015-16 #2
    reg('TOR16B') = {server, 'Torrey1049_2017', 1049, 2017};   % 2016-17 #2
    reg('TOR17D') = {server, 'Torrey0806_2018',  806, 2018};   % 2017-18 #4
    % --- from the multi-year CPG archive (Sarah_LPL_2014-2023) ---
    reg('TOR14A') = {fullfile(sarah,'2014-2015','Raw Data'), '141209_deployment', 1181, 2014}; % 2014-15 #1
    reg('TOR14B') = {fullfile(sarah,'2014-2015','Raw Data'), '150127_deployment',  475, 2015}; % 2014-15 #2
    reg('TOR14C') = {fullfile(sarah,'2014-2015','Raw Data'), '150306_deployment',  806, 2015}; % 2014-15 #3
    reg('TOR15D') = {fullfile(sarah,'2015-2016','Raw Data'), '160331_deployment',  824, 2016}; % 2015-16 #4
    reg('TOR16A') = {fullfile(sarah,'2016-2017','Raw Data'), '161130_deployment',  824, 2016}; % 2016-17 #1
    reg('TOR16C') = {fullfile(sarah,'2016-2017','Raw Data'), '170209_deployment',  824, 2017}; % 2016-17 #3
    reg('TOR16D') = {fullfile(sarah,'2016-2017','Raw Data'), '170321_deployment', 1049, 2017}; % 2016-17 #4
    reg('TOR17A') = {fullfile(sarah,'2017-2018','Raw Data'), '171129_deployment', 1049, 2017}; % 2017-18 #1
    reg('TOR17B') = {fullfile(sarah,'2017-2018','Raw Data'), '180108_deployment',  806, 2018}; % 2017-18 #2
    reg('TOR17C') = {fullfile(sarah,'2017-2018','Raw Data'), '180212_deployment', 1049, 2018}; % 2017-18 #3
    reg('TOR18A') = {fullfile(sarah,'2018-2019','Raw Data'), '181221_deployment', 1049, 2018}; % 2018-19 #1
    reg('TOR19A') = {fullfile(sarah,'2019-2020','Raw Data'), '',                   806, 2019};  % 2019-20 "Los Pen"
    reg('TOR20A') = {fullfile(sarah,'2020-2021','Raw Data'), '',                  1053, 2020};  % 2020-21 "Los Pen"

    if ~isKey(reg, deployment_name)
        error('TorreyOffshore_config:unknownDeployment', ...
            'Unknown deployment "%s". Valid: %s.', ...
            deployment_name, strjoin(keys(reg), ', '));
    end
    row = reg(deployment_name);

    cfg.name        = deployment_name;
    cfg.fs          = 2;   % Hz — measured from the records
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.rawDataRoot = row{1};

    cfg.qcOpts.Tvalid       = [9 26];   % San Diego coastal
    cfg.qcOpts.cutoffGapSec = 60;       % clear the benign per-file firmware-1.21 hiccups

    k = 1;
    cfg.instruments(k).label         = 'MOP591_9m';
    cfg.instruments(k).mopStation    = 'D0591';
    cfg.instruments(k).mopLine       = 591;
    cfg.instruments(k).latlon        = [32.93443, -117.26544];
    cfg.instruments(k).heading       = NaN;    % XYZ; auto-compute from .sen compass
    cfg.instruments(k).clockDrift    = NaN;     % handled by the filename clock recovery
    cfg.instruments(k).doffp         = 0.63;    % m — station frame, see header
    cfg.instruments(k).depth_nominal = 9;
    cfg.instruments(k).rawFormat     = 'VEC';
    cfg.instruments(k).clockSource   = 'filename';
    cfg.instruments(k).rawSubfolder  = row{2};
    cfg.instruments(k).filePrefix    = '';
    cfg.instruments(k).serialNum     = row{3};
    cfg.instruments(k).deployYear    = row{4};
end
