function cfg = SIO_Pier_config(deployment_name)
% SIO_PIER_CONFIG  Deployment configs for South SIO Pier (~6m depth).
%
%   cfg = SIO_Pier_config('SIO24A')
%
%   All deployments are single-instrument, flat layout, continuous 2 Hz.
%   The instrument is at ~6m depth south of Scripps Pier, co-located
%   with an altimeter and echologger.
%
%   Note: file prefix naming is inconsistent across deployments
%   (6M_51102, 6M-51102, 6M51102). This is fine — PUV_raw_process
%   auto-detects the prefix from .dat files in the directory.
%
%   Parameters from DeploymentNotes:
%     heading   = NaN (auto-computed from .sen compass data)
%     clockDrift = NaN (unknown unless filled from DeploymentNotes)
%     doffp     = NaN (fill from DeploymentNotes before running L2)
%     latlon    = approximate site center (sufficient for mag declination)

    cfg.name      = deployment_name;
    cfg.fs        = 2;  % Hz
    cfg.outputDir = fullfile(fileparts(mfilename('fullpath')), '..', 'outputs');

    % Approximate lat/lon for South SIO Pier at 6m depth
    % (precise enough for magnetic declination; refine from DeploymentNotes)
    sio_latlon = [32.8665, -117.2570];

    k = 0;

    switch deployment_name

        case 'SIO24A'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/SouthSIOPier20240328-20240530';
            k = k + 1;
            cfg.instruments(k).label          = 'SIO_6m';
            cfg.instruments(k).filePrefix     = '6M_51102';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0511';
            cfg.instruments(k).mopLine        = 511;
            cfg.instruments(k).depth_nominal  = 6;
            cfg.instruments(k).serialNum      = 16310;
            cfg.instruments(k).latlon         = sio_latlon;
            cfg.instruments(k).heading        = NaN;   % auto-compute from .sen
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.79;      % meters (79 cm from notes, initial install)

        case 'SIO24B'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/SouthSIOPier20240611-20240728';
            k = k + 1;
            cfg.instruments(k).label          = 'SIO_6m';
            cfg.instruments(k).filePrefix     = '6M_51102';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0511';
            cfg.instruments(k).mopLine        = 511;
            cfg.instruments(k).depth_nominal  = 6;
            cfg.instruments(k).serialNum      = 16310;
            cfg.instruments(k).latlon         = sio_latlon;
            cfg.instruments(k).heading        = NaN;
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.79;      % meters (same pipe as SIO24A)

        case 'SIO24C'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/SouthSIOPier20241024-20241231';
            k = k + 1;
            cfg.instruments(k).label          = 'SIO_6m';
            cfg.instruments(k).filePrefix     = '6M_51102';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0511';
            cfg.instruments(k).mopLine        = 511;
            cfg.instruments(k).depth_nominal  = 6;
            cfg.instruments(k).serialNum      = 15033;
            cfg.instruments(k).latlon         = sio_latlon;
            cfg.instruments(k).heading        = NaN;
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.79;      % meters (same pipe as SIO24A)

        case 'SIO25A'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/SouthSIOPier20250123-20250329';
            k = k + 1;
            cfg.instruments(k).label          = 'SIO_6m';
            cfg.instruments(k).filePrefix     = '6M-51102';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0511';
            cfg.instruments(k).mopLine        = 511;
            cfg.instruments(k).depth_nominal  = 6;
            cfg.instruments(k).serialNum      = 15277;
            cfg.instruments(k).latlon         = sio_latlon;
            cfg.instruments(k).heading        = NaN;
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.79;      % meters (same pipe as SIO24A)

        case 'SIO25B'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/SouthSIOPier20250417-20250622';
            k = k + 1;
            cfg.instruments(k).label          = 'SIO_6m';
            cfg.instruments(k).filePrefix     = '6M-51102';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0511';
            cfg.instruments(k).mopLine        = 511;
            cfg.instruments(k).depth_nominal  = 6;
            cfg.instruments(k).serialNum      = 17042;
            cfg.instruments(k).latlon         = sio_latlon;
            cfg.instruments(k).heading        = NaN;
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.79;      % meters (same pipe, sand level may vary)

        case 'SIO25C'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/SouthSIOPier20250718-20250813';
            k = k + 1;
            cfg.instruments(k).label          = 'SIO_6m';
            cfg.instruments(k).filePrefix     = '6M51102';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0511';
            cfg.instruments(k).mopLine        = 511;
            cfg.instruments(k).depth_nominal  = 6;
            cfg.instruments(k).serialNum      = 17047;
            cfg.instruments(k).latlon         = sio_latlon;
            cfg.instruments(k).heading        = NaN;
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.79;      % meters (same pipe, sand level may vary)

        case 'SIO25D'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/SouthSIOPier20250904-20251126';
            k = k + 1;
            cfg.instruments(k).label          = 'SIO_6m';
            cfg.instruments(k).filePrefix     = '6M-51102';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0511';
            cfg.instruments(k).mopLine        = 511;
            cfg.instruments(k).depth_nominal  = 6;
            cfg.instruments(k).serialNum      = 17042;
            cfg.instruments(k).latlon         = sio_latlon;
            cfg.instruments(k).heading        = NaN;
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.79;      % meters (same pipe, sand level may vary)

        case 'SIO25E'
            cfg.rawDataRoot = '/Volumes/group/PUV_data/Vector/SouthSIOPier20251208-20260225';
            k = k + 1;
            cfg.instruments(k).label          = 'SIO_6m';
            cfg.instruments(k).filePrefix     = '6M-51103';
            cfg.instruments(k).rawSubfolder   = '';
            cfg.instruments(k).mopStation     = 'D0511';
            cfg.instruments(k).mopLine        = 511;
            cfg.instruments(k).depth_nominal  = 6;
            cfg.instruments(k).serialNum      = 17047;
            cfg.instruments(k).latlon         = sio_latlon;
            cfg.instruments(k).heading        = NaN;
            cfg.instruments(k).clockDrift     = NaN;
            cfg.instruments(k).doffp          = 0.69;      % meters (69 cm measured 4/17/2025, sand accreted)

        otherwise
            error('SIO_Pier_config:unknown', ...
                'Unknown deployment: %s. Available: SIO24A-C, SIO25A-E', deployment_name);
    end
end
