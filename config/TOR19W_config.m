function cfg = TOR19W_config()
% TOR19W_CONFIG  Torrey Pines winter 2019-2020, MOP582 10 m (Nov 2019 - May 2020).
%
%   cfg = TOR19W_config()
%
%   Single Nortek Vector (S/N 15277, "TORREY02") at MOP582.2 in ~10 m, deployed
%   from Sally Ann 11/15/2019 and recovered 05/06/2020. Extends the Torrey
%   record four years earlier than TBR23.
%
%   Co-located with the MOP582.2 Aquadopp ADCP (S/N 2141, ~15 m) over the same
%   window, which is the reason this deployment was prioritised: it is the
%   independent-instrument check on that ADCP's currents.
%
%   INGEST: raw .VEC binary, NOT the ASCII export. An ExploreV export exists in
%   this folder but is partial and truncated — TORREY02_1.dat/.sen cover only
%   2019-11-14 to 2019-11-19 (5.1 days of a 174-day record) and both terminate
%   mid-line. rawFormat is pinned to 'VEC' so the full record is decoded; see
%   read_VEC and docs/pre2023_deployment_inventory.md.
%
%   filePrefix intentionally carries the trailing underscore. The folder also
%   holds a bare TORREY02.VEC (178 MB) which is an ABORTED DUPLICATE download
%   spanning 2019-11-14 to 2019-12-11 — data already contained in TORREY02_1
%   and _2. Matching 'TORREY02_' excludes it; matching 'TORREY02' would
%   double-count roughly 27 days. The _1.._10 split files are contiguous
%   (2019-11-14 16:00:02 through 2020-05-07 18:24:57, each resuming the second
%   after the previous).
%
%   Metadata from DeploymentNotes2019-2020.xls and
%   VectorPUV_Winter2019-2020Checkout.xlsx; instrument clock set to UTC.
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'TOR19W';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz, confirmed from the .VEC User Configuration record

    % San Diego coastal water temperature. Tighter than the pipeline default
    % [-2 40] so a failing thermistor is caught while genuine seasonal range
    % (this record spans a full winter) is not flagged.
    cfg.qcOpts.Tvalid = [9 26];

    k = 0;

    % ---- MOP 582, 10m (S/N 15277) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP582_10m';
    cfg.instruments(k).filePrefix     = 'TORREY02_';   % trailing _ excludes the duplicate
    cfg.instruments(k).rawSubfolder   = 'TorreyPines2019-2020MOP582_10meter';
    cfg.instruments(k).rawFormat      = 'VEC';         % ASCII export is partial — do not use
    cfg.instruments(k).mopStation     = 'D0582';
    cfg.instruments(k).mopLine        = 582;
    cfg.instruments(k).depth_nominal  = 10;
    cfg.instruments(k).serialNum      = 15277;
    cfg.instruments(k).latlon         = [32.9264049, -117.2657759];
    cfg.instruments(k).heading        = NaN;   % XYZ data; auto-compute from .sen compass
                                               % (notes record 57.3 deg magnetic at install)
    cfg.instruments(k).clockDrift     = 7;     % s, "7 seconds faster than internet time";
                                               % positive = instrument clock ahead, which L1
                                               % removes as a linear ramp
    cfg.instruments(k).doffp          = 0.66;  % m, pressure port 66 cm above sand at
                                               % deployment (75 cm 2020-01-30 inspection,
                                               % 78 cm at recovery — bed accreted ~12 cm)
end
