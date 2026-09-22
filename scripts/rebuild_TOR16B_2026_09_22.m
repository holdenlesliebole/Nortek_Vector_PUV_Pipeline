% REBUILD_TOR16B_2026_09_22  Rebuild TOR16B/MOP591_9m L1-L4 from a fresh server copy.
%
%   The 2026-09-22 storage audit found that raw_cache/TOR16B/Torrey1049_2017/ held 16
%   hourly .VEC files (of 856) plus one .dat as 0-byte files, written 2026-07-24, while the
%   server copies under recopied/Torrey1049_2017/ are intact (~274 KB each). L1 was built
%   2026-07-28 from that cache, so those hours are missing from the record.
%
%   This script re-caches TOR16B from the server into a scratch root (not raw_cache/, which
%   is being removed by the audit), asserts the fresh cache has no empty files, backs up the
%   current L1-L4 to outputs/_pre_TOR16Brebuild_backup_2026-09-22/ (EXPIRES: delete once the
%   rebuild is verified and pushed; see docs/todo.md), then rebuilds L1 -> L2 -> L3 -> L4 with
%   the same call sequence as scripts/rerun_catalina_fix_2026_07_27.m and prints the
%   before/after segment counts.
%
%   Run from PUV_Pipeline/:
%     matlab -batch "startup_puv; run scripts/rebuild_TOR16B_2026_09_22"

startup_puv
dep = 'TOR16B'; lab = 'MOP591_9m';
scratchRoot = '/private/tmp/claude-501/-Users-holden-Documents-Scripps-Research/e94350d6-f010-4efc-822a-522396c9d1e2/scratchpad/raw_cache';
outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
bkRoot  = fullfile(outRoot, '_pre_TOR16Brebuild_backup_2026-09-22');

reg = deployment_registry(); fn = reg(dep); cfg = fn();
ii = find(strcmp({cfg.instruments.label}, lab), 1); instr = cfg.instruments(ii);

% --- fresh cache from the server ---
cfg = copy_raw_to_local(cfg, scratchRoot);
cacheDir = fullfile(cfg.localDataRoot, instr.rawSubfolder);
dd = dir(cacheDir); dd = dd(~[dd.isdir]);
srvDir = fullfile(cfg.rawDataRoot, instr.rawSubfolder);
nEmpty = 0; nBad = 0;
for q = 1:numel(dd)
    if dd(q).bytes > 0, continue, end
    nEmpty = nEmpty + 1;
    ss = dir(fullfile(srvDir, dd(q).name));
    if ~isempty(ss) && ss.bytes > 0
        nBad = nBad + 1; fprintf('  local empty but server has %d bytes: %s\n', ss.bytes, dd(q).name);
    else
        fprintf('  empty on the server too (archive as delivered): %s\n', dd(q).name);
    end
end
fprintf('fresh cache: %d files, %d empty, %d truncated relative to server\n', numel(dd), nEmpty, nBad);
assert(nBad == 0, '%d files are empty locally but non-empty on the server', nBad);

% --- back up current outputs ---
l1Path = fullfile(outRoot,'L1',dep,[lab '_processed.mat']);
l2Path = fullfile(outRoot,'L2',dep,[lab '_L2.mat']);
l3Path = fullfile(outRoot,'L3',dep,[lab '_L3.mat']);
l4Path = fullfile(outRoot,'L4',dep,[lab '_L4.mat']);
for f = {l1Path, l2Path, l3Path, l4Path}
    if ~isfile(f{1}), continue, end
    rel = extractAfter(f{1}, [outRoot filesep]); dst = fullfile(bkRoot, rel);
    if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
    if ~isfile(dst), copyfile(f{1}, dst); end
end
S = load(l2Path,'L2'); oldSeg = numel(S.L2.time); oldValid = sum(S.L2.segValid);
S1 = load(l1Path,'PUV'); oldN = numel(S1.PUV.time); clear S S1

if isempty(gcp('nocreate')), parpool('Processes'); end
tAll = tic;

t0 = tic; PUV = PUV_raw_process(instr, cfg); save(l1Path,'PUV','-v7.3');
fprintf('  L1 (%.1f min): samples %d -> %d\n', toc(t0)/60, oldN, numel(PUV.time));

t0 = tic; L2 = PUV_L2_spectral(PUV, instr, struct()); save(l2Path,'L2','-v7.3');
fprintf('  L2 (%.1f min): segments %d -> %d, valid %d -> %d\n', toc(t0)/60, oldSeg, numel(L2.time), oldValid, sum(L2.segValid));

t0 = tic;
L3 = PUV_L3_bands(L2); L3 = PUV_L3_storms(L3, L2);
L3 = PUV_L3_transport(L3, L2); L3 = PUV_L3_currents(L3, L2);
save(l3Path,'L3','-v7.3'); fprintf('  L3 (%.0f s)\n', toc(t0));

t0 = tic; L4 = struct();
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
save(l4Path,'L4','-v7.3'); fprintf('  L4 (%.1f min)\n', toc(t0)/60);

[~, ai] = l4_l2_index_map(L2, L4);
qc = ztest_record_flag(L2.ztest_SS, L2.segValid);
fprintf('  medHs=%.4f medDepth=%.3f aligned=%d Z=%s\n', ...
    median(L2.Hs(L2.segValid),'omitnan'), median(L2.depth(L2.segValid),'omitnan'), ai.identity, qc.status);
fprintf('=== TOR16B rebuild done in %.2f h ===\n', toc(tAll)/3600);
