function cfg = TorreyOffshore_config(deployment_name)
% TORREYOFFSHORE_CONFIG  Pre-2019 Torrey Pines offshore PUV deployments.
%
%   cfg = TorreyOffshore_config('TOR15A')
%
%   A single Nortek Vector sat at the same offshore station off Torrey Pines
%   (32.93443, -117.26544, ~8-9 m) every winter from 2015. Each winter the
%   instrument was swapped every 5-6 weeks, so a season has up to four
%   sequential deployments; the letter in the name is that ordinal, taken
%   straight from the PUV inventory (PandPUV2015-2025.xlsx). The same station
%   appears in later deployment notes as the "Los Pen offshore ADV".
%
%   Not the same site as the MOP580/586 nearshore array used by TBR23 and the
%   TOR2xS/W deployments — this one is at MOP591, about 800 m north.
%
%   INGEST. Raw .VEC binary only; there is no ASCII export. These are firmware
%   1.21 instruments and two things about them differ from the modern fleet:
%
%   1. SAMPLE RATE IS 2 Hz, despite the User Configuration implying 8 Hz. The
%      field checkout sheet records "Sample rate = 2Hz, Samples per block =
%      7168, Block time = 3600 s, Sampling duration = 3584 s", which matches the
%      decoded records exactly (7167 velocity records per hourly file). read_VEC
%      measures the rate from the records rather than the configuration field.
%
%   2. THE CLOCK EPOCH IS WRONG. These instruments stamp their first sample
%      2000-01-01 or 2002-01-01. The clock still runs true, and the recorder
%      names each hourly file MMDDHHMM for the real wall-clock hour, so the
%      epoch is recovered by a constant offset — clockSource = 'filename' with
%      deployYear. See vec_clock_from_filenames. The recovered spans agree with
%      the logged deployment dates to the day.
%
%   doffp is not recorded for these years. 0.63 m is carried over from the
%   2019-2020 notes for the same station and the same upward-looking frame
%   ("Pressure port 63cm above sand"). The sensitivity is small: at 8 m depth
%   with 14 s swell, cosh(k*doffp) = 1.0005, so a 0.1 m error moves Hs by well
%   under 1%. It matters more for the reported water depth, which it shifts
%   one-for-one.
% Author: Holden Leslie-Bole, 2026

    cfg.name      = deployment_name;
    cfg.fs        = 2;   % Hz — measured from the records, see note above
    cfg.outputDir = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied';

    % San Diego coastal water temperature (see TOR19W_config for rationale).
    cfg.qcOpts.Tvalid = [9 26];

    tor_latlon = [32.93443, -117.26544];

    k = 1;
    cfg.instruments(k).label         = 'MOP591_9m';
    cfg.instruments(k).mopStation    = 'D0591';
    cfg.instruments(k).mopLine       = 591;
    cfg.instruments(k).latlon        = tor_latlon;
    cfg.instruments(k).heading       = NaN;    % XYZ; auto-compute from .sen compass
    cfg.instruments(k).clockDrift    = NaN;    % residual drift after epoch recovery is
                                               % 13-61 s over a deployment; see L1 log
    cfg.instruments(k).doffp         = 0.63;   % m — inherited, see header
    % One nominal depth for the station. Single-hour median pressures across the
    % four deployments run 7.8-8.8 dBar, a spread well inside the 2.5 m tidal
    % range, so it is not evidence of a changing bed.
    cfg.instruments(k).depth_nominal = 9;
    cfg.instruments(k).rawFormat     = 'VEC';
    cfg.instruments(k).clockSource   = 'filename';

    switch deployment_name

        case 'TOR15A'   % 1st deployment of winter 2015-16, S/N 1181
            cfg.instruments(k).rawSubfolder  = 'Torrey1181_2015';
            cfg.instruments(k).filePrefix    = '';
            cfg.instruments(k).serialNum     = 1181;
            cfg.instruments(k).deployYear    = 2015;

        case 'TOR15B'   % 2nd deployment of winter 2015-16, S/N 1053
            cfg.instruments(k).rawSubfolder  = 'Torrey1053_2016';
            cfg.instruments(k).filePrefix    = '';
            cfg.instruments(k).serialNum     = 1053;
            cfg.instruments(k).deployYear    = 2016;

        case 'TOR16B'   % 2nd deployment of winter 2016-17, S/N 1049
            cfg.instruments(k).rawSubfolder  = 'Torrey1049_2017';
            cfg.instruments(k).filePrefix    = '';
            cfg.instruments(k).serialNum     = 1049;
            cfg.instruments(k).deployYear    = 2017;

        case 'TOR17D'   % 4th deployment of winter 2017-18, S/N 0806
            cfg.instruments(k).rawSubfolder  = 'Torrey0806_2018';
            cfg.instruments(k).filePrefix    = '';
            cfg.instruments(k).serialNum     = 806;
            cfg.instruments(k).deployYear    = 2018;

        otherwise
            error('TorreyOffshore_config:unknownDeployment', ...
                'Unknown deployment "%s". Valid: TOR15A, TOR15B, TOR16B, TOR17D.', ...
                deployment_name);
    end
end
