function cfg = CAT21A_config()
% CAT21A_CONFIG  Catalina Island deployment, Feb-Mar 2021 (CATISL03).
%
%   cfg = CAT21A_config()
%
% Single-instrument deployment at Catalina Island, multi-burst record
% from 2/18/2021 to 3/6/2021. Raw data converted to ASCII format
% (.hdr/.dat/.sen/.VEC all present).
%
% Site geometry, latlon, heading, and doffp are placeholders — fill
% from Catalina-2021 deployment notes before running L2 with shore-
% normal rotation. Catalina is OUTSIDE the CDIP MOP coverage area, so
% mopStation is empty; to get shore-normal currents and the L4 reflection
% split, set a manual angle via cfg.instruments(k).shorenormal (deg) —
% see docs/NEW_DEPLOYMENT.md. Left unset for now (velocity stays in buoy
% coords, which is the default when no angle is supplied).
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'CAT21A';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied/Catalina_2021';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz, from .hdr

    k = 0;

    % ---- CATISL03 (Feb-Mar 2021) ----
    k = k + 1;
    cfg.instruments(k).label          = 'CAT_isl';
    cfg.instruments(k).filePrefix     = 'CATISL03_';
    cfg.instruments(k).rawSubfolder   = '';
    cfg.instruments(k).mopStation     = '';      % outside CDIP MOP coverage
    cfg.instruments(k).mopLine        = NaN;
    cfg.instruments(k).depth_nominal  = NaN;     % fill from notes
    cfg.instruments(k).serialNum      = NaN;     % fill from notes
    cfg.instruments(k).latlon         = [33.45, -118.50];   % approximate Catalina, refine from notes
    cfg.instruments(k).heading        = NaN;     % auto-compute from .sen
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.75;    % typical Vector pipe height; verify from notes
end
