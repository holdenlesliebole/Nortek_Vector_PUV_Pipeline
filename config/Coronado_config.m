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
%   doffp is not recorded for these years; 0.65 m is the program-typical value
%   for this frame. See TorreyOffshore_config for the sensitivity argument.
% Author: Holden Leslie-Bole, 2026

    cfg.name      = deployment_name;
    cfg.fs        = 2;   % Hz — measured from the records
    cfg.outputDir = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied';

    cfg.qcOpts.Tvalid = [9 26];   % San Diego coastal

    cor_latlon = [32.66545, -117.16860];

    k = 1;
    cfg.instruments(k).label         = 'MOP158_9m';
    cfg.instruments(k).mopStation    = 'D0158';
    cfg.instruments(k).mopLine       = 158;
    cfg.instruments(k).latlon        = cor_latlon;
    cfg.instruments(k).heading       = NaN;    % XYZ; auto-compute from .sen compass
    cfg.instruments(k).clockDrift    = NaN;
    cfg.instruments(k).doffp         = 0.65;   % m — program-typical, see header
    cfg.instruments(k).depth_nominal = 9;
    cfg.instruments(k).rawFormat     = 'VEC';
    cfg.instruments(k).clockSource   = 'filename';

    switch deployment_name

        case 'COR16B'   % 2nd deployment of winter 2016-17, S/N 1181
            cfg.instruments(k).rawSubfolder  = fullfile('CoronadoJan_2017', 'Coronado1181');
            cfg.instruments(k).filePrefix    = '';
            cfg.instruments(k).serialNum     = 1181;
            cfg.instruments(k).deployYear    = 2017;

        case 'COR17D'   % 4th deployment of winter 2017-18, S/N 1181
            cfg.instruments(k).rawSubfolder  = 'Coronado4thDeployment_2018';
            cfg.instruments(k).filePrefix    = '';
            cfg.instruments(k).serialNum     = 1181;
            cfg.instruments(k).deployYear    = 2018;

        otherwise
            error('Coronado_config:unknownDeployment', ...
                'Unknown deployment "%s". Valid: COR16B, COR17D.', deployment_name);
    end
end
