% REGEN_STALE_XSPEC_2026_07_26  Rebuild L4_xspec where its L4 inputs changed.
%
%   `L4_xspec` is computed from `L4.eta.eta_ig` across instrument pairs, so it
%   goes stale whenever a constituent record's `eta` is rebuilt. The 2026-07-26
%   repair rebuilt TOR24S/MOP586_7m and TOR24W/MOP586_10m from the current L2
%   (each gained a recovered leading segment), so those two deployments' xspec
%   no longer reflects their inputs.
%
%   The other 7 xspec files also predate their L4 files, but only because the
%   2026-05-20 asymmetry sign fix re-saved every L4 to update `moments`. That
%   pass did not touch `eta`, so their xspec is still consistent with its input
%   and is deliberately left alone.
%
%   Note the old xspec was not *wrong*: PUV_L4_xspec matches segments by
%   best time-window overlap, not by index, so the misalignment never corrupted
%   the pairing. What it missed is the recovered hour and the small QC
%   differences in the rebuilt eta.
%
%   Staleness is detected by comparing mtimes rather than hardcoded, and the
%   before/after pair statistics are printed so the size of the change is
%   visible.
%
%   Run from PUV_Pipeline/ (about a minute):
%     >> run scripts/regen_stale_xspec_2026_07_26

startup_puv

outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
bkRoot  = fullfile(outRoot, '_pre_xspec_regen_backup_2026-07-26');

xspecDirs = dir(fullfile(outRoot, 'L4_xspec', '*'));
xspecDirs = xspecDirs([xspecDirs.isdir] & ~startsWith({xspecDirs.name}, '.'));

todo = {};
for d = 1:numel(xspecDirs)
    dep  = xspecDirs(d).name;
    xf   = fullfile(outRoot, 'L4_xspec', dep, 'xspec.mat');
    if ~isfile(xf), continue, end
    xInfo = dir(xf);
    l4    = dir(fullfile(outRoot, 'L4', dep, '*_L4.mat'));
    if isempty(l4), continue, end
    % Only an L4 rebuilt AFTER the 2026-05-20 moments re-save can have changed
    % eta; anything at or before that date was a metadata-only rewrite.
    etaCutoff = datenum(2026, 6, 1); %#ok<DATNM>
    changed = l4([l4.datenum] > xInfo.datenum & [l4.datenum] > etaCutoff);
    if ~isempty(changed)
        todo(end+1,:) = {dep, {changed.name}}; %#ok<SAGROW>
    end
end

fprintf('\n=== L4_xspec regen: %d deployment(s) with rebuilt eta ===\n', size(todo,1));
if isempty(todo), fprintf('Nothing to do.\n'); return, end

for r = 1:size(todo,1)
    dep = todo{r,1};
    fprintf('\n[%d/%d] %s  (rebuilt inputs: %s)\n', r, size(todo,1), dep, ...
        strjoin(erase(todo{r,2}, '_L4.mat'), ', '));
    xf = fullfile(outRoot, 'L4_xspec', dep, 'xspec.mat');
    try
        old = load(xf, 'L4xs'); oldXs = old.L4xs;

        rel = extractAfter(xf, [outRoot filesep]);
        dst = fullfile(bkRoot, rel);
        if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
        if ~isfile(dst), copyfile(xf, dst); end

        l4Files = dir(fullfile(outRoot, 'L4', dep, '*_L4.mat'));
        L4list  = arrayfun(@(s) fullfile(s.folder, s.name), l4Files, 'UniformOutput', false);

        t0 = tic;
        L4xs = PUV_L4_xspec(L4list, struct());
        save(xf, 'L4xs', '-v7.3');
        fprintf('    rebuilt in %.0f s, %d pairs\n', toc(t0), numel(L4xs.pairs));

        fprintf('    %-28s %10s %10s   %10s %10s\n', 'pair', 'nMatch_old', 'nMatch_new', 'coh2_old', 'coh2_new');
        for p = 1:numel(L4xs.pairs)
            pn = L4xs.pairs(p);
            nm = sprintf('%s-%s', pn.labels{1}, pn.labels{2});
            oi = find(arrayfun(@(q) isequal(sort(q.labels), sort(pn.labels)), oldXs.pairs), 1);
            if isempty(oi)
                fprintf('    %-28s %10s %10d   %10s %10.4f\n', nm, 'NEW', pn.nMatched, '-', pn.mean_coh2_IG);
            else
                po = oldXs.pairs(oi);
                fprintf('    %-28s %10d %10d   %10.4f %10.4f\n', nm, ...
                    po.nMatched, pn.nMatched, po.mean_coh2_IG, pn.mean_coh2_IG);
            end
        end
    catch ME
        fprintf('    FAIL: %s\n', ME.message);
    end
end

fprintf('\nDone.\n');
