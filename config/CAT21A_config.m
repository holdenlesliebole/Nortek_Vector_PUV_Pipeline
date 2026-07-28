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
%   method                                              offshore bearing
%   -----------------------------------------------------------------
%   beach directly in front of the PUV, measured on imagery   63 deg
%   mean-current principal axis (anisotropy 3.12)             62.5 deg
%   surveyed shoreline, RBR142->RBR144 (461 m, 2021-05-25)    57.7 deg
%   surveyed RBR142->RBR143 (340 m, the nearer segment)       61.5 deg
%   wave principal axis, <a2>/<b2>, swell band                92.7 deg
%   wave mean direction, <a1>/<b1>                           107   deg
%
% APPLIED: 63 deg.
%
% The GPS survey is /Volumes/group/LiDAR/Mele/Catalina_GPS/
% 20210525_CATALINA_RBR.txt -- three RBR marks surveyed 2021-05-25, DURING this
% deployment, that lie along the coast 0.5-1 km NW of the PUV. Their trend gives
% an independent shore-normal that lands within 1-5 deg of both the imagery
% measurement and the current axis.
%
% The survey also confirms the beach is EMBAYED: the trend swings 151.5 deg
% (RBR142->143) to 137.1 deg (RBR143->144), i.e. the local normal moves 61.5 ->
% 47.1 deg over 460 m. So a single angle is a compromise, and 63 deg is chosen
% because it describes the beach directly in front of the instrument.
%
% A PREVIOUS REVISION APPLIED 90 deg AND WAS WRONG BY ~27 deg. It preferred the
% wave principal axis on the reasoning that refraction aligns waves with the
% shore-normal in shallow water. That assumption fails here: this is a sheltered
% leeward embayment receiving long-period swell (median Tp 16.4 s) that wraps
% around the island and arrives obliquely, with 52 deg of directional spread.
% Waves never refract into alignment, so the wave axis is NOT the shore-normal.
% The current axis -- constrained by the coastline rather than by refraction --
% was the reliable estimator, and it agrees with the survey and the imagery.
% LESSON: prefer the current principal axis over wave direction wherever
% refraction is weak (sheltered, embayed, or long-period sites).
%
% Uncertainty is now roughly +/-8 deg (the three independent local estimators
% span 57.7-63), down from the +/-20 deg quoted when only the wave estimators
% were trusted. Still not a survey of the normal itself; a bathymetric gradient
% from a DEM would settle it.
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
    cfg.instruments(k).shorenormal    = 63;      % deg, OFFSHORE bearing; survey + imagery + currents (see header)
end
