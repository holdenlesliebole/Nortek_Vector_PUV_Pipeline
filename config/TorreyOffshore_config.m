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
    % Heading: normally NaN = auto-compute from the .sen compass. Three
    % deployments need an explicit override -- see headingFix below.
    cfg.instruments(k).heading       = NaN;    % XYZ; auto-compute from .sen compass

    % ---- HEADING OVERRIDES (added 2026-07-27) -------------------------------
    % Three 2016-17 deployments were processed with a compass heading that does
    % not reflect the instrument's true orientation. Divers mount these units in
    % near-zero visibility and the housing is close to rotationally symmetric, so
    % a misalignment of any angle is possible; the compass reading additionally
    % failed to capture it (a physically rotated instrument with a working
    % compass would still rotate correctly, so the compass itself was stuck,
    % obstructed, or magnetically disturbed).
    %
    % TWO INDEPENDENT ESTIMATES OF EACH OFFSET, agreeing to <= 1.5 deg:
    %   (a) the L1 compass heading relative to the clean TOR16A deployment
    %       (88.8 deg, same site, and for TOR16C the SAME instrument S/N 824)
    %   (b) the circular median of (PUV wave direction - MOP wave direction),
    %       shore-relative, over the swell band
    %
    %   deploy   L1 sensor   (a) vs TOR16A   (b) vs MOP   applied
    %   TOR16B     198.0        109.2          110.7      -110.7  (empirical)
    %   TOR16C     268.4        179.6          179.2      -180.0  (exact)
    %   TOR16D     265.2        176.4          177.4      -180.0  (exact)
    %
    % C and D are set to EXACTLY 180 so the correction is independent of MOP --
    % 180 is a discrete, physically meaningful misalignment and both independent
    % estimates land within 3.6 deg of it. B has no such round value, so its
    % correction is the empirical offset; it is corroborated by the compass
    % estimate (109.2) but is partly MOP-referenced. See the caveat in
    % ../../PUV_paper/docs/findings_consequences_2026-07-25.md.
    %
    % Detected by validation/sweep_heading_flips.m; controls confirm the two
    % flips fixed in May 2026 (TBR23/MOP580_5m, TOR24S/MOP586_7m) now read clean.
    headingFix = containers.Map( ...
        {'TOR16B','TOR16C','TOR16D'}, ...
        {198.0 - 110.7,  268.4 - 180.0,  265.2 - 180.0});
    if isKey(headingFix, deployment_name)
        cfg.instruments(k).heading = mod(headingFix(deployment_name), 360);
    end
    % ------------------------------------------------------------------------
    cfg.instruments(k).clockDrift    = NaN;     % handled by the filename clock recovery
    cfg.instruments(k).doffp         = 0.63;    % m — station frame, see header
    cfg.instruments(k).depth_nominal = 9;
    cfg.instruments(k).rawFormat     = 'VEC';
    cfg.instruments(k).clockSource   = 'filename';
    cfg.instruments(k).rawSubfolder  = row{2};
    cfg.instruments(k).filePrefix    = '';
    cfg.instruments(k).serialNum     = row{3};
    cfg.instruments(k).deployYear    = row{4};

    % TOR20A (2020-21 "Los Pen offshore", S/N 1053) is HELD OUT of the catalog —
    % its timing could not be validated. It is kept here as a documented case and
    % to exercise the clockSource='fixed' path, but it is NOT registered in
    % deployment_registry, so no batch run processes it into the catalog.
    %
    % Why it fails: its raw files are named with a sequence counter, not the
    % wall-clock hour, so clockSource='filename' cannot recover it (the offset
    % guard rejects it, correctly). The sample clock RATE is true — the pressure
    % M2 tide sits at 12.411 h (real 12.421 h) — so in principle a single fixed
    % offset should recover it. But three independent anchors disagree and the
    % plausible one fails a cross-check:
    %   - tide vs TOR20W's known-time tide: +44 h, r=0.846, but ALIASED (the
    %     periodic tide did not disambiguate over the ~27 d overlap);
    %   - Hs vs MOP D0591: ~-22 d, r=0.47;   Hs vs TOR20W Hs: ~-15 d, r=0.67;
    %     both point to a start BEFORE the checkout's programmed date (implausible).
    % At the tide-aligned epoch, TOR20A Hs vs the well-timed neighbour TOR20W is
    % R^2=0.001 — its wave-event sequence does not align with reality at any
    % offset, consistent with the unusual file structure (sequence-counter names,
    % duplicate .VEC/.053 sets) having scrambled the assembled event timing beyond
    % what a single offset fixes. Recovering it needs a reliable field start date
    % and a check of the raw-file assembly, not just a clock offset.
    if strcmp(deployment_name, 'TOR20A')
        cfg.instruments(k).clockSource = 'fixed';
        cfg.instruments(k).deployStart = datetime(2020,10,9,8,0,0);  % best (unvalidated) estimate
    end
end
