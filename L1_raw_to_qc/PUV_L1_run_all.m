% PUV_L1_RUN_ALL  Run L1 processing for all registered deployments.
%
%   Loops through every deployment in the registry and runs PUV_L1_driver
%   logic for each. Skips deployments that already have output files.
%
%   Each saved file carries provenance (shared/save_with_provenance): an
%   embedded .prov block and a <file>.prov.json sidecar, as scripts/copy_to_server
%   requires. Instruments flagged knownFailed in the config are skipped.
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
problems     = {};   % config errors and failed records, reported at the end

for d = 1:nDeploy
    dName = deployNames{d};
    fprintf('\n\n=== [%d/%d] %s ===\n', d, nDeploy, dName);

    try
        configFn = registry(dName);
        cfg = configFn();
    catch ME
        fprintf('  ERROR loading config: %s\n', ME.message);
        resultStatus{d} = 'config_error';
        problems{end+1} = sprintf('%s: config error: %s', dName, ME.message); %#ok<SAGROW>
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
    failedLabs = {};   % labels of records not written (named in the final error)
    nKnown     = 0;

    for k = 1:nInstr
        instr = cfg.instruments(k);
        outFile = fullfile(outDir, [instr.label '_processed.mat']);
        [isKF, kfWhy] = known_failed(instr);
        if isKF
            fprintf('  [%d/%d] %s — KNOWN FAILED, skipped: %s\n', k, nInstr, instr.label, kfWhy);
            nKnown = nKnown + 1;
            continue
        end

        % Skip if output already exists
        if isfile(outFile)
            fprintf('  [%d/%d] %s — already processed, skipping\n', k, nInstr, instr.label);
            nSkipped = nSkipped + 1;
            continue
        end

        fprintf('\n  [%d/%d] Processing %s — %s\n', k, nInstr, cfg.name, instr.label);

        try
            PUV = PUV_raw_process(instr, cfg);
            save_with_provenance(outFile, 'L1', 'PUV', PUV, [], instr);
            fprintf('  Saved: %s\n', outFile);
            nProcessed = nProcessed + 1;
        catch ME
            warning('PUV_L1_run_all:instrumentFailed', ...
                'FAILED: %s — %s\nReason: %s', cfg.name, instr.label, ME.message);
            nFailed = nFailed + 1;
            failedLabs{end+1} = instr.label; %#ok<SAGROW>
        end
    end

    resultStatus{d} = sprintf('%d ok, %d skip, %d known-failed, %d fail', nProcessed, nSkipped, nKnown, nFailed);
    if nFailed > 0, problems{end+1} = sprintf('%s: %d record(s) failed: %s', dName, nFailed, strjoin(failedLabs, ', ')); end %#ok<SAGROW>
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

% Fail loudly. Every deployment and record runs inside try/catch so one failure
% cannot abort the batch, but a config that throws or a record that fails must
% not end the run looking like success (TOR18A, 2026-07-27, was invisible for a
% day this way). An error here makes `matlab -batch` exit nonzero.
if ~isempty(problems)
    error('PUV_L1_run_all:failures', '%d problem(s); details in the log above:\n  %s', ...
        numel(problems), strjoin(problems, '\n  '));
end
