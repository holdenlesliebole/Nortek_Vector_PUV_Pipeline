% RERUN_CATALINA_FIX_2026_07_27  Propagate the corrected CAT21A/B site geometry.
%
%   CAT21A and CAT21B were built on placeholder geometry that was never filled
%   in. Resolved 2026-07-27 from DeploymentNotes2020-2021.xls (see
%   CAT21A_config.m for the sourcing and the two lines of evidence that both
%   records are S/N 15032):
%
%     latlon  [33.45, -118.50]  ->  [33.334072, -118.309038]   (21.9 km error)
%     doffp   0.75              ->  0.71
%     serial  NaN               ->  15032
%     depth_nominal NaN         ->  7
%
%   `heading` stays NaN (auto from the .sen compass) — the compass and the
%   surveyed value differ by only ~10 deg, which is not evidence the compass is
%   wrong. `clockDrift` stays NaN — the notes record it as unknown for 15032.
%
%   Only `doffp` and `latlon` are carried in the L1 struct, and neither is used
%   by any L1 computation (PUV_raw_process just copies them), so the raw
%   binaries do NOT need re-decoding. This patches the L1 scalars from the
%   config and rebuilds L2 -> L3 -> L4.
%
%   Expected impact: depth shifts by exactly -0.04 m; Hs moves a few tenths of a
%   percent. The substantive fix is the position, which propagates to L4.LATLON
%   and the server manifest.
%
%   Backups to outputs/_pre_catalina_backup_2026-07-27/.
%
%   Run from PUV_Pipeline/ (~30 min, dominated by CAT21A bispectra):
%     >> run scripts/rerun_catalina_fix_2026_07_27

startup_puv

outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
bkRoot  = fullfile(outRoot, '_pre_catalina_backup_2026-07-27');
REC = {'CAT21A','CAT_isl'; 'CAT21B','CAT_isl'};

if isempty(gcp('nocreate')), parpool('Processes'); end
fprintf('\n=== Catalina geometry rerun ===\n');
tAll = tic; reg = deployment_registry(); nOk = 0; nFail = 0;

for r = 1:size(REC,1)
    dep = REC{r,1}; lab = REC{r,2};
    fprintf('\n[%d/%d] %s/%s\n', r, size(REC,1), dep, lab);
    try
        fn = reg(dep); cfg = fn();
        ii = find(strcmp({cfg.instruments.label}, lab), 1);
        instr = cfg.instruments(ii);

        l1Path = fullfile(outRoot,'L1',dep,[lab '_processed.mat']);
        l2Path = fullfile(outRoot,'L2',dep,[lab '_L2.mat']);
        l3Path = fullfile(outRoot,'L3',dep,[lab '_L3.mat']);
        l4Path = fullfile(outRoot,'L4',dep,[lab '_L4.mat']);

        for f = {l1Path, l2Path, l3Path, l4Path}
            if ~isfile(f{1}), continue, end
            rel = extractAfter(f{1}, [outRoot filesep]);
            dst = fullfile(bkRoot, rel);
            if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
            if ~isfile(dst), copyfile(f{1}, dst); end
        end

        S1 = load(l1Path,'PUV'); PUV = S1.PUV;
        oldD = PUV.doffp; oldLL = PUV.LATLON(:).';
        PUV.doffp  = instr.doffp;
        PUV.LATLON = instr.latlon(:);
        save(l1Path,'PUV','-v7.3');
        fprintf('  L1 patched: doffp %.2f -> %.2f | latlon %s -> %s\n', ...
            oldD, PUV.doffp, mat2str(oldLL,6), mat2str(PUV.LATLON(:).',6));

        t0 = tic;
        L2 = PUV_L2_spectral(PUV, instr, struct());
        save(l2Path,'L2','-v7.3');
        fprintf('  L2 (%.1f min) %d/%d valid\n', toc(t0)/60, sum(L2.segValid), numel(L2.time));

        t0 = tic;
        L3 = PUV_L3_bands(L2); L3 = PUV_L3_storms(L3, L2);
        L3 = PUV_L3_transport(L3, L2); L3 = PUV_L3_currents(L3, L2);
        save(l3Path,'L3','-v7.3');
        fprintf('  L3 (%.0f s)\n', toc(t0));

        t0 = tic;
        L4 = struct();
        L4.eta = PUV_L4_eta(PUV, L2);
        L4.ref = PUV_L4_reflection(PUV, L2, L4.eta);
        L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2, struct('useParallel',true));
        L4.moments = PUV_L4_moments(L2);
        L4.pdf = PUV_L4_velocity_pdf(PUV, L2);
        L4.boundwave = PUV_L4_boundwave(L4.eta, L2, PUV);
        L4.reflection_free = PUV_L4_reflection_free(PUV, L2, L4.eta, L4.boundwave);
        L4.label = PUV.label; L4.deploymentName = PUV.deploymentName;
        L4.LATLON = PUV.LATLON; L4.doffp = PUV.doffp; L4.shorenormal = L2.shorenormal;
        if isfield(L2,'mopStation'), L4.mopStation = L2.mopStation; end
        L4.builtAt = datetime('now');
        save(l4Path,'L4','-v7.3');
        fprintf('  L4 (%.1f min)\n', toc(t0)/60);

        [~, ai] = l4_l2_index_map(L2, L4);
        qc = ztest_record_flag(L2.ztest_SS, L2.segValid);
        fprintf('  medHs=%.4f medDepth=%.3f aligned=%d Z=%s\n', ...
            median(L2.Hs(L2.segValid),'omitnan'), median(L2.depth(L2.segValid),'omitnan'), ...
            ai.identity, qc.status);
        nOk = nOk + 1;
    catch ME
        fprintf(2,'  FAIL: %s\n', ME.message);
        for s = 1:numel(ME.stack), fprintf(2,'    %s (line %d)\n', ME.stack(s).name, ME.stack(s).line); end
        nFail = nFail + 1;
    end
end
fprintf('\n=== Done in %.2f h: %d ok, %d failed ===\n', toc(tAll)/3600, nOk, nFail);
