function cfg = IB19W_config()
% IB19W_CONFIG  Imperial Beach winter 2019-2020, Cortez Ave (Nov 2019 - May 2020).
%
%   cfg = IB19W_config()
%
%   Single Nortek Vector (S/N 15032, "IB-S02") off Cortez Ave in ~6 m, deployed
%   from Sally Ann 11/18/2019 and recovered 05/27/2020. Same instrument and MOP
%   line as the IB19S MOP045 record, one season later — IB18W (winter 2018-19),
%   IB19S (spring 2019) and IB19W (winter 2019-20) are three separate
%   deployments of the same Vector at this site.
%
%   INGEST: raw .VEC binary only — no ASCII export exists in this folder.
%   See read_VEC.
%
%   NOTE ON doffp: the pressure port sat 73 cm above the sand at deployment but
%   120 cm at recovery, so the bed eroded ~47 cm over the winter. That is a far
%   larger change than the other Tier A deployments and it matters, because the
%   pressure-to-surface-elevation transfer function at L2 uses a single fixed
%   doffp. The at-deployment value is used here, per DOFFP_LOOKUP_CHECKLIST.md,
%   but depth-attenuation corrections late in this record carry more
%   uncertainty than the nominal value implies.
%
%   Metadata from DeploymentNotes2019-2020.xls and
%   VectorPUV_Winter2019-2020Checkout.xlsx; instrument clock set to UTC.
% Author: Holden Leslie-Bole, 2026

    cfg.name        = 'IB19W';
    cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/recopied';
    cfg.outputDir   = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');
    cfg.fs          = 2;  % Hz, confirmed from the .VEC User Configuration record

    % San Diego coastal water temperature — see TOR19W_config for rationale.
    cfg.qcOpts.Tvalid = [9 26];

    k = 0;

    % ---- MOP 045, Cortez Ave 6m (S/N 15032) ----
    k = k + 1;
    cfg.instruments(k).label          = 'MOP045_6m';
    cfg.instruments(k).filePrefix     = 'IB-S02_';
    cfg.instruments(k).rawSubfolder   = '2019-2020-IB-Cortez';
    cfg.instruments(k).rawFormat      = 'VEC';   % no ASCII export exists
    cfg.instruments(k).mopStation     = 'D0045';
    cfg.instruments(k).mopLine        = 45;
    cfg.instruments(k).depth_nominal  = 6;
    cfg.instruments(k).serialNum      = 15032;
    cfg.instruments(k).latlon         = [32.5729147, -117.1359743];
    cfg.instruments(k).heading        = NaN;   % XYZ data; auto-compute from .sen compass
                                               % (notes record 80.3 deg magnetic at install)
    cfg.instruments(k).clockDrift     = 11;    % s, "11 seconds faster than internet time"
    cfg.instruments(k).doffp          = 0.73;  % m, pressure port 73 cm above sand at
                                               % deployment (120 cm at recovery — see above)
end
