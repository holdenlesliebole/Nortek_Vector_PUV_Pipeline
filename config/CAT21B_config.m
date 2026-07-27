function cfg = CAT21B_config()
% CAT21B_CONFIG  Catalina Island deployment, Aug 2021 (CATISL02).
%
%   cfg = CAT21B_config()
%
% Single-instrument, single-burst record at Catalina Island,
% 8/16/2021 11:44 PM to 8/31/2021 6:35 PM. Same site as CAT21A.
%
% Site geometry RESOLVED 2026-07-27 — see CAT21A_config.m for the full account
% and the evidence that both CAT21A and CAT21B are S/N 15032 (this record spans
% 2021-08-16 to 2021-08-25, just before the 08/27 recovery). Note the notes
% record "probe bent slightly on 04/6/2021", which precedes this file set and
% may explain why so few of its segments survive QC.
%
% Formerly the same caveats as CAT21A on lat/lon, heading, doffp, and the absent
% MOP coverage. There is no CDIP MOP transect here; to get shore-normal
% currents and the L4 reflection split, set a manual angle via
% cfg.instruments(k).shorenormal (deg) — see docs/NEW_DEPLOYMENT.md.
% Left unset for now (velocity stays in buoy coords).
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'CAT21B';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied/Catalina_2021';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz

    k = 0;

    % ---- CATISL02 (Aug 2021) ----
    k = k + 1;
    cfg.instruments(k).label          = 'CAT_isl';
    cfg.instruments(k).filePrefix     = 'CATISL02';   % single-burst, no _N suffix
    cfg.instruments(k).rawSubfolder   = '';
    cfg.instruments(k).mopStation     = '';
    cfg.instruments(k).mopLine        = NaN;
    cfg.instruments(k).depth_nominal  = 7;       % ~-7 m per notes; measured median 7.7 m
    cfg.instruments(k).serialNum      = 15032;   % S/N 15032, see header
    cfg.instruments(k).latlon         = [33.334072, -118.309038];  % Pebbly Beach, surveyed
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.71;    % m, port 71cm above sand (S/N 15032)
end
