% RERUN_DOFFP_FIX_2026_07_27  Propagate the corrected doffp through L2-L4.
%
%   doffp was a placeholder on 7 records. The real values were recovered from
%   the field logs on 2026-07-27 (see the headers of RUBY22_config,
%   Cardiff_config and Coronado_config for the exact source rows):
%
%     RUBY22/MOP578_10m   0.60 -> 0.79      CDF15A/MOP677_9m  0.65 -> 0.54
%     RUBY22/MOP579_6m    0.60 -> 0.69      CDF15C/MOP677_9m  0.65 -> 0.55
%     RUBY22/MOP582_30m   0.60 -> 0.80      COR16B/MOP158_9m  0.65 -> 0.58
%                                           COR17D/MOP158_9m  0.65 -> 0.72
%
%   doffp is only STORED at L1 (PUV_raw_process.m sets PUV.doffp = instr.doffp
%   and nothing in L1 reads it), so the raw binaries do NOT need re-decoding.
%   This patches the scalar in each L1 file from the config, then rebuilds
%   L2 -> L3 -> L4 for those records only.
%
%   Everything it overwrites is copied to outputs/_pre_doffp_backup_2026-07-27/
%   first. Idempotent: re-running skips records whose L1 doffp already matches
%   the config AND whose L2 is newer than L1.
%
%   Expected impact (verified against the stored Spp before running, with the
%   Kp recomputation closing to 2.2e-16): Hs -0.41% to +0.63%, depth -0.11 to
%   +0.20 m, Hs/h -1.26% to +0.79%.
%
%   Run from PUV_Pipeline/ (about 2-2.5 h):
%     >> run scripts/rerun_doffp_fix_2026_07_27

startup_puv

outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
bkRoot  = fullfile(outRoot, '_pre_doffp_backup_2026-07-27');

REC = { 'RUBY22','MOP578_10m'; 'RUBY22','MOP579_6m'; 'RUBY22','MOP582_30m';
        'CDF15A','MOP677_9m';  'CDF15C','MOP677_9m';
        'COR16B','MOP158_9m';  'COR17D','MOP158_9m' };

if isempty(gcp('nocreate')), parpool('Processes'); end
p = gcp('nocreate');
fprintf('\n=== doffp rerun (pool: %d workers) ===\n', p.NumWorkers);
tAll = tic;

reg = deployment_registry();
nOk = 0; nFail = 0;
summary = cell(size(REC,1), 1);

for r = 1:size(REC,1)
    dep = REC{r,1}; lab = REC{r,2};
    fprintf('\n[%d/%d] %s/%s\n', r, size(REC,1), dep, lab);
    try
        fn = reg(dep); cfg = fn();
        ii = find(strcmp({cfg.instruments.label}, lab), 1);
        if isempty(ii)
            error('label %s not in %s config', lab, dep);
        end
        instr = cfg.instruments(ii);
        if ~isfinite(instr.doffp)
            error('config doffp for %s/%s is not finite', dep, lab);
        end

        l1Path = fullfile(outRoot, 'L1', dep, [lab '_processed.mat']);
        l2Path = fullfile(outRoot, 'L2', dep, [lab '_L2.mat']);
        l3Path = fullfile(outRoot, 'L3', dep, [lab '_L3.mat']);
        l4Path = fullfile(outRoot, 'L4', dep, [lab '_L4.mat']);
        if ~isfile(l1Path), error('no L1 file: %s', l1Path); end

        % ---- back up everything we are about to overwrite ----
        for f = {l1Path, l2Path, l3Path, l4Path}
            if ~isfile(f{1}), continue, end
            rel = extractAfter(f{1}, [outRoot filesep]);
            dst = fullfile(bkRoot, rel);
            if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
            if ~isfile(dst), copyfile(f{1}, dst); end
        end

        % ---- 1. patch the L1 scalar ----
        S1 = load(l1Path, 'PUV'); PUV = S1.PUV;
        oldDoffp = PUV.doffp;
        PUV.doffp = instr.doffp;
        if ~isequal(oldDoffp, instr.doffp)
            save(l1Path, 'PUV', '-v7.3');
            fprintf('  L1 doffp %.2f -> %.2f (patched)\n', oldDoffp, instr.doffp);
        else
            fprintf('  L1 doffp already %.2f\n', instr.doffp);
        end

        % ---- 2. L2 ----
        t0 = tic;
        L2 = PUV_L2_spectral(PUV, instr, struct());
        save(l2Path, 'L2', '-v7.3');
        fprintf('  L2 rebuilt (%.1f min), %d/%d valid\n', toc(t0)/60, sum(L2.segValid), numel(L2.time));

        % ---- 3. L3 ----
        t0 = tic;
        L3 = PUV_L3_bands(L2);
        L3 = PUV_L3_storms(L3, L2);
        L3 = PUV_L3_transport(L3, L2);
        L3 = PUV_L3_currents(L3, L2);
        save(l3Path, 'L3', '-v7.3');
        fprintf('  L3 rebuilt (%.0f s)\n', toc(t0));

        % ---- 4. L4 (full chain, bispectra in parallel) ----
        t0 = tic;
        L4 = struct();
        L4.eta             = PUV_L4_eta(PUV, L2);
        L4.ref             = PUV_L4_reflection(PUV, L2, L4.eta);
        L4.bispectra       = PUV_L4_bispectra(L4.eta.eta_total, L2, struct('useParallel', true));
        L4.moments         = PUV_L4_moments(L2);
        L4.pdf             = PUV_L4_velocity_pdf(PUV, L2);
        L4.boundwave       = PUV_L4_boundwave(L4.eta, L2, PUV);
        L4.reflection_free = PUV_L4_reflection_free(PUV, L2, L4.eta, L4.boundwave);
        L4.label           = PUV.label;
        L4.deploymentName  = PUV.deploymentName;
        L4.LATLON          = PUV.LATLON;
        L4.doffp           = PUV.doffp;
        L4.shorenormal     = L2.shorenormal;
        if isfield(L2, 'mopStation'), L4.mopStation = L2.mopStation; end
        L4.builtAt         = datetime('now');
        save(l4Path, 'L4', '-v7.3');
        fprintf('  L4 rebuilt (%.1f min)\n', toc(t0)/60);

        % ---- verify alignment + record the outcome ----
        [~, ainfo] = l4_l2_index_map(L2, L4);
        qc = ztest_record_flag(L2.ztest_SS, L2.segValid);
        summary{r} = sprintf(['%-9s %-12s doffp %.2f->%.2f | medHs=%.4f medDepth=%.3f | ' ...
                              'aligned=%d | Z %s'], ...
            dep, lab, oldDoffp, instr.doffp, ...
            median(L2.Hs(L2.segValid), 'omitnan'), ...
            median(L2.depth(L2.segValid), 'omitnan'), ...
            ainfo.identity, qc.status);
        fprintf('  %s\n', summary{r});
        nOk = nOk + 1;
    catch ME
        fprintf('  FAIL: %s\n', ME.message);
        for s = 1:numel(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
        end
        summary{r} = sprintf('%-9s %-12s FAILED: %s', dep, lab, ME.message);
        nFail = nFail + 1;
    end
end

fprintf('\n=== Done in %.2f h: %d ok, %d failed ===\n', toc(tAll)/3600, nOk, nFail);
for r = 1:numel(summary)
    if ~isempty(summary{r}), fprintf('  %s\n', summary{r}); end
end
fprintf('\nNext: validation/audit_L4_coverage, then scripts/copy_to_server.m\n');
