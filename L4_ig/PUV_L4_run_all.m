% PUV_L4_RUN_ALL  Run L4 IG / bound-wave dynamics for all registered deployments.
%
%   Iterates over every deployment in deployment_registry, loads each
%   instrument's L1 and L2 .mat, runs PUV_L4_eta → PUV_L4_reflection →
%   PUV_L4_bispectra → PUV_L4_moments → PUV_L4_velocity_pdf, and writes
%   one _L4.mat per instrument. Already-processed instruments are
%   skipped (idempotent).
% Author: Holden Leslie-Bole, 2026

startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n========================================\n');
fprintf(' PUV L4 IG / Bound-Wave Dynamics — %d deployments\n', nDeploy);
fprintf('========================================\n');

resultStatus = cell(nDeploy, 1);
resultNInstr = zeros(nDeploy, 1);

for d = 1:nDeploy
    dName = deployNames{d};
    fprintf('\n\n=== [%d/%d] %s ===\n', d, nDeploy, dName);

    try
        configFn = registry(dName);
        cfg = configFn();
    catch ME
        fprintf('  ERROR loading config: %s\n', ME.message);
        resultStatus{d} = 'config_error';
        continue
    end

    l1Dir = fullfile(cfg.outputDir, 'L1', cfg.name);
    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~isfolder(l1Dir) || ~isfolder(l2Dir)
        fprintf('  Missing L1 or L2 directory — skipping.\n');
        resultStatus{d} = 'no_input_data';
        continue
    end

    outDir = fullfile(cfg.outputDir, 'L4', cfg.name);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    nInstr = numel(cfg.instruments);
    resultNInstr(d) = nInstr;
    nProcessed = 0;
    nSkipped   = 0;
    nFailed    = 0;

    for k = 1:nInstr
        instr = cfg.instruments(k);
        outFile = fullfile(outDir, [instr.label '_L4.mat']);

        if isfile(outFile)
            fprintf('  [%d/%d] %s — already processed, skipping\n', k, nInstr, instr.label);
            nSkipped = nSkipped + 1;
            continue
        end

        l1File = fullfile(l1Dir, [instr.label '_processed.mat']);
        l2File = fullfile(l2Dir, [instr.label '_L2.mat']);
        if ~isfile(l1File) || ~isfile(l2File)
            fprintf('  [%d/%d] %s — missing L1 or L2 file, skipping\n', k, nInstr, instr.label);
            nFailed = nFailed + 1;
            continue
        end

        fprintf('\n  [%d/%d] Processing %s — %s\n', k, nInstr, cfg.name, instr.label);

        try
            l1 = load(l1File, 'PUV');
            l2 = load(l2File, 'L2');
            PUV = l1.PUV;
            L2  = l2.L2;

            L4 = struct();
            L4.eta       = PUV_L4_eta(PUV, L2);
            L4.ref       = PUV_L4_reflection(PUV, L2, L4.eta);
            L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2);
            L4.moments   = PUV_L4_moments(L2);
            L4.pdf       = PUV_L4_velocity_pdf(PUV, L2);

            L4.label          = PUV.label;
            L4.deploymentName = PUV.deploymentName;
            L4.LATLON         = PUV.LATLON;
            L4.doffp          = PUV.doffp;
            L4.shorenormal    = L2.shorenormal;
            if isfield(L2, 'mopStation'), L4.mopStation = L2.mopStation; end
            L4.builtAt        = datetime('now');

            save(outFile, 'L4', '-v7.3');
            nProcessed = nProcessed + 1;
        catch ME
            warning('PUV_L4_run_all:failed', '%s/%s: %s', dName, instr.label, ME.message);
            nFailed = nFailed + 1;
        end
    end

    resultStatus{d} = sprintf('%d ok, %d skip, %d fail', nProcessed, nSkipped, nFailed);
    fprintf('\n  Summary: %s\n', resultStatus{d});
end

%% Summary
fprintf('\n\n========================================\n');
fprintf(' L4 IG / Bound-Wave Dynamics Complete\n');
fprintf('========================================\n');
fprintf('  %-10s  %6s  %s\n', 'Deploy', 'Instr', 'Status');
fprintf('  %s\n', repmat('-', 1, 45));
for d = 1:nDeploy
    fprintf('  %-10s  %6d  %s\n', deployNames{d}, resultNInstr(d), resultStatus{d});
end
fprintf('\n');
