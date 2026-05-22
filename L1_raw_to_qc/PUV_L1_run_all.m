% PUV_L1_RUN_ALL  Run L1 processing for all registered deployments.
%
%   Loops through every deployment in the registry and runs PUV_L1_driver
%   logic for each. Skips deployments that already have output files.
%
%   Run from the PUV_Pipeline repo root:
%     >> startup_puv
%     >> PUV_L1_run_all
%
%   To process from local cache (faster), copy raw files for each deployment:
%     >> reg = deployment_registry(); cfg = reg('SIO24A')();
%     >> copy_raw_to_local(cfg);   % repeat per deployment as needed
% Author: Holden Leslie-Bole, 2026

%% ======================== SETUP ========================
startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n========================================\n');
fprintf(' PUV L1 Processing — %d deployments\n', nDeploy);
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

    % Check for local cache
    localCache = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'raw_cache', cfg.name);
    if isfolder(localCache)
        cfg.localDataRoot = localCache;
        fprintf('  Using local cache: %s\n', localCache);
    end

    outDir = fullfile(cfg.outputDir, 'L1', cfg.name);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    diagDir = fullfile(cfg.outputDir, 'L1', 'diagnostics');
    if ~exist(diagDir, 'dir'), mkdir(diagDir); end

    nInstr = numel(cfg.instruments);
    resultNInstr(d) = nInstr;
    nProcessed = 0;
    nSkipped   = 0;
    nFailed    = 0;

    for k = 1:nInstr
        instr = cfg.instruments(k);
        outFile = fullfile(outDir, [instr.label '_processed.mat']);

        % Skip if output already exists
        if isfile(outFile)
            fprintf('  [%d/%d] %s — already processed, skipping\n', k, nInstr, instr.label);
            nSkipped = nSkipped + 1;
            continue
        end

        fprintf('\n  [%d/%d] Processing %s — %s\n', k, nInstr, cfg.name, instr.label);

        try
            PUV = PUV_raw_process(instr, cfg);
            save(outFile, 'PUV', '-v7.3');
            fprintf('  Saved: %s\n', outFile);
            nProcessed = nProcessed + 1;
        catch ME
            warning('PUV_L1_run_all:instrumentFailed', ...
                'FAILED: %s — %s\nReason: %s', cfg.name, instr.label, ME.message);
            nFailed = nFailed + 1;
        end
    end

    resultStatus{d} = sprintf('%d ok, %d skip, %d fail', nProcessed, nSkipped, nFailed);
    fprintf('\n  Summary: %s\n', resultStatus{d});
end

%% ======================== FINAL SUMMARY ========================
fprintf('\n\n========================================\n');
fprintf(' L1 Processing Complete\n');
fprintf('========================================\n');
fprintf('  %-10s  %6s  %s\n', 'Deploy', 'Instr', 'Status');
fprintf('  %s\n', repmat('-', 1, 45));
for d = 1:nDeploy
    fprintf('  %-10s  %6d  %s\n', deployNames{d}, resultNInstr(d), resultStatus{d});
end
fprintf('\n');
