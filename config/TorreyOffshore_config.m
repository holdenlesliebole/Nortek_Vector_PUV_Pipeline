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
%   doffp IS recorded for every year, contrary to the note this replaces
%   (resolved 2026-07-27). Every deployment was matched on serial AND ordinal
%   AND season; the 2014-15 folder dates confirm the ordinal mapping exactly
%   (141209/150127/150306 vs logged 12/09, 01/27, 03/16). Sources:
%     2014-15  SoCal_instruments_2014.xls      'All Data' r39-41
%     2015-16  SoCal_instruments_2015.xls      'All Data' r54-58
%     2016-17  SoCal_instruments_2016-2017.xls 'All Data' r26-29
%     2017-18  SoCal_instruments_2017-2018.xls 'All Data' r32-35
%     2018-19  DeploymentNotes2018-2019.xls    'All Data' r48-49
%     2019-20  DeploymentNotes2019-2020.xls    'All Data' r66-68
%
%   THE CARRIED 0.63 WAS WRONG BY UP TO 0.25 m. Actual at-deployment values run
%   0.38-0.76 m: the bed at this station moves far more than one number can
%   describe. Worst cases TOR16D (0.38, off by -0.25) and TOR16C (0.42, -0.21).
%   The old note's "Hs sensitivity well under 1%" still holds, but depth shifts
%   one-for-one with doffp, so Hs/h, Ursell and Shields were biased by 2-3%.
%
%   Caveat: 2014-15 and the first three 2015-16 entries say "top of pressure
%   CASE"; later years say "pressure PORT". If the port sits below the case top,
%   those five are upper bounds.
%
%   [superseded] doffp is not recorded for the older years; 0.63 m is carried from the
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
    cfg.tideStation = '9410230';  % NOAA CO-OPS La Jolla (Scripps Institution Wharf), harmonic station; tidal depth in PUV_L3_currents. Same station every catalog L3 used through 2026-10-15 (then hardcoded in toolbox getztide2.m)
    cfg.qcOpts.cutoffGapSec = 60;       % clear the benign per-file firmware-1.21 hiccups

    k = 1;
    cfg.instruments(k).label         = 'MOP591_9m';
    cfg.instruments(k).mopStation    = 'D0591';
    cfg.instruments(k).mopLine       = 591;
    cfg.instruments(k).latlon        = [32.93443, -117.26544];
    % Heading: NaN = auto-compute from the .sen compass, EXCEPT where the field
    % log records the mount heading and the compass is shown not to track
    % orientation (logHeading below).
    cfg.instruments(k).heading       = NaN;    % XYZ; auto-compute from .sen compass

    % ---- LOGGED HEADINGS (2026-10-07; replaces the 2026-07-27 headingFix) -----
    % Rule: use the field-log mount heading where the onboard compass DRIFTS or
    % STEPS at constant tilt (in-water daily heading range > 5 deg with daily
    % pitch and roll ranges each <= 2 deg). The criterion uses the compass and
    % tilt only, never MOP. It selects TOR16A-D, TOR17A and TOR17C here.
    % Evidence (outputs/validation/heading_audit_2026-10-07/): TOR16A's compass
    % runs 53.8 -> 136.9 deg over ~35 d at constant tilt while the PUV-MOP
    % direction offset does not follow it (slope +0.02; a real rotation gives
    % -1, confirmed at -0.983 by injecting the same drift).
    %
    % Convention: the logged value is the magnetic bearing of +x, used as is
    % (no 180 added). Set by the PUV-only check that the wave direction then
    % sits within 4.3 deg of onshore for all six, every hour within +-90 deg;
    % the opposite convention lands 171.7-176.6 deg away.
    %
    % The 2026-07-27 headingFix (TOR16B 87.3 = 198.0-110.7, TOR16C 88.4 =
    % 268.4-180, TOR16D 85.2 = 265.2-180) was MOP-referenced and is retired,
    % so no record carries two heading sources. The 180 deg in C and D was
    % the compass reading 180 deg off, not the mount: the logged 82.3 is
    % within 6.1 deg of both fixes.
    logHeading = containers.Map( ...
        {'TOR16A','TOR16B','TOR16C','TOR16D','TOR17A','TOR17C'}, ...
        {82.3, ...   % TOR16A: SoCal_instruments_2016-2017.xls 'All Data' row 27, "PUV-Torrey, 1st Deployment" S/N V0824: "82.3 deg (mag)"
         82.3, ...   % TOR16B: same workbook row 28, "PUV-Torrey, 2nd Deployment" S/N V1049: "unchanged" (inherits row 27: "82.3 deg (mag)")
         82.3, ...   % TOR16C: same workbook row 29, "PUV-Torrey, 3rd Deployment" S/N V0824: "unchanged" (inherits row 27: "82.3 deg (mag)")
         82.3, ...   % TOR16D: same workbook row 30, "PUV-Torrey, 4th Deployment" S/N V1049: "unchanged" (inherits row 27: "82.3 deg (mag)")
         66.7, ...   % TOR17A: SoCal_instruments_2017-2018.xls 'All Data' row 33, "PUV-Torrey (Nortek Vector ADV), 1st Deployment" S/N V1049: "66.7 deg (mag)"
         66.7});     % TOR17C: same workbook row 35, "... 3rd Deployment" S/N V1049: '""' (ditto; inherits row 33: "66.7 deg (mag)")
    if isKey(logHeading, deployment_name)
        cfg.instruments(k).heading = logHeading(deployment_name);
    end
    % DISPUTED, value left on the compass median (|log - compass| > 10 deg, but
    % the compass does not drift, so the rule above does not apply). Reported
    % via shared/heading_disputed_records.m; L1-L4 unaffected.
    %   TOR14B  log 101.5 vs compass 89.9 : SoCal_instruments_2014.xls 'All Data' row 41, V0475: "113.3 deg (101.5mag)"
    %   TOR14C  log 101.5 vs compass 76.1 : same workbook row 42, V0806: "113.3 deg (101.5mag)"
    %   TOR15A  log 63.6 vs compass 48.7  : SoCal_instruments_2015.xls 'All Data' row 55, V1181: "75 deg (63.6mag)"
    %   TOR15D  log 43.0 vs compass 26.8  : same workbook row 59, V0824: "55 deg (43.0mag)"
    %   TOR17B  log 66.7 vs compass 87.6  : SoCal_instruments_2017-2018.xls 'All Data' row 34, V0806: '""' (inherits row 33: "66.7 deg (mag)")
    %   TOR17D  log 66.7 vs compass 100.3 : same workbook row 36, V0806: '""' (inherits row 33: "66.7 deg (mag)")
    % ------------------------------------------------------------------------
    cfg.instruments(k).clockDrift    = NaN;     % handled by the filename clock recovery

    % clockOffsetHours: ADDED to the filename-derived clock to reach UTC. The
    % recorders were set to Pacific LOCAL time; measured 2026-07-27 by
    % cross-correlating L2 depth against the NOAA-referenced L3 tidal
    % prediction. At lag 0 these records sit at R ~ -0.55.
    %
    % SIGN. Pacific local time is BEHIND UTC, so the labels are SLOW and the
    % correction is POSITIVE. Derivation from the lag test: with D(t)=W(t+delta)
    % and P(t)=W(t), cross-correlation rolls P so roll(P,L)(i)=W(t_i-L), and
    % matching gives L = -delta. The measured L = -8 therefore means delta = +8
    % (samples taken 8 h AFTER their label), so +8 is added to reach UTC.
    % An earlier revision applied -8/-7 and made these records twice as wrong;
    % the in-run lag validation caught it on the second record.
    %
    % NOT a timezone conversion -- TOR15D, TOR16D and TOR17D sit entirely in
    % daylight time and still measure 8 h, so the recorders were set to PST and
    % left there.
    %   2014-15 season  +7  (TOR14B and TOR14C measured, stable across thirds
    %                        of each record; TOR14A INFERRED from its
    %                        season-mates -- only 1.9 days of valid data, its
    %                        own best lags -6/-7 are within 0.015 of each other)
    %   2015-16 onward  +8  (measured on all 11)
    %   2018-19 onward   0  (recorder set to UTC; measured on TOR18A and TOR19A)
    %
    % Every deployment MUST appear here. An omission is not a benign default:
    % the Map throws, and every registry-driven loop swallows it with
    % `catch, continue`, so the record silently disappears from the batch
    % drivers, the audits and copy_to_server while its outputs sit on disk
    % looking complete. TOR18A was missing here from 2026-07-27 to 07-28 and
    % vanished from all of them.
    clockOffsetMap = containers.Map( ...
        {'TOR14A','TOR14B','TOR14C', ...
         'TOR15A','TOR15B','TOR15D','TOR16A','TOR16B','TOR16C','TOR16D', ...
         'TOR17A','TOR17B','TOR17C','TOR17D','TOR18A','TOR19A','TOR20A'}, ...
        {  +7,      +7,      +7, ...
           +8,      +8,      +8,     +8,      +8,      +8,      +8, ...
           +8,      +8,      +8,     +8,       0,       0,       0});
    cfg.instruments(k).clockOffsetHours = clockOffsetMap(deployment_name);
    % doffp: PER-DEPLOYMENT from the field logs (resolved 2026-07-27, see header).
    % At-deployment value; the recovery value follows in the comment because the
    % difference is real bed change at this station and is large here.
    doffpMap = containers.Map( ...
        {'TOR14A','TOR14B','TOR14C', ...
         'TOR15A','TOR15B','TOR15D', ...
         'TOR16A','TOR16B','TOR16C','TOR16D', ...
         'TOR17A','TOR17B','TOR17C','TOR17D', ...
         'TOR18A','TOR19A','TOR20A'}, ...
        { 0.63,   0.55,   0.76, ...      % 2014-15 #1 (rec 0.51) / #2 (0.72) / #3 (0.76)
          0.52,   0.59,   0.64, ...      % 2015-16 #1 (rec 0.60) / #2 (see WARNING) / #4
          0.52,   0.63,   0.42,  0.38, ...% 2016-17 #1 (0.63) / #2 (0.40) / #3 (0.38) / #4 (0.40)
          0.60,   0.62,   0.65,  0.65, ...% 2017-18 #1 (0.69) / #2 (0.65) / #3 (0.65) / #4 (0.74)
          0.57,   0.63,   0.60});        % 2018-19 (rec 0.58) / 2019-20 (rec 0.74) / 2020-21
    cfg.instruments(k).doffp         = doffpMap(deployment_name);

    % WARNING — TOR15B is NOT well described by a fixed doffp. The 2015-16
    % season log records an inspection on 2016-02-04, mid-deployment, reading
    % "4cm sand to top of pressure case, not removed". The port started at 59 cm
    % and was within 4 cm of burial a month later, so doffp fell by ~55 cm over
    % the record. The 0.59 applied here is correct only at the start. Treat
    % TOR15B depth, Hs/h and any nonlinearity metric as unreliable, and do not
    % use it in a depth-dependent analysis without reconstructing a time-varying
    % doffp. (A time-varying doffp is a parked pipeline extension, not built.)
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
