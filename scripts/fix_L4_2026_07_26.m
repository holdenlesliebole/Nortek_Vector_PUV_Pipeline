% FIX_L4_2026_07_26  Repair the two L4 catalog defects found 2026-07-26.
%
%   Phase 1 -- rebuild the 3 records whose L2 gained a leading segment in the
%   2026-07-10/11 channel-decoupling rerun. Their L4 is correctly time-stamped
%   but sits one index off the current L2 for EVERY segment, so any consumer
%   that indexes L4 with an L2 index silently reads the wrong hour. Rebuilt
%   from the current L1+L2 so index alignment holds again.
%
%   Phase 2 -- backfill L4.bispectra on every record that lacks it. These are
%   the 23 archive/new-site records ingested after the one-time
%   scripts/refresh_L4_bispectra.m pass. PUV_L4_run_all deliberately skips
%   bispectra ("too slow for the full batch"), so nothing ever computed it for
%   them. Nothing errored -- it was simply never run.
%
%   Both phases use PUV_L4_bispectra with useParallel=true, which is verified
%   bit-identical to the serial path (checked against the bispectra already
%   stored for SIO25C, RUBY22/MOP579_6m and RUBY22/MOP578_10m).
%
%   Old L4 files are copied to outputs/_pre_L4fix_backup_2026-07-26/ before
%   being overwritten. The script is idempotent: re-running skips records that
%   are already correct, so it is safe to resume after an interruption.
%
%   Run from PUV_Pipeline/ (expect ~4 h on a 10-core machine):
%     >> run scripts/fix_L4_2026_07_26

startup_puv

outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
bkRoot  = fullfile(outRoot, '_pre_L4fix_backup_2026-07-26');
bispOpts = struct('useParallel', true);

% Records whose L2 grid shifted -- verified by time, depth and fCut.
shifted = {'SIO25B','SIO_6m'; 'TOR24S','MOP586_7m'; 'TOR24W','MOP586_10m'};

if isempty(gcp('nocreate')), parpool('Processes'); end
p = gcp('nocreate');
fprintf('\n=== L4 repair 2026-07-26 (pool: %d workers) ===\n', p.NumWorkers);
tAll = tic;

%% ---------------- Phase 1: rebuild the shifted records ----------------
fprintf('\n--- Phase 1: rebuild %d misaligned records ---\n', size(shifted,1));
n1ok = 0; n1skip = 0; n1fail = 0;

for r = 1:size(shifted,1)
    dep = shifted{r,1}; lab = shifted{r,2};
    l1Path = fullfile(outRoot, 'L1', dep, [lab '_processed.mat']);
    l2Path = fullfile(outRoot, 'L2', dep, [lab '_L2.mat']);
    l4Path = fullfile(outRoot, 'L4', dep, [lab '_L4.mat']);
    fprintf('\n  [%d/%d] %s/%s\n', r, size(shifted,1), dep, lab);

    if ~isfile(l1Path) || ~isfile(l2Path)
        fprintf('    missing L1 or L2 -- skipped\n'); n1fail = n1fail + 1; continue
    end

    try
        l2 = load(l2Path, 'L2'); L2 = l2.L2;

        if isfile(l4Path)
            old = load(l4Path, 'L4');
            [~, info] = l4_l2_index_map(L2, old.L4);
            if info.identity && isfield(old.L4, 'bispectra')
                fprintf('    already aligned and complete -- skipped\n');
                n1skip = n1skip + 1; continue
            end
            fprintf('    current: nL4=%d vs nL2=%d, maxOffset=%d\n', ...
                info.nL4, info.nL2, info.maxOffset);
            backup(l4Path, outRoot, bkRoot);
        end

        l1 = load(l1Path, 'PUV'); PUV = l1.PUV;
        t0 = tic;

        L4 = struct();
        fprintf('    eta...\n');             L4.eta = PUV_L4_eta(PUV, L2);
        fprintf('    reflection...\n');      L4.ref = PUV_L4_reflection(PUV, L2, L4.eta);
        fprintf('    bispectra (%d valid)...\n', sum(L2.segValid));
        L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2, bispOpts);
        fprintf('    moments...\n');         L4.moments = PUV_L4_moments(L2);
        fprintf('    velocity pdf...\n');    L4.pdf = PUV_L4_velocity_pdf(PUV, L2);
        fprintf('    boundwave...\n');       L4.boundwave = PUV_L4_boundwave(L4.eta, L2, PUV);
        fprintf('    reflection_free...\n');
        L4.reflection_free = PUV_L4_reflection_free(PUV, L2, L4.eta, L4.boundwave);

        L4.label          = PUV.label;
        L4.deploymentName = PUV.deploymentName;
        L4.LATLON         = PUV.LATLON;
        L4.doffp          = PUV.doffp;
        L4.shorenormal    = L2.shorenormal;
        if isfield(L2, 'mopStation'), L4.mopStation = L2.mopStation; end
        L4.builtAt        = datetime('now');

        save(l4Path, 'L4', '-v7.3');

        [~, chk] = l4_l2_index_map(L2, L4);
        fprintf('    DONE %.1f min | aligned=%d nL4=%d nL2=%d | skew=%.3f bic=%.3f R2free=%.3f\n', ...
            toc(t0)/60, chk.identity, chk.nL4, chk.nL2, ...
            median(L4.bispectra.skewness,'omitnan'), ...
            median(L4.bispectra.bic_swell_self,'omitnan'), ...
            median(L4.reflection_free.R2_IG,'omitnan'));
        n1ok = n1ok + 1;
    catch ME
        fprintf('    FAIL: %s\n', ME.message);
        for s = 1:numel(ME.stack)
            fprintf('      %s (line %d)\n', ME.stack(s).name, ME.stack(s).line);
        end
        n1fail = n1fail + 1;
    end
