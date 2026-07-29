% PUV_L2_RERUN_FOR_ZFIX  One-time reprocess of all non-TBR23 deployments to
% pick up the corrected Z-test formula (see PIPELINE_NOTES.md, 2026-06-05).
%
% TBR23 was already reprocessed interactively; this script handles the
% remaining ~38 PUV files. It mirrors PUV_L2_run_all but overwrites existing
% L2 .mat files instead of skipping them, since the existing files contain
% the buggy ztest_SS/ztest_IG values.
%
% Total wall time estimate: 3-4 hours serially. Intended for overnight.
%
% Run from PUV_Pipeline repo root:
%   >> startup_puv
%   >> PUV_L2_rerun_for_Zfix
%
% After this completes, the buggy ztest values are gone from disk and the
% pipeline is consistent with the synthetic-input closure test
% (L2_spectral/test_ztest_linear.m).
%
% Author: Holden Leslie-Bole, 2026-06-05

%% ======================== SETUP ========================
startup_puv

SKIP_DEPLOY = {'TBR23'};   % already done interactively
registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n========================================\n');
fprintf(' PUV L2 Z-fix rerun — %d deployments (skipping %s)\n', ...
    nDeploy, strjoin(SKIP_DEPLOY, ', '));
fprintf(' Started: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('========================================\n');

opts = struct();

resultStatus  = cell(nDeploy, 1);
resultNInstr  = zeros(nDeploy, 1);
overall_t0    = tic;

for d = 1:nDeploy
    dName = deployNames{d};
    if any(strcmp(dName, SKIP_DEPLOY))
        fprintf('\n=== [%d/%d] %s — SKIP (already reprocessed) ===\n', d, nDeploy, dName);
        resultStatus{d} = 'skipped';
        continue
    end
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
    nFailed    = 0;

    for k = 1:nInstr
        instr = cfg.instruments(k);
        outFile = fullfile(outDir, [instr.label '_L2.mat']);
        l1File  = fullfile(l1Dir, [instr.label '_processed.mat']);
        if ~isfile(l1File)
            fprintf('  [%d/%d] %s — no L1 file, skipping\n', k, nInstr, instr.label);
            nFailed = nFailed + 1;
            continue
        end

        fprintf('\n  [%d/%d] Processing %s — %s\n', k, nInstr, cfg.name, instr.label);
        t0 = tic;
        try
            loaded = load(l1File, 'PUV');
            L2 = PUV_L2_spectral(loaded.PUV, instr, opts);
            save(outFile, 'L2', '-v7.3');
            fprintf('  Saved: %s (%.1f min)\n', outFile, toc(t0)/60);
            nProcessed = nProcessed + 1;
        catch ME
            warning('PUV_L2_rerun_for_Zfix:instrumentFailed', ...
                'FAILED: %s — %s\nReason: %s', cfg.name, instr.label, ME.message);
            nFailed = nFailed + 1;
        end
    end

    resultStatus{d} = sprintf('%d ok, %d fail', nProcessed, nFailed);
    fprintf('\n  Deployment summary: %s\n', resultStatus{d});
end

%% ======================== FINAL SUMMARY ========================
fprintf('\n\n========================================\n');
fprintf(' L2 Z-fix Rerun Complete\n');
fprintf(' Finished: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(' Total wall time: %.1f hours\n', toc(overall_t0)/3600);
fprintf('========================================\n');
fprintf('  %-12s  %6s  %s\n', 'Deploy', 'Instr', 'Status');
fprintf('  %s\n', repmat('-', 1, 45));
for d = 1:nDeploy
    fprintf('  %-12s  %6d  %s\n', deployNames{d}, resultNInstr(d), resultStatus{d});
end
fprintf('\n');
