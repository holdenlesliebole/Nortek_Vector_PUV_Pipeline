% PUV_L1_DRIVER  Level-1 processing for all instruments in a deployment.
%
%   Loads raw Nortek Vector data, applies QC (clock drift, pitch/roll/
%   pressure thresholds, correlation filter), rotates to buoy coordinates,
%   and saves one .mat file per instrument.
%
%   To process a different deployment, change deployment_name below and re-run.

%% ======================== USER SETTINGS ========================
deployment_name = 'TBR23';  % change to process a different deployment

%% ======================== SETUP ========================
startup_puv  % add pipeline directories to MATLAB path

% Load the deployment configuration from the registry
registry = deployment_registry();
if ~isKey(registry, deployment_name)
    error('PUV_L1_driver:unknownDeployment', ...
        'Deployment "%s" not found in registry. Available: %s', ...
        deployment_name, strjoin(keys(registry), ', '));
end
configFn = registry(deployment_name);
cfg = configFn();

% Use local cache if available
localCache = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'raw_cache', cfg.name);
if isfolder(localCache)
    cfg.localDataRoot = localCache;
    fprintf('Using local cache: %s\n', localCache);
end

% Create output directories
outDir = fullfile(cfg.outputDir, 'L1', cfg.name);
if ~exist(outDir, 'dir'), mkdir(outDir); end

diagDir = fullfile(cfg.outputDir, 'L1', 'diagnostics');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end

%% ======================== PROCESS EACH INSTRUMENT ========================
nInstr = numel(cfg.instruments);
fprintf('\n=== L1 Processing: %s (%d instruments) ===\n', deployment_name, nInstr);

for k = 1:nInstr
    instr = cfg.instruments(k);
    fprintf('\n[%d/%d] Processing %s - %s\n', k, nInstr, cfg.name, instr.label);

    try
        PUV = PUV_raw_process(instr, cfg);

        outFile = fullfile(outDir, [instr.label '_processed.mat']);
        save(outFile, 'PUV', '-v7.3');
        fprintf('  Saved: %s\n', outFile);
    catch ME
        warning('PUV_L1_driver:instrumentFailed', ...
            'FAILED: %s\nReason: %s\nStack: %s', ...
            instr.label, ME.message, ...
            sprintf('%s (line %d)\n', ...
                arrayfun(@(s) string(s.name), ME.stack), ...
                arrayfun(@(s) s.line, ME.stack)));
    end
end

fprintf('\nDone. Processed %d instruments for %s.\n', nInstr, deployment_name);
