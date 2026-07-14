function cfg = TEMPLATE_config()
% TEMPLATE_CONFIG  Copy-me starting point for a NEW deployment (any site).
%
%   cfg = TEMPLATE_config()
%
%   This is a fully-commented, site-agnostic template. It is NOT a real
%   deployment and is deliberately left OUT of deployment_registry.m. To set up
%   your own deployment:
%
%     1. Copy this file to  config/<YOURSITE>_config.m  and rename the function
%        to  <YOURSITE>_config  (the filename and function name must match).
%     2. Fill in every field marked  <<< EDIT >>>  below.
%     3. Register it: add one line to config/deployment_registry.m, e.g.
%              registry('HIREEF25') = @HIREEF25_config;
%     4. Run the levels in order (see README.md "Quick start"):
%              deployment_name = 'HIREEF25';  % set at top of each driver
%              PUV_L1_driver; PUV_L2_driver; PUV_L3_driver; PUV_L4_driver
%
%   See docs/NEW_DEPLOYMENT.md for the full walkthrough (where to find each
%   parameter, how to get a shore-normal angle without CDIP/MOP, warm-water
%   temperature QC, grain size / transport notes, and troubleshooting).
%
%   The worked example below is a single Nortek Vector on a coral reef with NO
%   CDIP/MOP transect — i.e. shore-normal is set manually. Multi-instrument
%   deployments just repeat the "k = k + 1; ..." block (see TOR24S_config.m).
% Author: <<< EDIT: your name >>>

    % ---- Deployment-level settings ---------------------------------------
    cfg.name        = 'TEMPLATE';   % <<< EDIT: short key, must match registry + filename prefix
    cfg.fs          = 2;            % sample rate, Hz (Nortek Vector burst rate; usually 2)

    % rawDataRoot: absolute path to the folder holding this deployment's raw
    % Nortek files (.dat/.sen/.hdr, or .VEC exports). Point it at wherever YOUR
    % raw data lives — a local folder is perfectly fine; no lab server required.
    cfg.rawDataRoot = '/absolute/path/to/your/raw/data';   % <<< EDIT

    % outputDir: where processed L1-L4 .mat files are written. Leave as-is to
    % use PUV_Pipeline/outputs/ (recommended; already gitignored).
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');

    % ---- Optional: temperature QC range (STRONGLY recommended) -----------
    % L1 flags a failed thermistor when temperature leaves this plausible range.
    % The pipeline default [-2 40] is a wide safety bound; TIGHTEN it to your
    % site's real water-temperature range so subtle sensor failures are caught
    % without ever mis-flagging genuine water. Examples:
    %     San Diego coastal : [9 26]
    %     Tropical reef      : [22 31]
    % A failed thermistor only affects the sound-speed correction; velocity and
    % pressure survive independently (per-channel QC). See README.md "Quality
    % control" and docs/PUV_Pipeline_Guide.pdf.
    cfg.qcOpts.Tvalid = [22 31];   % <<< EDIT to your site range (degC)

    k = 0;

    % ======================================================================
    % INSTRUMENT 1  (copy this whole block for each additional instrument)
    % ======================================================================
    k = k + 1;
    cfg.instruments(k).label         = 'REEF_5m';   % <<< EDIT: unique, used in output filenames
    cfg.instruments(k).filePrefix    = 'REEF5M';    % <<< EDIT: leading chars of the raw filenames
                                                    %      (Nortek base name, without extension)
    cfg.instruments(k).rawSubfolder  = '';          % <<< EDIT: subfolder under rawDataRoot, or '' if flat

    % --- Position & environment ---
    cfg.instruments(k).latlon        = [21.28, -157.83];  % <<< EDIT [lat lon] deg; used for magnetic
                                                          %      declination (global IGRF) — approximate is fine
    cfg.instruments(k).depth_nominal = 5;    % <<< EDIT nominal water depth, m (documentation / QC context)

    % --- Instrument mounting / timing (from your deployment log) ---
    % doffp: height of the PRESSURE SENSOR above the bed, in METERS. REQUIRED for
    % the pressure->surface-elevation correction at L2. Measure it in the field.
    cfg.instruments(k).doffp         = 0.60;   % <<< EDIT (meters)

    % heading: instrument +x compass heading (deg). Leave NaN to auto-compute
    % from the .sen compass (XYZ-coordinate data). For instruments recording in
    % ENU, heading is not used. Only set an explicit value if the onboard compass
    % is known bad (see TOR24S_config.m MOP586_7m for a 180-deg-flip example).
    cfg.instruments(k).heading       = NaN;    % <<< usually leave NaN

    % clockDrift: total instrument clock offset over the deployment (seconds),
    % linearly removed at L1. Leave NaN if unknown / negligible.
    cfg.instruments(k).clockDrift    = NaN;

    cfg.instruments(k).serialNum     = 00000;  % <<< EDIT (bookkeeping only)

    % --- Shore-normal rotation: CHOOSE ONE -------------------------------
    % L2 rotates buoy-frame velocity (+x W, +y N) into a shore-normal frame
    % (+x onshore, +y alongshore-north). This drives cross-shore/alongshore
    % currents (L3) AND the incident/reflected IG split (L4). Pick one source:
    %
    %  (A) MANUAL angle  — for ANY site without a CDIP/MOP transect (the usual
    %      case outside California). Set the shore-normal direction in degrees:
    %      the compass bearing (0=N, 90=E) of the OFFSHORE-pointing shore normal.
    %      Get it from a bathymetry chart / satellite image of the local
    %      isobaths, or from the dominant swell direction. See docs/NEW_DEPLOYMENT.md.
    cfg.instruments(k).shorenormal   = 200;    % <<< EDIT (deg). Comment out to use CDIP instead.
    %
    %  (B) CDIP/MOP station — California sites only; angle fetched live from CDIP
    %      THREDDS (needs internet). If you set this instead of (A), delete the
    %      shorenormal line above and uncomment:
    % cfg.instruments(k).mopStation  = 'D0580';
    % cfg.instruments(k).mopLine     = 580;
    %
    %  If you set NEITHER, L2 leaves velocity in buoy coords and L4 reflection
    %  is skipped.

    % ======================================================================
    % INSTRUMENT 2, 3, ...  — copy the block above, incrementing k each time.
    % ======================================================================

end
