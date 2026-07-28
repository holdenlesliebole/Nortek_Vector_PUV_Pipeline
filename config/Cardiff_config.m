function cfg = Cardiff_config(deployment_name)
% CARDIFF_CONFIG  Pre-2019 Cardiff offshore PUV deployments.
%
%   cfg = Cardiff_config('CDF15A')
%
%   Cardiff is a new site for this pipeline. A single Nortek Vector sat off
%   Cardiff (33.01011, -117.28419, ~9-10 m) through the 2015-16 winter, swapped
%   every 5-6 weeks; the letter is the deployment ordinal from the PUV inventory
%   (PandPUV2015-2025.xlsx). Only the 1st and 3rd deployments survive in the
%   archive — the 2nd (S/N 0824) and 4th (S/N 1181) are not in recopied/.
%
%   MOP D0677 is the nearest transect (257 m), resolved from the CDIP station
%   metadata rather than assumed; shore-normal there is 253.5 deg.
%
%   INGEST. Raw .VEC binary, firmware 1.21, 2 Hz. See TorreyOffshore_config for
%   the full explanation of the rate and clock-epoch handling — the same two
%   issues apply here.
%
%   CDF15A is the control case for the whole clock recovery: its RTC was set
%   correctly, so filename-derived time can be checked against the instrument's
%   own clock. They agree to a 33 s median offset, which is what justifies
%   trusting the same reconstruction on the instruments whose clocks were wrong.
%
%   doffp IS recorded, contrary to an earlier note here that said otherwise.
%   Source: /Volumes/group/DeploymentNotes/SoCal_instruments_2015.xls, sheet
%   'All Data', column "Deployment Depth below sand (cm)". Matched on serial
%   AND deployment ordinal AND season, so the mapping is unambiguous:
%     CDF15A = "PUV-Cardiff, 1st Deployment", S/N V1049, 11/19/2015-01/04/2016
%              "54cm sand to top of pressure case, 59cm on recovery"
%     CDF15C = "PUV-Cardiff, 3rd Deployment", S/N V1053, 02/24/2016-03/31/2016
%              "55cm sand to top of pressure case, 54cm on recovery"
%   Per DOFFP_LOOKUP_CHECKLIST the at-deployment value is used; the recovery
%   value is kept in the comment because the difference is real bed change and
%   is the uncertainty on a single fixed doffp.
%
%   CAVEAT: these Cardiff entries say "top of pressure CASE", where Coronado
%   and Torrey say "pressure PORT". If the port sits below the case top, the
%   true doffp is smaller by that offset. Treat 0.54/0.55 as an upper bound.
% Author: Holden Leslie-Bole, 2026

    cfg.name      = deployment_name;
    cfg.fs        = 2;   % Hz — measured from the records
    cfg.outputDir = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied';

    cfg.qcOpts.Tvalid = [9 26];
    % Firmware-1.21 recorders leave one benign 3-4 s gap in nearly every
    % hourly file; raise the battery-cutoff gap threshold above them so a
    % hiccup is not mistaken for the instrument dying (see PUV_raw_process).
    cfg.qcOpts.cutoffGapSec = 60;

    cdf_latlon = [33.01011, -117.28419];

    k = 1;
    cfg.instruments(k).label         = 'MOP677_9m';
    cfg.instruments(k).mopStation    = 'D0677';
    cfg.instruments(k).mopLine       = 677;
    cfg.instruments(k).latlon        = cdf_latlon;
    cfg.instruments(k).heading       = NaN;    % XYZ; auto-compute from .sen compass
    cfg.instruments(k).clockDrift    = NaN;
    cfg.instruments(k).doffp         = NaN;    % set per deployment in the switch below
    cfg.instruments(k).depth_nominal = 9;      % station nominal; the 8.1 vs 9.4 dBar
                                               % single-hour medians differ by less than
                                               % the tidal range, not by a bed change
    cfg.instruments(k).rawFormat     = 'VEC';
    cfg.instruments(k).clockSource   = 'filename';
    % Filename clock is Pacific LOCAL time; add this to reach UTC. Measured
    % 2026-07-27 against the NOAA-referenced L3 tidal prediction: CDF15A
    % R=0.974 and CDF15C R=0.988 at -8, against R ~ -0.55 at lag 0. A FIXED
    % offset, not a timezone conversion -- CDF15C spans the 2016-03-13 DST
    % change and still measures 8 h throughout, because the recorder was set to
    % PST and left there. See TorreyOffshore_config for the full evidence.
    cfg.instruments(k).clockOffsetHours = +8;

    switch deployment_name

        case 'CDF15A'   % 1st deployment of winter 2015-16, S/N 1049 — RTC was GOOD
            cfg.instruments(k).rawSubfolder  = 'Cardiff1049_2015-2016';
            cfg.instruments(k).filePrefix    = '';
            cfg.instruments(k).serialNum     = 1049;
            cfg.instruments(k).deployYear    = 2015;   % spans into Jan 2016
            cfg.instruments(k).doffp         = 0.54;   % m, at deployment (0.59 on recovery)

        case 'CDF15C'   % 3rd deployment of winter 2015-16, S/N 1053
            cfg.instruments(k).rawSubfolder  = 'Cardiff1053_2016';
            cfg.instruments(k).filePrefix    = '';
            cfg.instruments(k).serialNum     = 1053;
            cfg.instruments(k).deployYear    = 2016;
            cfg.instruments(k).doffp         = 0.55;   % m, at deployment (0.54 on recovery)

        otherwise
            error('Cardiff_config:unknownDeployment', ...
                'Unknown deployment "%s". Valid: CDF15A, CDF15C.', deployment_name);
    end
end
