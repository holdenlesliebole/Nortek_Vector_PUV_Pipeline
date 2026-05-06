function cfg = CAT21B_config()
% CAT21B_CONFIG  Catalina Island deployment, Aug 2021 (CATISL02).
%
%   cfg = CAT21B_config()
%
% Single-instrument, single-burst record at Catalina Island,
% 8/16/2021 11:44 PM to 8/31/2021 6:35 PM. Same site as CAT21A.
%
% Same caveats as CAT21A on lat/lon, heading, doffp, and the absent
% MOP coverage. Run L2 with `opts.doRotate = false` until a manual
% shore-normal angle is provided.
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
    cfg.instruments(k).depth_nominal  = NaN;
    cfg.instruments(k).serialNum      = NaN;
    cfg.instruments(k).latlon         = [33.45, -118.50];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.75;
end
