% PUV_L1_DRIVER  Level-1 processing for all instruments in a deployment.
%
%   Loads raw Nortek Vector data, applies QC (clock drift, pitch/roll/
%   pressure thresholds, correlation filter), rotates to buoy coordinates,
%   and saves one .mat file per instrument.
%
%   Each saved file carries provenance (shared/save_with_provenance): an
%   embedded .prov block and a <file>.prov.json sidecar, as scripts/copy_to_server
%   requires. Instruments flagged knownFailed in the config are skipped.
%
%   To process a different deployment, change deployment_name below and re-run.
% Author: Holden Leslie-Bole, 2026

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
failed = {};   % labels of records not written
fprintf('\n=== L1 Processing: %s (%d instruments) ===\n', deployment_name, nInstr);

for k = 1:nInstr
    instr = cfg.instruments(k);
    fprintf('\n[%d/%d] Processing %s - %s\n', k, nInstr, cfg.name, instr.label);
    [isKF, kfWhy] = known_failed(instr);
    if isKF
        fprintf('  KNOWN FAILED, skipped (instruments(%d).knownFailed): %s\n', k, kfWhy);
        continue
    end

    try
        PUV = PUV_raw_process(instr, cfg);

        outFile = fullfile(outDir, [instr.label '_processed.mat']);
        save_with_provenance(outFile, 'L1', 'PUV', PUV, [], instr);
        fprintf('  Saved: %s\n', outFile);
    catch ME
        failed{end+1} = instr.label; %#ok<SAGROW>
        % (the stack used to be formatted with arrayfun(@(s) string(s.name), ...),
        % which throws MATLAB:invalidConversion and hid the original error)
        warning('PUV_L1_driver:instrumentFailed', ...
            'FAILED: %s\nReason: %s', instr.label, ME.message);
        for s = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
        end
    end
end

fprintf('\nDone. Processed %d instruments for %s.\n', nInstr, deployment_name);

% Fail loudly: a record that failed or had no input must not end the run looking
% like success (each record runs in try/catch so the others still run).
if ~isempty(failed)
    error('PUV_L1_driver:failures', '%d of %d record(s) not written for %s: %s (details above)', ...
        numel(failed), nInstr, deployment_name, strjoin(failed, ', '));
end
