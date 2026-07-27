function cfg = Coronado_config(deployment_name)
% CORONADO_CONFIG  Pre-2019 Coronado (Silver Strand) offshore PUV deployments.
%
%   cfg = Coronado_config('COR16B')
%
%   Coronado is a new site for this pipeline, and the only one in the catalog on
%   the Silver Strand — a south-facing stretch whose shore-normal (223.5 deg) is
%   nearly 40 deg off the north-county sites, so it samples a different slice of
%   the directional wave field.
%
%   A single Nortek Vector sat off Coronado (32.66545, -117.16860, ~9 m) through
%   the 2016-17 and 2017-18 winters, swapped every 5-6 weeks; the letter is the
%   deployment ordinal from the PUV inventory (PandPUV2015-2025.xlsx). Only the
%   2nd deployment of 2016-17 and the 4th of 2017-18 survive in the archive.
%
%   MOP D0158 is the nearest transect (381 m), resolved from the CDIP station
%   metadata. Note the Silver Strand runs NNW here, so alongshore distance is
%   not well approximated by latitude alone — the station was picked on true
%   separation, not on latitude.
%
%   INGEST. Raw .VEC binary, firmware 1.21, 2 Hz, wrong clock epoch recovered
%   from the MMDDHHMM filenames. See TorreyOffshore_config for the full
%   explanation of both.
%
%   COR17D deployed simultaneously with TOR17D (both 2018-03-20 to 04-25), so
%   the two folders contain files with identical names covering different sites.
%   They are distinguished by rawSubfolder, and by serial in the binary
%   (Coronado 1181, Torrey 0806).
%
%   doffp IS recorded, contrary to an earlier note here that said otherwise.
%   Source: /Volumes/group/DeploymentNotes/SoCal_instruments_{2016-2017,
%   2017-2018}.xls, sheet 'All Data', column "Deployment Depth below sand (cm)".
%   Matched on serial AND deployment ordinal AND season:
%     COR16B = "PUV-Coronado, 2nd Deployment", S/N V1181, 01/05-02/09/2017
%              "58cm sand to top of pressure port, 42 on recovery"
%     COR17D = "PUV-Coronado (Nortek Vector ADV), 4th Deployment", S/N V1181,
%              03/20-04/25/2018, "72cm sand to top of pressure port, 76cm on recovery"
%   The at-deployment value is used, per DOFFP_LOOKUP_CHECKLIST.
%
%   NOTE the two deployments genuinely differ (0.58 vs 0.72) — the single
%   0.65 m "program-typical" placeholder that was here split the difference and
%   was wrong in both directions. COR16B also lost 16 cm of bed over the
%   deployment (58 -> 42 cm), the largest bed change in this set, so its fixed
%   doffp carries correspondingly more uncertainty.
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

    cor_latlon = [32.66545, -117.16860];

    k = 1;
    cfg.instruments(k).label         = 'MOP158_9m';
    cfg.instruments(k).mopStation    = 'D0158';
    cfg.instruments(k).mopLine       = 158;
    cfg.instruments(k).latlon        = cor_latlon;
    cfg.instruments(k).heading       = NaN;    % XYZ; auto-compute from .sen compass
    cfg.instruments(k).clockDrift    = NaN;
    cfg.instruments(k).doffp         = NaN;    % set per deployment in the switch below
    cfg.instruments(k).depth_nominal = 9;
    cfg.instruments(k).rawFormat     = 'VEC';
    cfg.instruments(k).clockSource   = 'filename';

    switch deployment_name

        case 'COR16B'   % 2nd deployment of winter 2016-17, S/N 1181
            cfg.instruments(k).rawSubfolder  = fullfile('CoronadoJan_2017', 'Coronado1181');
            cfg.instruments(k).filePrefix    = '';
            cfg.instruments(k).serialNum     = 1181;
            cfg.instruments(k).deployYear    = 2017;
            cfg.instruments(k).doffp         = 0.58;   % m, at deployment (0.42 on recovery)

        case 'COR17D'   % 4th deployment of winter 2017-18, S/N 1181
            cfg.instruments(k).rawSubfolder  = 'Coronado4thDeployment_2018';
            cfg.instruments(k).filePrefix    = '';
            cfg.instruments(k).serialNum     = 1181;
            cfg.instruments(k).deployYear    = 2018;
            cfg.instruments(k).doffp         = 0.72;   % m, at deployment (0.76 on recovery)

        otherwise
            error('Coronado_config:unknownDeployment', ...
                'Unknown deployment "%s". Valid: COR16B, COR17D.', deployment_name);
    end
end
