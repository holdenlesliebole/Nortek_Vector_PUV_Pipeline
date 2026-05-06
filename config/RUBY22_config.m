function cfg = RUBY22_config()
% RUBY22_CONFIG  Ruby2D winter 2021-2022 cross-shore array at Torrey Pines.
%
%   cfg = RUBY22_config()
%
% Multi-instrument cross-shore array deployed off Torrey Pines from
% Nov 2021 onward, originally analyzed by Athina Lange (Lange et al.
% 2023, JGR-Oceans). Ruby2D refers to the IG-band wave dynamics
% experiment.
%
% Three instruments confirmed pipeline-ready (have full .hdr/.dat/
% .sen/.VEC file sets):
%   - 12414 at MOP582 30m   (Nov 10-26 2021, 8 bursts)
%   - 16310 at MOP578 10m   (2 bursts, prefix TORREY16310_03_)
%   - 16737 at MOP579 6m    (4 bursts)
%
% A fourth Ruby2D instrument (Cardiff_2021_MOP669_10m) has incomplete
% file sets across bursts — excluded for now.
%
% lat/lon, heading, clockDrift, doffp are placeholders pending
% deployment notes. doffp set to 0.60 m as in legacy comparison
% (process_ruby2d_one.m), which was itself a placeholder.
%
% Compatible with the existing legacy comparison (compare_ruby2d.m)
% which already validated the MOP582 6m record's bulk parameters
% against the legacy pipeline (Hs RMS 5 cm, R²=0.98).
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'RUBY22';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied/Ruby2D_2021-2022';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz, from .hdr

    k = 0;

    % ---- MOP 582, 30m (S/N 12414) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP582_30m';
    cfg.instruments(k).filePrefix     = 'TORREY12414_';
    cfg.instruments(k).rawSubfolder   = '12414_MOP582-30m';
    cfg.instruments(k).mopStation     = 'D0582';
    cfg.instruments(k).mopLine        = 582;
    cfg.instruments(k).depth_nominal  = 30;
    cfg.instruments(k).serialNum      = 12414;
    cfg.instruments(k).latlon         = [32.927, -117.286];   % approximate, refine from notes
    cfg.instruments(k).heading        = NaN;     % auto-compute from .sen
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.60;    % placeholder; verify from DeploymentNotes2021Torrey

    % ---- MOP 578, 10m (S/N 16310, prefix has _03_ middle) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP578_10m';
    cfg.instruments(k).filePrefix     = 'TORREY16310_03_';
    cfg.instruments(k).rawSubfolder   = '16310_MOP578_10m';
    cfg.instruments(k).mopStation     = 'D0578';
    cfg.instruments(k).mopLine        = 578;
    cfg.instruments(k).depth_nominal  = 10;
    cfg.instruments(k).serialNum      = 16310;
    cfg.instruments(k).latlon         = [32.918, -117.270];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.60;

    % ---- MOP 579, 6m (S/N 16737) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP579_6m';
    cfg.instruments(k).filePrefix     = 'TORREY16737_';
    cfg.instruments(k).rawSubfolder   = '16737_MOP579_6m';
    cfg.instruments(k).mopStation     = 'D0579';
    cfg.instruments(k).mopLine        = 579;
    cfg.instruments(k).depth_nominal  = 6;
    cfg.instruments(k).serialNum      = 16737;
    cfg.instruments(k).latlon         = [32.920, -117.265];
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.60;

end
