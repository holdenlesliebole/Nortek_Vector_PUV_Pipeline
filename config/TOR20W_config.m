function cfg = TOR20W_config()
% TOR20W_CONFIG  Torrey Pines winter 2020-2021, MOP582 10 m (Oct 2020 - Mar 2021).
%
%   cfg = TOR20W_config()
%
%   Single Nortek Vector (S/N 15277, "TORREY02") redeployed at the same
%   MOP582 ~10 m site as TOR19W, 10/29/2020 - 03/31/2021. Together with TOR19W
%   and RUBY22 this gives three consecutive winters at the Torrey 10 m site.
%
%   INGEST: raw .VEC binary only — this folder has no ASCII export at all
%   (no .dat/.sen/.hdr), which is why it was never processed. See read_VEC.
%
%   filePrefix carries a trailing underscore for consistency with TOR19W; this
%   folder holds only TORREY02_1.VEC .. TORREY02_10.VEC with no bare duplicate.
%
%   Metadata from DeploymentNotes2020-2021.xls and
%   VectorPUV_Winter2020-2021Checkout.xlsx; instrument clock set to UTC.
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'TOR20W';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz, confirmed from the .VEC User Configuration record

    % San Diego coastal water temperature — see TOR19W_config for rationale.
    cfg.qcOpts.Tvalid = [9 26];

    k = 0;

    % ---- MOP 582, 10m (S/N 15277) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP582_10m';
    cfg.instruments(k).filePrefix     = 'TORREY02_';
    cfg.instruments(k).rawSubfolder   = 'TorreyPines2020-2021_10meter';
    cfg.instruments(k).rawFormat      = 'VEC';   % no ASCII export exists
    cfg.instruments(k).mopStation     = 'D0582';
    cfg.instruments(k).mopLine        = 582;
    cfg.instruments(k).depth_nominal  = 10;
    cfg.instruments(k).serialNum      = 15277;
    cfg.instruments(k).latlon         = [32.9264368, -117.2657812];
    cfg.instruments(k).heading        = NaN;   % XYZ data; auto-compute from .sen compass
                                               % (notes record 64.1 deg magnetic at install)
    cfg.instruments(k).clockDrift     = 9.3;   % s, "9.3sec faster than internet time"
    cfg.instruments(k).doffp          = 0.95;  % m, pressure port 95 cm above sand at
                                               % deployment (90 cm on 2021-02-24 service)
end
