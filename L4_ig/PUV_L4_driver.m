% PUV_L4_DRIVER  Level-4 IG / bound-wave dynamics for one deployment.
%
%   Loads L1 (raw QC'd timeseries) and L2 (spectra) .mat files for every
%   instrument in the deployment, runs PUV_L4_eta → PUV_L4_reflection →
%   PUV_L4_bispectra, and saves one L4 .mat file per instrument.
%
%   To process a different deployment, change deployment_name below and
%   re-run.
% Author: Holden Leslie-Bole, 2026

%% ======================== USER SETTINGS ========================
deployment_name = 'TBR23';

% Per-module option overrides. Leave structs empty for module defaults.
% For fast validation runs, set bispectraOpts.nfft = 1024 (~4x faster
% than the 2048 default at coarser frequency resolution).
etaOpts        = struct();
reflectionOpts = struct();
bispectraOpts  = struct();

%% ======================== SETUP ========================
startup_puv

registry = deployment_registry();
if ~isKey(registry, deployment_name)
    error('PUV_L4_driver:unknownDeployment', ...
        'Deployment "%s" not found in registry. Available: %s', ...
        deployment_name, strjoin(keys(registry), ', '));
end
configFn = registry(deployment_name);
cfg = configFn();

l1Dir = fullfile(cfg.outputDir, 'L1', cfg.name);
l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
if ~isfolder(l1Dir)
    error('PUV_L4_driver:noL1', ...
        'L1 directory not found: %s\nRun PUV_L1_driver first.', l1Dir);
end
if ~isfolder(l2Dir)
    error('PUV_L4_driver:noL2', ...
        'L2 directory not found: %s\nRun PUV_L2_driver first.', l2Dir);
end

outDir = fullfile(cfg.outputDir, 'L4', cfg.name);
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% ======================== PROCESS EACH INSTRUMENT ========================
nInstr = numel(cfg.instruments);
fprintf('\n=== L4 IG / Bound-Wave Dynamics: %s (%d instruments) ===\n', deployment_name, nInstr);

for k = 1:nInstr
    instr = cfg.instruments(k);
    fprintf('\n[%d/%d] Processing %s - %s\n', k, nInstr, cfg.name, instr.label);

    l1File = fullfile(l1Dir, [instr.label '_processed.mat']);
    l2File = fullfile(l2Dir, [instr.label '_L2.mat']);
    if ~isfile(l1File)
        warning('PUV_L4_driver:noL1File', ...
            'L1 file not found: %s — skipping.', l1File);
        continue
    end
    if ~isfile(l2File)
        warning('PUV_L4_driver:noL2File', ...
            'L2 file not found: %s — skipping.', l2File);
        continue
    end

    try
        fprintf('  Loading L1 + L2...\n');
        l1 = load(l1File, 'PUV');
        l2 = load(l2File, 'L2');
        PUV = l1.PUV;
        L2  = l2.L2;

        % --- L4_eta: pressure → elevation timeseries (3 bands) ---
        fprintf('  L4_eta:        pressure → eta timeseries\n');
        L4 = struct();
        L4.eta        = PUV_L4_eta(PUV, L2, etaOpts);

        % --- L4_reflection: Sheremet incident/reflected split + R²(f) ---
        fprintf('  L4_reflection: Sheremet split + IG flux\n');
        L4.ref        = PUV_L4_reflection(PUV, L2, L4.eta, reflectionOpts);

        % --- L4_bispectra: bicoherence on broadband eta_total ---
        fprintf('  L4_bispectra:  bicoherence + coupling metrics\n');
        L4.bispectra  = PUV_L4_bispectra(L4.eta.eta_total, L2, bispectraOpts);

        % --- Metadata ---
        L4.label          = PUV.label;
        L4.deploymentName = PUV.deploymentName;
        L4.LATLON         = PUV.LATLON;
        L4.doffp          = PUV.doffp;
        L4.shorenormal    = L2.shorenormal;
        if isfield(L2, 'mopStation'), L4.mopStation = L2.mopStation; end
        L4.builtAt        = datetime('now');

        outFile = fullfile(outDir, [instr.label '_L4.mat']);
        save(outFile, 'L4', '-v7.3');
        fprintf('  Saved: %s\n', outFile);

    catch ME
        warning('PUV_L4_driver:instrumentFailed', ...
            'FAILED: %s\nReason: %s', instr.label, ME.message);
        for s = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
        end
    end
end

fprintf('\nDone. L4 processing for %s complete.\n', deployment_name);
