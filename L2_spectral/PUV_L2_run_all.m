% PUV_L2_RUN_ALL  Run L2 spectral processing for all registered deployments.
%
%   Loops through every deployment in the registry and runs PUV_L2_spectral
%   for each instrument. Skips instruments that already have L2 output files
%   or deployments with no L1 data.
%
%   Each saved file carries provenance (shared/save_with_provenance): an
%   embedded .prov block and a <file>.prov.json sidecar, as scripts/copy_to_server
%   requires. Instruments flagged knownFailed in the config are skipped.
%
%   Run from the PUV_Pipeline repo root:
%     >> startup_puv
%     >> PUV_L2_run_all
% Author: Holden Leslie-Bole, 2026

%% ======================== SETUP ========================
startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n========================================\n');
fprintf(' PUV L2 Spectral Processing — %d deployments\n', nDeploy);
fprintf('========================================\n');

opts = struct();  % default opts for all deployments

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

    % Check for L1 data
    l1Dir = fullfile(cfg.outputDir, 'L1', cfg.name);
    if ~isfolder(l1Dir)
        fprintf('  No L1 directory — skipping.\n');
        resultStatus{d} = 'no_L1_data';
        continue
    end

    outDir = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    nInstr = numel(cfg.instruments);
    resultNInstr(d) = nInstr;
    nProcessed = 0;
    nSkipped   = 0;
    nFailed    = 0;
    failedLabs = {};   % labels of records not written (named in the final error)
    nKnown     = 0;

    for k = 1:nInstr
        instr = cfg.instruments(k);
        outFile = fullfile(outDir, [instr.label '_L2.mat']);
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

        l1File = fullfile(l1Dir, [instr.label '_processed.mat']);
        if ~isfile(l1File)
            fprintf('  [%d/%d] %s — no L1 file, skipping\n', k, nInstr, instr.label);
            nFailed = nFailed + 1;
            failedLabs{end+1} = instr.label; %#ok<SAGROW>
            continue
        end

        fprintf('\n  [%d/%d] Processing %s — %s\n', k, nInstr, cfg.name, instr.label);

        try
            loaded = load(l1File, 'PUV');
            L2 = PUV_L2_spectral(loaded.PUV, instr, opts);
            save_with_provenance(outFile, 'L2', 'L2', L2, struct('level', 'L1', 'path', l1File), instr);
            fprintf('  Saved: %s\n', outFile);
            nProcessed = nProcessed + 1;
        catch ME
            warning('PUV_L2_run_all:instrumentFailed', ...
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
fprintf(' L2 Spectral Processing Complete\n');
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
    error('PUV_L2_run_all:failures', '%d problem(s); details in the log above:\n  %s', ...
        numel(problems), strjoin(problems, '\n  '));
end
