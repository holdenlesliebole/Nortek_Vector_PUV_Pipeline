% PUV_L3_DRIVER  Level-3 forcing characterization for all instruments in a deployment.
%
%   Loads L2 .mat files and computes L3 products (frequency-band decomposition,
%   transport proxies, etc.). Saves one L3 .mat file per instrument.
%
%   To process a different deployment, change deployment_name below and re-run.

%% ======================== USER SETTINGS ========================
deployment_name = 'NN24';  % change to process a different deployment

%% ======================== SETUP ========================
startup_puv

registry = deployment_registry();
if ~isKey(registry, deployment_name)
    error('PUV_L3_driver:unknownDeployment', ...
        'Deployment "%s" not found in registry. Available: %s', ...
        deployment_name, strjoin(keys(registry), ', '));
end
configFn = registry(deployment_name);
cfg = configFn();

% L2 input directory
l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
if ~isfolder(l2Dir)
    error('PUV_L3_driver:noL2', ...
        'L2 directory not found: %s\nRun PUV_L2_driver first.', l2Dir);
end

% L3 output directory
outDir = fullfile(cfg.outputDir, 'L3', cfg.name);
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% ======================== PROCESS EACH INSTRUMENT ========================
nInstr = numel(cfg.instruments);
fprintf('\n=== L3 Forcing Characterization: %s (%d instruments) ===\n', deployment_name, nInstr);

for k = 1:nInstr
    instr = cfg.instruments(k);
    fprintf('\n[%d/%d] Processing %s - %s\n', k, nInstr, cfg.name, instr.label);

    l2File = fullfile(l2Dir, [instr.label '_L2.mat']);
    if ~isfile(l2File)
        warning('PUV_L3_driver:noL2File', ...
            'L2 file not found: %s — skipping.', l2File);
        continue
    end

    try
        fprintf('  Loading L2: %s\n', l2File);
        loaded = load(l2File, 'L2');
        L2 = loaded.L2;

        % --- L3a: Frequency-band decomposition ---
        L3 = PUV_L3_bands(L2);

        % --- L3b: Storm detection + MOP context ---
        L3 = PUV_L3_storms(L3, L2);

        % --- L3c: Transport proxies ---
        L3 = PUV_L3_transport(L3, L2);

        % --- Future L3 components ---
        % L3 = PUV_L3_currents(L3, L2);  % L3d

        outFile = fullfile(outDir, [instr.label '_L3.mat']);
        save(outFile, 'L3', '-v7.3');
        fprintf('  Saved: %s\n', outFile);

    catch ME
        warning('PUV_L3_driver:instrumentFailed', ...
            'FAILED: %s\nReason: %s', instr.label, ME.message);
        for s = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
        end
    end
end

fprintf('\nDone. L3 processing for %s complete.\n', deployment_name);
