function cfg = IB19S_config()
% IB19S_CONFIG  Imperial Beach spring 2019 PUV cross-shore pair.
%
%   cfg = IB19S_config()
%
% Continuation of the IB18W deployment, 2019-03-01 → 2019-04-23. Same
% two Vectors at the same MOP stations; data was split into two
% date-named subfolders during .VEC → ASCII conversion. Metadata
% identical to IB18W (no redeployment, no service).
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'IB19S';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz, from .hdr

    k = 0;

    % ---- IB-North, MOP D0055 (S/N VEC15033) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP055_7m';
    cfg.instruments(k).filePrefix     = 'IB-N02';
    cfg.instruments(k).rawSubfolder   = '20190422_IB_North/20190301-20190423';
    cfg.instruments(k).mopStation     = 'D0055';
    cfg.instruments(k).mopLine        = 55;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 15033;
    cfg.instruments(k).latlon         = [32.5819, -117.1374];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.663;

    % ---- IB-South, MOP D0045 (S/N VEC15032) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP045_7m';
    cfg.instruments(k).filePrefix     = 'IB-S02';
    cfg.instruments(k).rawSubfolder   = '20190422_IB_South/20190301-20190423';
    cfg.instruments(k).mopStation     = 'D0045';
    cfg.instruments(k).mopLine        = 45;
    cfg.instruments(k).depth_nominal  = 7;
    cfg.instruments(k).serialNum      = 15032;
    cfg.instruments(k).latlon         = [32.5730, -117.1361];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.618;
end
