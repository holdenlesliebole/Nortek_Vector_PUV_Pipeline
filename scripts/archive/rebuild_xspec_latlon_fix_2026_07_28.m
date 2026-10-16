% REBUILD_XSPEC_LATLON_FIX_2026_07_28  Rebuild L4_xspec after the coordinate fix.
%
%   `PUV_L4_xspec` derives every pair's cross-shore, alongshore and total
%   separation from the stored LATLON. Four deployments carried coordinates
%   that had been rounded to 3 decimals (~100 m) or eyeballed outright, so
%   their separations were wrong -- worst case MOP586 7m-10m, which came out
%   93 m against a surveyed 143 m, 35% short. Any phase- or
%   coherence-versus-separation result from these is affected.
%
%   The surveyed positions were recovered on 2026-07-28 from
%   /Volumes/group/DeploymentNotes/*.xls, sheet 'All Data'. The instruments were
%   reinstalled on the same jetted pipes season to season, so the survey carries
%   across years; only the transcription was lossy.
%
%   `scripts/patch_stored_latlon.py` has already corrected LATLON in L1/L2/L4
%   in place. Nothing else in L1-L4 reads it, so this is the only rebuild.
%
%   Before/after separations are printed for every pair so the size of the
%   correction is on the record.
%
%   Run from PUV_Pipeline/ (a few minutes):
%     >> run scripts/rebuild_xspec_latlon_fix_2026_07_28

startup_puv

outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
bkRoot  = fullfile(outRoot, '_pre_latlon_xspec_backup_2026-07-28');

DEPS = {'RUBY22','TOR24S','TOR24W','TOR25S'};

fprintf('\n=== L4_xspec rebuild after coordinate fix: %d deployments ===\n', numel(DEPS));
nOk = 0; nFail = 0;

for r = 1:numel(DEPS)
    dep = DEPS{r};
    xf  = fullfile(outRoot, 'L4_xspec', dep, 'xspec.mat');
    fprintf('\n[%d/%d] %s\n', r, numel(DEPS), dep);
    if ~isfile(xf), fprintf('  no xspec.mat -- skipped\n'); continue, end
    try
        old   = load(xf, 'L4xs'); oldXs = old.L4xs;

        rel = extractAfter(xf, [outRoot filesep]);
        dst = fullfile(bkRoot, rel);
        if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
        if ~isfile(dst), copyfile(xf, dst); end

        l4Files = dir(fullfile(outRoot, 'L4', dep, '*_L4.mat'));
        L4list  = arrayfun(@(s) fullfile(s.folder, s.name), l4Files, ...
                           'UniformOutput', false);

        t0 = tic;
        L4xs = PUV_L4_xspec(L4list, struct());
        save(xf, 'L4xs', '-v7.3');
        fprintf('  rebuilt in %.0f s, %d pairs\n', toc(t0), numel(L4xs.pairs));

        fprintf('  %-26s %9s %9s %8s   %9s %9s\n', 'pair', ...
            'sep_old', 'sep_new', 'change', 'coh2_old', 'coh2_new');
        for p = 1:numel(L4xs.pairs)
            pn = L4xs.pairs(p);
            nm = sprintf('%s-%s', pn.labels{1}, pn.labels{2});
            oi = find(arrayfun(@(q) isequal(sort(q.labels), sort(pn.labels)), ...
                               oldXs.pairs), 1);
            if isempty(oi)
                fprintf('  %-26s %9s %9.0f %8s   %9s %9.4f\n', nm, '-', ...
                    pn.sep_total, '-', '-', pn.mean_coh2_IG);
            else
                po = oldXs.pairs(oi);
                pct = 100*(pn.sep_total - po.sep_total)/max(po.sep_total, eps);
                fprintf('  %-26s %9.0f %9.0f %7.1f%%   %9.4f %9.4f\n', nm, ...
                    po.sep_total, pn.sep_total, pct, ...
                    po.mean_coh2_IG, pn.mean_coh2_IG);
            end
        end
        nOk = nOk + 1;
    catch ME
        fprintf(2,'  FAIL: %s\n', ME.message);
        for s = 1:numel(ME.stack)
            fprintf(2,'    %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
        end
        nFail = nFail + 1;
    end
end

fprintf('\n=== done: %d rebuilt, %d failed ===\n', nOk, nFail);
fprintf('Backups in %s\n', bkRoot);
