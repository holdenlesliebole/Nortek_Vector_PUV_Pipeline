% PUV_L2_DRIVER  Level-2 spectral processing for all instruments in a deployment.
%
%   Loads L1 QC'd .mat files, runs spectral analysis (1-hour UTC-aligned
%   segments by default), and saves one L2 .mat file per instrument.
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
    error('PUV_L2_driver:unknownDeployment', ...
        'Deployment "%s" not found in registry. Available: %s', ...
        deployment_name, strjoin(keys(registry), ', '));
end
configFn = registry(deployment_name);
cfg = configFn();

% L1 input directory
l1Dir = fullfile(cfg.outputDir, 'L1', cfg.name);
if ~isfolder(l1Dir)
    error('PUV_L2_driver:noL1', ...
        'L1 directory not found: %s\nRun PUV_L1_driver first.', l1Dir);
end

% L2 output directory
outDir = fullfile(cfg.outputDir, 'L2', cfg.name);
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% ======================== OPTIONAL SETTINGS ========================
opts = struct();
% opts.KpMin    = 0.1;       % pressure correction cutoff
% opts.D50      = 0.25e-3;   % median grain size (m) — default 0.25 mm placeholder
% opts.doRotate = true;       % shore-normal rotation via CDIP THREDDS

%% ======================== PROCESS EACH INSTRUMENT ========================
nInstr = numel(cfg.instruments);
fprintf('\n=== L2 Spectral Processing: %s (%d instruments) ===\n', deployment_name, nInstr);

for k = 1:nInstr
    instr = cfg.instruments(k);
    fprintf('\n[%d/%d] Processing %s - %s\n', k, nInstr, cfg.name, instr.label);

    l1File = fullfile(l1Dir, [instr.label '_processed.mat']);
    if ~isfile(l1File)
        warning('PUV_L2_driver:noL1File', ...
            'L1 file not found: %s — skipping.', l1File);
        continue
    end

    try
        fprintf('  Loading L1: %s\n', l1File);
        loaded = load(l1File, 'PUV');

        L2 = PUV_L2_spectral(loaded.PUV, instr, opts);

        outFile = fullfile(outDir, [instr.label '_L2.mat']);
        save(outFile, 'L2', '-v7.3');
        fprintf('  Saved: %s\n', outFile);

        nValid = sum(L2.segValid);
        nTotal = length(L2.segValid);
        validPct = 100 * nValid / nTotal;
        fprintf('  %d/%d segments valid (%.0f%%), Hs range: %.2f–%.2f m\n', ...
            nValid, nTotal, validPct, ...
            min(L2.Hs(L2.segValid)), max(L2.Hs(L2.segValid)));
        if validPct < 60
            warning('PUV_L2_driver:lowValidRate', ...
                '%s: only %.0f%% of segments valid — check L1 QC diagnostics.', ...
                instr.label, validPct);
        end

        % Run MOP validation if this instrument has a MOP station
        if isfield(instr, 'mopStation') && ~isempty(instr.mopStation)
            fprintf('  Running bound wave validation...\n');
            try
                analyze_bound_waves(L2);
                fprintf('  Bound wave figures saved.\n');
            catch valME
                warning('PUV_L2_driver:validationFailed', ...
                    'Bound wave validation failed for %s: %s', instr.label, valME.message);
            end

            fprintf('  Running directional spread comparison...\n');
            try
                compare_directional_spread(L2);
                fprintf('  Directional spread figures saved.\n');
            catch valME
                warning('PUV_L2_driver:validationFailed', ...
                    'Directional spread comparison failed for %s: %s', instr.label, valME.message);
            end
        end
    catch ME
        warning('PUV_L2_driver:instrumentFailed', ...
            'FAILED: %s\nReason: %s\nStack: %s', ...
            instr.label, ME.message, ...
            sprintf('%s (line %d)\n', ...
                arrayfun(@(s) string(s.name), ME.stack), ...
                arrayfun(@(s) s.line, ME.stack)));
    end
end

fprintf('\nDone. L2 processing for %s complete.\n', deployment_name);
