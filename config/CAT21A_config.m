function cfg = CAT21A_config()
% CAT21A_CONFIG  Catalina Island deployment, Feb-Mar 2021 (CATISL03).
%
%   cfg = CAT21A_config()
%
% Single-instrument deployment at Catalina Island, multi-burst record
% from 2/18/2021 to 3/6/2021. Raw data converted to ASCII format
% (.hdr/.dat/.sen/.VEC all present).
%
% Site geometry RESOLVED 2026-07-27 from
% /Volumes/group/DeploymentNotes/DeploymentNotes2020-2021.xls, sheet 'All Data',
% rows 14-15, "Catalina, Pebbly Beach. Nortek Vector ADV". An earlier note here
% said these were placeholders to be filled "before running L2" — they never
% were, and L1-L4 were built on them.
%
%   The notes list TWO Catalina deployments at one site:
%     S/N 15033  09/24/2020 - 02/19/2021  port 79cm above sand (67cm recovery)
%                heading +X = 56.2 deg magnetic
%     S/N 15032  02/19/2021 - 08/27/2021  port 71cm above sand
%                heading +X = 222.7 deg magnetic, "probe bent slightly 04/6/2021"
%
%   BOTH CAT21A and CAT21B are S/N 15032, on two independent lines of evidence:
%     (a) L1 time spans fall inside the 15032 window and nowhere near 15033's --
%         CAT21A runs 2021-02-19 19:26 (the exact changeover day) to 2021-06-17,
%         CAT21B runs 2021-08-16 to 2021-08-25 (just before the 08/27 recovery)
%     (b) the .sen compass reads 232.7 deg (CAT21A) and 230.7 deg (CAT21B),
%         close to 15032's surveyed 222.7 and nowhere near 15033's 56.2
%   CATISL02 / CATISL03 are recorder file-set names, not serials. The
%   2021-06-17 -> 2021-08-16 gap between the two file sets is unexplained by
%   the notes.
%
%   The 15033 deployment (Sep 2020 - Feb 2021) is NOT in this catalog.
%
% latlon was [33.45, -118.50], which is 21.9 km from the surveyed position.
% depth_nominal 7 m matches the measured median depth (7.68 m at doffp 0.71).
%
% heading is deliberately left NaN (auto-compute from the .sen compass). The
% compass and the surveyed value differ by ~10 deg, which is ordinary survey /
% compass disagreement -- not the 110-180 deg failure that justified the
% explicit overrides in TorreyOffshore_config. Do not "correct" it without new
% evidence. clockDrift stays NaN: the notes record it as unknown for 15032.
%
% Catalina is OUTSIDE CDIP MOP coverage, so mopStation is empty and
% cfg.instruments(k).shorenormal is unset -- velocity stays in BUOY coordinates.
% CONSEQUENCE: L4 reflection / boundwave for this record are computed without a
% shore-normal rotation and should not be read as cross-shore quantities. Set a
% manual bathymetry-derived angle (see docs/NEW_DEPLOYMENT.md) before using them.
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
    cfg.instruments(k).depth_nominal  = 7;       % ~-7 m per notes; measured median 7.7 m
    cfg.instruments(k).serialNum      = 15032;   % S/N 15032, see header
    cfg.instruments(k).latlon         = [33.334072, -118.309038];  % Pebbly Beach, surveyed
    cfg.instruments(k).heading        = NaN;     % auto-compute from .sen
    cfg.instruments(k).clockDrift     = NaN;
    cfg.instruments(k).doffp          = 0.71;    % m, port 71cm above sand (S/N 15032)
end
