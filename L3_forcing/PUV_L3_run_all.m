% PUV_L3_RUN_ALL  Run L3 forcing characterization for all registered deployments.
%
%   Each saved file carries provenance (shared/save_with_provenance): an
%   embedded .prov block and a <file>.prov.json sidecar, as scripts/copy_to_server
%   requires. Instruments flagged knownFailed in the config are skipped.
%   The NOAA tide station is each config's cfg.tideStation (l3_currents_opts).
%
% Author: Holden Leslie-Bole, 2026

startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n========================================\n');
fprintf(' PUV L3 Forcing Characterization — %d deployments\n', nDeploy);
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

    % config's own L1 Tvalid for the L3 viscosity (default [-2 40] otherwise)
    l3Opts = struct('Tvalid', l1_qc_opts(cfg).Tvalid);
    tideOpts = l3_currents_opts(cfg);   % cfg.tideStation (NOAA id) for PUV_L3_currents

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
    failedLabs = {};   % labels of records not written (named in the final error)
    nKnown     = 0;

    for k = 1:nInstr
        instr = cfg.instruments(k);
        outFile = fullfile(outDir, [instr.label '_L3.mat']);
        [isKF, kfWhy] = known_failed(instr);
        if isKF
            fprintf('  [%d/%d] %s — KNOWN FAILED, skipped: %s\n', k, nInstr, instr.label, kfWhy);
            nKnown = nKnown + 1;
            continue
        end

        if isfile(outFile)
            fprintf('  [%d/%d] %s — already processed, skipping\n', k, nInstr, instr.label);
            nSkipped = nSkipped + 1;
            continue
        end

        l2File = fullfile(l2Dir, [instr.label '_L2.mat']);
        if ~isfile(l2File)
            fprintf('  [%d/%d] %s — no L2 file, skipping\n', k, nInstr, instr.label);
            nFailed = nFailed + 1;
            failedLabs{end+1} = instr.label; %#ok<SAGROW>
            continue
        end

        fprintf('\n  [%d/%d] Processing %s — %s\n', k, nInstr, cfg.name, instr.label);

        try
            loaded = load(l2File, 'L2');
            L2 = loaded.L2;

            L3 = PUV_L3_bands(L2);
            L3 = PUV_L3_storms(L3, L2);
            L3 = PUV_L3_transport(L3, L2, l3Opts);
            L3 = PUV_L3_currents(L3, L2, tideOpts);

            save_with_provenance(outFile, 'L3', 'L3', L3, struct('level', 'L2', 'path', l2File), instr);
            nProcessed = nProcessed + 1;
        catch ME
            warning('PUV_L3_run_all:failed', '%s/%s: %s', dName, instr.label, ME.message);
            nFailed = nFailed + 1;
            failedLabs{end+1} = instr.label; %#ok<SAGROW>
        end
    end

    resultStatus{d} = sprintf('%d ok, %d skip, %d known-failed, %d fail', nProcessed, nSkipped, nKnown, nFailed);
    if nFailed > 0, problems{end+1} = sprintf('%s: %d record(s) failed: %s', dName, nFailed, strjoin(failedLabs, ', ')); end %#ok<SAGROW>
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

% Fail loudly. Every deployment and record runs inside try/catch so one failure
% cannot abort the batch, but a config that throws or a record that fails must
% not end the run looking like success (TOR18A, 2026-07-27, was invisible for a
% day this way). An error here makes `matlab -batch` exit nonzero.
if ~isempty(problems)
    error('PUV_L3_run_all:failures', '%d problem(s); details in the log above:\n  %s', ...
        numel(problems), strjoin(problems, '\n  '));
end
