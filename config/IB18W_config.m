function cfg = IB18W_config()
% IB18W_CONFIG  Imperial Beach winter 2018-2019 PUV cross-shore pair.
%
%   cfg = IB18W_config()
%
% Two Vector ADVs deployed at Imperial Beach, 2018-11-27 → 2019-03-01.
% Continuous 2 Hz record, single-burst .dat per instrument. Metadata
% from /Volumes/group/DeploymentNotes/DeploymentNotes2018-2019.xls
% (Brian Woodward).
%
% IB-North at MOP D0055 (5.5 km north of Mexican border), water depth
% ~7.4 m; IB-South at MOP D0045 (4.5 km north), water depth ~6.6 m.
% IB Pier (separate B3 pressure-only sensor, not in this config) sits
% between them at MOP D0053 in ~8 m water.
%
% Continuation deployment 2019-03-01 → 2019-04-23 is captured separately
% in IB19S_config.m (data was split into two date-named subfolders during
% .VEC → ASCII conversion).
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'IB18W';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz, from .hdr

    k = 0;

    % ---- IB-North, MOP D0055 (S/N VEC15033) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP055_7m';
    cfg.instruments(k).filePrefix     = 'IB-N02';
    cfg.instruments(k).rawSubfolder   = '20190422_IB_North/20181127-20190301';
    cfg.instruments(k).mopStation     = 'D0055';
    cfg.instruments(k).mopLine        = 55;
    cfg.instruments(k).depth_nominal  = 7;        % 7.4 m water depth at deploy (notes)
    cfg.instruments(k).serialNum      = 15033;    % VEC15033
    cfg.instruments(k).latlon         = [32.5819, -117.1374];
    cfg.instruments(k).heading        = NaN;       % auto-compute from .sen
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.663;     % from deployment notes

    % ---- IB-South, MOP D0045 (S/N VEC15032) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP045_7m';
    cfg.instruments(k).filePrefix     = 'IB-S02';
    cfg.instruments(k).rawSubfolder   = '20190422_IB_South/20181127-20190301';
    cfg.instruments(k).mopStation     = 'D0045';
    cfg.instruments(k).mopLine        = 45;
    cfg.instruments(k).depth_nominal  = 7;        % 6.6 m water depth at deploy (notes)
    cfg.instruments(k).serialNum      = 15032;    % VEC15032
    cfg.instruments(k).latlon         = [32.5730, -117.1361];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.618;     % from deployment notes
end
