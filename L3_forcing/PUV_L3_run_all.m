% PUV_L3_RUN_ALL  Run L3 forcing characterization for all registered deployments.

startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n========================================\n');
fprintf(' PUV L3 Forcing Characterization — %d deployments\n', nDeploy);
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

    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~isfolder(l2Dir)
        fprintf('  No L2 directory — skipping.\n');
        resultStatus{d} = 'no_L2_data';
        continue
    end

    outDir = fullfile(cfg.outputDir, 'L3', cfg.name);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    nInstr = numel(cfg.instruments);
    resultNInstr(d) = nInstr;
    nProcessed = 0;
    nSkipped   = 0;
    nFailed    = 0;

    for k = 1:nInstr
        instr = cfg.instruments(k);
        outFile = fullfile(outDir, [instr.label '_L3.mat']);

        if isfile(outFile)
            fprintf('  [%d/%d] %s — already processed, skipping\n', k, nInstr, instr.label);
            nSkipped = nSkipped + 1;
            continue
        end

        l2File = fullfile(l2Dir, [instr.label '_L2.mat']);
        if ~isfile(l2File)
            fprintf('  [%d/%d] %s — no L2 file, skipping\n', k, nInstr, instr.label);
            nFailed = nFailed + 1;
            continue
        end

        fprintf('\n  [%d/%d] Processing %s — %s\n', k, nInstr, cfg.name, instr.label);

        try
            loaded = load(l2File, 'L2');
            L2 = loaded.L2;

            L3 = PUV_L3_bands(L2);
            L3 = PUV_L3_storms(L3, L2);
            L3 = PUV_L3_transport(L3, L2);

            save(outFile, 'L3', '-v7.3');
            nProcessed = nProcessed + 1;
        catch ME
            warning('PUV_L3_run_all:failed', '%s/%s: %s', dName, instr.label, ME.message);
            nFailed = nFailed + 1;
        end
    end

    resultStatus{d} = sprintf('%d ok, %d skip, %d fail', nProcessed, nSkipped, nFailed);
    fprintf('\n  Summary: %s\n', resultStatus{d});
end

%% Summary
fprintf('\n\n========================================\n');
fprintf(' L3 Forcing Characterization Complete\n');
fprintf('========================================\n');
fprintf('  %-10s  %6s  %s\n', 'Deploy', 'Instr', 'Status');
fprintf('  %s\n', repmat('-', 1, 45));
for d = 1:nDeploy
    fprintf('  %-10s  %6d  %s\n', deployNames{d}, resultNInstr(d), resultStatus{d});
end
fprintf('\n');