end

%% ---------------- Phase 2: backfill missing bispectra ----------------
fprintf('\n--- Phase 2: backfill L4.bispectra ---\n');
l4Files = dir(fullfile(outRoot, 'L4', '*', '*_L4.mat'));
n2ok = 0; n2skip = 0; n2fail = 0;

for k = 1:numel(l4Files)
    l4Path = fullfile(l4Files(k).folder, l4Files(k).name);
    [~, dep] = fileparts(l4Files(k).folder);
    lab    = erase(l4Files(k).name, '_L4.mat');
    l2Path = fullfile(outRoot, 'L2', dep, [lab '_L2.mat']);
    if ~isfile(l2Path), continue, end

    try
        ld = load(l4Path, 'L4'); L4 = ld.L4;
        if isfield(L4, 'bispectra')
            n2skip = n2skip + 1; continue
        end
        l2 = load(l2Path, 'L2'); L2 = l2.L2;

        % Guard: bispectra is computed from the STORED L4.eta but gated on the
        % CURRENT L2.segValid. If the two grids disagree those are different
        % hours, so refuse rather than silently mix them.
        [~, info] = l4_l2_index_map(L2, L4);
        if ~info.identity
            fprintf('  %s/%s -- SKIPPED, L4 grid does not match L2 (nL4=%d nL2=%d maxOffset=%d)\n', ...
                dep, lab, info.nL4, info.nL2, info.maxOffset);
            n2fail = n2fail + 1; continue
        end

        fprintf('  %s/%s (%d valid) ...', dep, lab, sum(L2.segValid));
        t0 = tic;
        L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2, bispOpts);
        backup(l4Path, outRoot, bkRoot);
        save(l4Path, 'L4', '-v7.3');
        fprintf(' %.1f min | nValid=%d skew=%.3f bic=%.3f b95=%.3f\n', ...
            toc(t0)/60, L4.bispectra.nValid, ...
            median(L4.bispectra.skewness,'omitnan'), ...
            median(L4.bispectra.bic_swell_self,'omitnan'), ...
            median(L4.bispectra.b95,'omitnan'));
        n2ok = n2ok + 1;
    catch ME
        fprintf('  %s/%s -- FAIL: %s\n', dep, lab, ME.message);
        n2fail = n2fail + 1;
    end
end

fprintf('\n=== Done in %.2f h ===\n', toc(tAll)/3600);
fprintf('  Phase 1 (rebuild):  %d rebuilt, %d already ok, %d failed\n', n1ok, n1skip, n1fail);
fprintf('  Phase 2 (bispectra): %d backfilled, %d already had it, %d failed\n', n2ok, n2skip, n2fail);
fprintf('\nNext: run validation/audit_L4_coverage to confirm, then push with scripts/copy_to_server.m\n');

%% ---------------- local functions ----------------
function backup(src, outRoot, bkRoot)
% Copy an L4 file into the backup tree, preserving its outputs/-relative path.
rel = extractAfter(src, [outRoot filesep]);
dst = fullfile(bkRoot, rel);
if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
if isfile(dst)
    fprintf('    backup already exists, kept\n');
else
    copyfile(src, dst);
    fprintf('    backed up -> %s\n', dst);
end
end
