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
% SHORE-NORMAL (added 2026-07-27). Catalina is OUTSIDE CDIP MOP coverage, so
% there is no station to look the angle up from. It was previously left unset,
% which meant velocity stayed in the BUOY frame and L4.ref / L4.boundwave were
% not cross-shore quantities at all despite their field names.
%
% Estimated from the data. `shorenormal` is the OFFSHORE-pointing compass
% bearing (cf. Torrey 263.94 deg = west/seaward); apply_shorenormal_rotation
% does rotation = 270 - shorenormal and negates so +x' ends up onshore.
%
%   method                                        offshore bearing
%   ---------------------------------------------------------------
%   wave principal axis, <a2>/<b2>, swell band          92.7 deg
%   wave mean direction, <a1>/<b1>                     107   deg
%   mean-current principal axis (anisotropy 3.12)       62.5 deg
%   Avalon -> Pebbly Beach chord (1.9 km, least local)  30   deg
%
% APPLIED: 90 deg (due east). The wave principal axis is the best single
% estimator here -- it is an AXIS, so it is immune to the from/toward
% convention that makes the first-moment direction ambiguous, and it is
% energy-weighted over the swell band across 1861 valid segments. It lands
% within 3 deg of due east, which is also what the geography demands: Pebbly
% Beach is on Catalina's east (leeward) shore facing the San Pedro Channel
% toward the mainland.
%
% UNCERTAINTY IS LARGE: +/- 20 deg. The four estimates span 77 deg, and the
% two physically independent families (waves vs currents) differ by 30 deg. A
% 20 deg error mixes sin(20) = 34% of the alongshore component into the
% cross-shore one. Treat CAT cross-shore quantities as indicative, NOT
% quantitative, and do not use this record for a cross-shore transport budget.
% Refraction is also weaker here than on an open coast (directional spread is
% 52 deg at a sheltered leeward site), which is the main reason the wave
% estimators may be biased away from the true normal.
%
% TO IMPROVE: this wants a real bathymetric normal from a chart or DEM of
% Pebbly Beach -- the depth-gradient direction at 7.6 m. Published sources
% consulted 2026-07-27 gave the location but no coastline bearing.
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
    cfg.instruments(k).shorenormal    = 90;      % deg, OFFSHORE bearing; data-derived, +/-20 deg (see header)
end
