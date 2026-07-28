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
% lat/lon, heading and clockDrift are still placeholders pending deployment
% notes.
%
% doffp RESOLVED 2026-07-27 from
% /Volumes/group/DeploymentNotes/DeploymentNotes2021Torrey.xls, sheet
% 'All Data' (NOT the 'Torrey' sheet, which is a separate shallow Paros survey
% array and does not cover these instruments). Matched on serial number:
%   S/N 16310  "#03 Torrey Vector MOP 578 -10m"  79 cm at deployment, 91 on recovery
%   S/N 16737  "#06 Torrey Vector MOP 579 -6m"   69 cm at deployment, 70 on recovery
%   S/N 12414  "#16 Torrey Vector MOP 582 -30m"  80 cm at deployment, 83 in a
%              scour pit on recovery
% The at-deployment value is used, per DOFFP_LOOKUP_CHECKLIST. The previous
% 0.60 m was a placeholder carried from the legacy comparison
% (process_ruby2d_one.m) and was 0.09-0.20 m low on every instrument.
%
% The same rows explain two long-standing oddities in this deployment:
%   MOP582_30m — "Pressure signal flat lined due to being deployed deeper than
%     it's maximum range." The dead record is an over-range sensor, not a
%     hardware failure. Its data is unrecoverable by construction.
%   MOP579_6m  — "Probe bent at a 90deg. angle, metal sheared open. Data shows
%     damage on 10/26 at 13:33 UTC", good data only through 2021-10-26, which
%     is why so few segments survive QC.
%   MOP578_10m — battery cable found yanked out around 11/6 13:52 UTC; data
%     through 11/11/2021 then intermittent.
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
    cfg.instruments(k).latlon         = [32.925067, -117.276367];  % surveyed; DeploymentNotes2021Torrey.xls 'All Data' row "#16 Torrey Vector MOP 582 -30m" (was [32.927 -117.286], 925 m off)
    cfg.instruments(k).heading        = NaN;     % auto-compute from .sen
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.80;    % m — MOP582_30m, at deployment (0.83 in scour pit on recovery)

    % ---- MOP 578, 10m (S/N 16310, prefix has _03_ middle) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP578_10m';
    cfg.instruments(k).filePrefix     = 'TORREY16310_03_';
    cfg.instruments(k).rawSubfolder   = '16310_MOP578_10m';
    cfg.instruments(k).mopStation     = 'D0578';
    cfg.instruments(k).mopLine        = 578;
    cfg.instruments(k).depth_nominal  = 10;
    cfg.instruments(k).serialNum      = 16310;
    cfg.instruments(k).latlon         = [32.923496, -117.265903];  % surveyed; DeploymentNotes2021Torrey.xls 'All Data' row "#03 Torrey Vector MOP 578 -10m" (was [32.918 -117.270], 720 m off)
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.79;    % m — MOP578_10m, at deployment (0.91 on recovery)

    % ---- MOP 579, 6m (S/N 16737) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP579_6m';
    cfg.instruments(k).filePrefix     = 'TORREY16737_';
    cfg.instruments(k).rawSubfolder   = '16737_MOP579_6m';
    cfg.instruments(k).mopStation     = 'D0579';
    cfg.instruments(k).mopLine        = 579;
    cfg.instruments(k).depth_nominal  = 6;
    cfg.instruments(k).serialNum      = 16737;
    cfg.instruments(k).latlon         = [32.924247, -117.263266];  % surveyed; DeploymentNotes2021Torrey.xls 'All Data' row "#06 Torrey Vector MOP 579 -6m" (was [32.920 -117.265], 498 m off)
    cfg.instruments(k).heading        = NaN;
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.69;    % m — MOP579_6m, at deployment (0.70 on recovery)

end
