% RERUN_TBR23_PHASE_20260626  Reprocess the 4 TBR23 PUVs to pick up the new
% P-U cross-spectral phase diagnostic (L2.phase_PU + full complex L2.Spu),
% added to PUV_L2_spectral.m on 2026-06-26 for the Bob/Steve velocity-QC
% thread (B3). Closure-tested by L2_spectral/test_phase_PU_linear.m.
%
% This is an ADDITIVE change: every pre-existing L2 field (spectra, bulk
% params, ztest_SS, qtest_PU, ...) is recomputed identically. The script
% backs up the current L2 files, reprocesses with opts.storeXspec=true, and
% prints a REGRESSION CHECK comparing new vs old medians of ztest_SS,
% qtest_PU and Hs. If those do not match to ~1e-6 something changed
% unexpectedly -- investigate before keeping the new files.
%
% Run from PUV_Pipeline repo root:
%   >> startup_puv
%   >> rerun_TBR23_phase_20260626
%
% Author: Holden Leslie-Bole, 2026-06-26

startup_puv

DEPLOY  = 'TBR23';
bkpDir  = fullfile(tempdir, 'TBR23_L2_backup_20260626');
if ~isfolder(bkpDir), mkdir(bkpDir); end

registry = deployment_registry();
configFn = registry(DEPLOY);
cfg      = configFn();

l1Dir  = fullfile(cfg.outputDir, 'L1', cfg.name);
outDir = fullfile(cfg.outputDir, 'L2', cfg.name);

opts = struct('storeXspec', true);   % retain full complex Spu for phase plots

fprintf('\n=== TBR23 phase reprocess (%s) ===\n', datestr(now,'yyyy-mm-dd HH:MM'));
fprintf('Backup dir: %s\n', bkpDir);

nInstr = numel(cfg.instruments);
for k = 1:nInstr
    instr   = cfg.instruments(k);
    outFile = fullfile(outDir, [instr.label '_L2.mat']);
    l1File  = fullfile(l1Dir,  [instr.label '_processed.mat']);
    if ~isfile(l1File)
        fprintf('  [%d/%d] %s -- no L1 file, skipping\n', k, nInstr, instr.label);
        continue
    end

    % --- regression baseline: old medians (valid segs) ---
    old = load(outFile, 'L2');  oldL2 = old.L2;
    ov  = oldL2.segValid(:) == 1;
    zo  = median(oldL2.ztest_SS(ov), 'omitnan');
    qo  = median(oldL2.qtest_PU(ov), 'omitnan');
    ho  = median(oldL2.Hs(ov),       'omitnan');
    copyfile(outFile, fullfile(bkpDir, [instr.label '_L2.mat']));

    % --- reprocess ---
    fprintf('\n  [%d/%d] %s\n', k, nInstr, instr.label);
    t0 = tic;
    loaded = load(l1File, 'PUV');
    L2 = PUV_L2_spectral(loaded.PUV, instr, opts);

    % --- regression check vs old ---
    nv = L2.segValid(:) == 1;
    zn = median(L2.ztest_SS(nv), 'omitnan');
    qn = median(L2.qtest_PU(nv), 'omitnan');
    hn = median(L2.Hs(nv),       'omitnan');
    dz = abs(zn-zo); dq = abs(qn-qo); dh = abs(hn-ho);
    ok = (dz < 1e-6) && (dq < 1e-6) && (dh < 1e-6);
    fprintf('    regression: dZ=%.2e dQ=%.2e dHs=%.2e  %s\n', dz, dq, dh, ...
        ternary(ok,'OK','*** MISMATCH ***'));

    % --- new phase diagnostic summary ---
    ph = L2.phase_PU(nv);
    fprintf('    phase_PU (deg): median %.1f  IQR [%.1f, %.1f]  |  Spu stored: %d x %d\n', ...
        median(ph,'omitnan'), prctile(ph,25), prctile(ph,75), size(L2.Spu,1), size(L2.Spu,2));

    if ~ok
        warning('Regression mismatch for %s -- NOT overwriting. Old file preserved; new L2 in workspace var L2_%s.', instr.label, instr.label);
        assignin('base', ['L2_' instr.label], L2);
        continue
    end
    save(outFile, 'L2', '-v7.3');
    fprintf('    saved %s (%.1f min)\n', outFile, toc(t0)/60);
end
fprintf('\nDone. Backups in %s\n', bkpDir);

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
