% copy_to_server.m
% Author: Holden Leslie-Bole, 2026
% Copy L1-L4 and L4_xspec processed .mat files, with their provenance sidecars,
% to the group server, organized deployment-first under Processed_HLB.
% Generates README.md, manifest.csv and CHANGELOG.md. Idempotent.
%
% Optional workspace variables:
%   dryRun        true: copy nothing and write nothing; report what WOULD be
%                 pushed and every refusal (default false)
%   sidecarRoot   (dry runs only) read provenance sidecars from this parallel
%                 tree instead of beside each .mat
%   srcRoot       outputs tree to publish (default: this repo's outputs/)
%   destRoot      (dry runs only) a stand-in for the server tree, for testing
%   forceReasons  containers.Map, '<level>/<deployment>/<file>' -> reason. A
%                 refused file listed here is pushed anyway and the reason is
%                 written into CHANGELOG.md verbatim.
%
% PROVENANCE GATE (2026-10-09). Every file is checked by shared/check_prov
% against its sidecar, the current code, the current config and its current
% parent files, and is REFUSED (not copied) when:
%   HARD  no provenance; bytes differ from the sidecar's file_sha256
%         ("modified outside the pipeline": outputs/ is written only by this
%         pipeline, see docs/catalog_changes/README.md); config or derived
%         value differs from what was applied; built from a superseded parent
%   SOFT  level code changed since the build, a recorded fallback, or
%         uncommitted code, unless a PENDING change entry acknowledges it
%   CHANGE  its sha256 differs from the server manifest's and no pending
%         change entry (docs/catalog_changes/*.md) names it
% A refused file that already has a copy on the server is left there and
% inventoried from the previous manifest, so manifest.csv keeps describing the
% server. Catalog version 'YYYY-MM-DD.N'; manifest.csv gains size_bytes,
% sha256, build_id, git_hash, backfilled, catalog_version_first; the previous
% manifest is kept as manifests/manifest_<version>.csv.

repo_root = fileparts(fileparts(mfilename('fullpath')));
src_root  = fullfile(repo_root, 'outputs');
if exist('srcRoot', 'var') && ~isempty(srcRoot), src_root = srcRoot; end   % e.g. run from a worktree
% resolve symlinks (outputs/ is a symlink to ~/LocalData): dir() reports the
% resolved folders, and relative paths must be taken against the same root
src_root = char(java.io.File(src_root).getCanonicalPath());
dest_root = '/Volumes/group/PUV_data/Vector/Processed_HLB';
if ~exist('dryRun', 'var'), dryRun = false; end
if exist('destRoot', 'var') && ~isempty(destRoot)       % testing only: a stand-in server tree
    if ~dryRun, error('copy_to_server: destRoot override is allowed in dry runs only'); end
    dest_root = destRoot;
end
if ~exist('forceReasons', 'var'), forceReasons = containers.Map(); end
provOpts = struct();
if exist('sidecarRoot', 'var') && ~isempty(sidecarRoot)
    if ~dryRun, error('copy_to_server: sidecarRoot is allowed in dry runs only'); end
    provOpts.sidecarRoot = sidecarRoot; provOpts.outRoot = src_root;
end
if dryRun, fprintf('\n*** DRY RUN: nothing will be copied or written ***\n\n'); end

if ~isfolder(fileparts(dest_root))
    error('Server not mounted: %s', fileparts(dest_root));
end
if ~exist(dest_root, 'dir') && ~dryRun; mkdir(dest_root); end

[~, git_hash] = system(sprintf('cd %s && git rev-parse --short HEAD', repo_root));
git_hash = strtrim(git_hash);

%% Collect L1 (raw QC'd) + L2, L3, L4 instrument files + L4_xspec deployment files
L1_files       = dir(fullfile(src_root, 'L1',       '*', '*_processed.mat'));
L2_files       = dir(fullfile(src_root, 'L2',       '*', '*_L2.mat'));
L3_files       = dir(fullfile(src_root, 'L3',       '*', '*_L3.mat'));
L4_files       = dir(fullfile(src_root, 'L4',       '*', '*_L4.mat'));
L4_xspec_files = dir(fullfile(src_root, 'L4_xspec', '*', 'xspec.mat'));
fprintf('Found %d L1, %d L2, %d L3, %d L4, %d L4_xspec files\n', ...
    numel(L1_files), numel(L2_files), numel(L3_files), numel(L4_files), numel(L4_xspec_files));

%% Build manifest while copying
rows = {};
all_files = [arrayfun(@(s) struct('level','L1',       'd', s), L1_files); ...
             arrayfun(@(s) struct('level','L2',       'd', s), L2_files); ...
             arrayfun(@(s) struct('level','L3',       'd', s), L3_files); ...
             arrayfun(@(s) struct('level','L4',       'd', s), L4_files); ...
             arrayfun(@(s) struct('level','L4_xspec', 'd', s), L4_xspec_files)];

%% Guard: never push a deployment that is not in the registry.
% outputs/ can hold exploratory runs for deployments deliberately held OUT of
% the catalog -- TOR20A, for instance, whose timing could not be validated
% (see docs/recopied_data_backlog.md). Those directories look exactly like
% canonical ones to a dir() glob, so without this filter they would land on
% the server and in manifest.csv indistinguishable from validated records.
registeredNames = containers.Map('KeyType', 'char', 'ValueType', 'logical');
cfgByName = struct();
reg = deployment_registry();
regKeys = keys(reg);
for k = 1:numel(regKeys)
    try
        fn = reg(regKeys{k}); cfg = fn();
        registeredNames(cfg.name) = true;
        cfgByName.(matlab.lang.makeValidName(cfg.name)) = cfg;
    catch
        % a config that fails to load cannot vouch for its outputs either
    end
end

isReg   = false(numel(all_files), 1);
depName = cell(numel(all_files), 1);
for k = 1:numel(all_files)
    [~, depName{k}] = fileparts(all_files(k).d.folder);
    isReg(k) = isKey(registeredNames, depName{k});
end
if any(~isReg)
    skipped = unique(depName(~isReg));
    fprintf('\n*** SKIPPING %d file(s) from %d UNREGISTERED deployment(s): %s\n', ...
        sum(~isReg), numel(skipped), strjoin(skipped', ', '));
    fprintf('    Not in deployment_registry -- held out of the catalog on purpose.\n');
    fprintf('    Register the deployment if it should actually be published.\n\n');
    all_files = all_files(isReg);
end

%% Guard: never push an INCOMPLETE L4 file.
% The canonical copy is what other people and other repos read, so a partially
% built L4 must not reach it. This fires on 2026-07-27, when a concurrent job
% rewrote three TOR16* records without pdf / LATLON / doffp / shorenormal --
% and LATLON and shorenormal are exactly what PUV_L4_xspec reads, so those
% files would break any multi-instrument run downstream.
%
% Uses h5info to list the group members without loading the (multi-GB) data.
L4WANT = {'eta','ref','bispectra','boundwave','moments','reflection_free','pdf', ...
          'label','deploymentName','LATLON','doffp','shorenormal'};
keepFile = true(numel(all_files), 1);
incomplete = {};
for k = 1:numel(all_files)
    if ~strcmp(all_files(k).level, 'L4'), continue, end
    p = fullfile(all_files(k).d.folder, all_files(k).d.name);
    try
        info = h5info(p, '/L4');
        present = [{info.Groups.Name}, {info.Datasets.Name}];
        present = erase(present, '/L4/');
        miss = setdiff(L4WANT, present);
    catch
        % Not an HDF5 (-v7.3) file, or unreadable structure: fall back to a load.
        try
            S = load(p, 'L4');
            miss = setdiff(L4WANT, fieldnames(S.L4));
        catch ME
            miss = {sprintf('<unreadable: %s>', ME.message)};
        end
    end
    if ~isempty(miss)
        keepFile(k) = false;
        incomplete{end+1} = sprintf('%s  (missing: %s)', ...
            erase(p, [src_root filesep]), strjoin(miss, ', ')); %#ok<SAGROW>
    end
end
skipIncomplete = ~keepFile;
if any(skipIncomplete)
    fprintf(2, '\n*** SKIPPING %d INCOMPLETE L4 file(s) -- not pushed:\n', sum(skipIncomplete));
    for i = 1:numel(incomplete), fprintf(2, '    %s\n', incomplete{i}); end
    fprintf(2, ['    Rebuild them (scripts/repair_L4_metadata_*.m or PUV_L4_driver)\n' ...
                '    before pushing. Check with validation/audit_L4_coverage.\n' ...
                '    NOTE: any copy already on the server is LEFT IN PLACE and still\n' ...
                '    inventoried in manifest.csv from the server-side file, so the\n' ...
                '    manifest keeps describing what is actually there.\n\n']);
    % Deliberately NOT removed from all_files: dropping them here would also
    % drop them from the manifest, leaving files present on the server but
    % absent from its own inventory (which is what happened on 2026-07-27).
end

%% Previous manifest, pending change entries, catalog version
prevPath = fullfile(dest_root, 'manifest.csv');
prevRows = containers.Map();
baseline = true;
if isfile(prevPath)
    prevT = readtable(prevPath, 'TextType', 'string', 'Delimiter', ',');
    baseline = ~ismember('sha256', prevT.Properties.VariableNames);
    if ~baseline
        for r = 1:height(prevT)
            prevRows(char(prevT.deployment(r) + "|" + prevT.level(r) + "|" + prevT.instrument(r))) = prevT(r, :);
        end
    end
end
CE = read_change_entries(fullfile(repo_root, 'docs', 'catalog_changes'));
catVersion = next_catalog_version(dest_root);
fprintf('Catalog version %s | %d pending change entr%s | %s\n', catVersion, numel(CE), ...
    ternary(numel(CE) == 1, 'y', 'ies'), ternary(baseline, ...
    'BASELINE: server manifest has no sha256 yet, so no change-entry requirement this push', ...
    'changed files must be named by a pending change entry'));

%% Provenance gate (shared/check_prov), per file, before anything is copied
gate = repmat(struct('rel', '', 'sha', '', 'prov', [], 'refusals', {{}}, 'notes', {{}}, ...
                     'forced', '', 'entries', {{}}, 'changed', false), numel(all_files), 1);
fprintf('Checking provenance of %d files (sha256 is computed locally)...\n', numel(all_files));
for k = 1:numel(all_files)
    level = all_files(k).level; d = all_files(k).d;
    [~, dep] = fileparts(d.folder);
    rel = [level '/' dep '/' d.name];
    gate(k).rel = rel;
    if skipIncomplete(k), continue, end
    p = fullfile(d.folder, d.name);
    gate(k).sha = file_sha256(p);
    [ackCode, ackFb, ents] = entries_for(CE, rel);
    gate(k).entries = ents;
    req = struct('matPath', p, 'level', level, 'fileSha', gate(k).sha, 'opts', provOpts, ...
                 'repoRoot', repo_root, 'ackCodeLevels', {ackCode}, 'ackFallback', ackFb, ...
                 'instr', [], 'cfg', [], 'parents', struct('level', {}, 'path', {}));
    lab = regexprep(d.name, '(_processed|_L[1-4])\.mat$', '');
    cfgKey = matlab.lang.makeValidName(dep);
    if isfield(cfgByName, cfgKey)
        cfg = cfgByName.(cfgKey); req.cfg = cfg;
        ii = find(strcmp({cfg.instruments.label}, lab), 1);
        if ~isempty(ii), req.instr = cfg.instruments(ii); end
    end
    switch level
        case 'L2',         req.parents = struct('level', 'L1', 'path', fullfile(src_root, 'L1', dep, [lab '_processed.mat']));
        case {'L3','L4'},  req.parents = struct('level', 'L2', 'path', fullfile(src_root, 'L2', dep, [lab '_L2.mat']));
        case 'L4_xspec'
            m = dir(fullfile(src_root, 'L4', dep, '*_L4.mat'));
            req.parents = struct('level', repmat({'L4'}, 1, numel(m)), ...
                                 'path', arrayfun(@(z) fullfile(z.folder, z.name), m, 'UniformOutput', false)');
    end
    res = check_prov(req);
    gate(k).prov = res.prov; gate(k).refusals = res.refusals; gate(k).notes = res.notes;
    instrName = ternary(strcmp(level, 'L4_xspec'), 'xspec', lab);
    key = [dep '|' level '|' instrName];
    gate(k).changed = ~baseline && (~isKey(prevRows, key) || ~strcmp(prevRows(key).sha256, gate(k).sha));
    if gate(k).changed && isempty(ents)
        gate(k).refusals{end+1} = 'CHANGE: sha256 differs from the server manifest and no pending change entry names this file';
    end
    if ~isempty(gate(k).refusals) && isKey(forceReasons, rel)
        gate(k).forced = forceReasons(rel);
    end
end
refused = arrayfun(@(g) ~isempty(g.refusals) && isempty(g.forced), gate);
nForced = sum(arrayfun(@(g) ~isempty(g.forced), gate));
fprintf('\nProvenance gate: %d of %d files refused, %d forced.\n', sum(refused), sum(~skipIncomplete), nForced);
reasonsAll = {};
for k = find(refused)'
    fprintf(2, '  REFUSED %s\n', gate(k).rel);
    for r = 1:numel(gate(k).refusals)
        fprintf(2, '      %s\n', gate(k).refusals{r});
        reasonsAll{end+1} = regexprep(gate(k).refusals{r}, ':.*$', ''); %#ok<SAGROW>
        reasonsAll{end} = [reasonsAll{end} ': ' regexprep(extractAfter(gate(k).refusals{r}, ': '), '\<[0-9a-f]{8,}\>|(?<![A-Za-z_])[-+]?[0-9][0-9.]*(e[-+]?[0-9]+)?', '#')];
    end
end
if any(refused)
    [u, ~, j] = unique(reasonsAll); c = accumarray(j(:), 1);
    fprintf('\nRefusal reasons (count):\n');
    for r = 1:numel(u), fprintf('  %4d  %s\n', c(r), u{r}); end
end

% Per-level destination subfolder name
destSubFor = containers.Map( ...
    {'L1','L2','L3','L4','L4_xspec'}, ...
    {'Level1_QC','Level2_QC','Level3_QC','Level4_QC','Level4_xspec'});

for k = 1:numel(all_files)
    level = all_files(k).level;
    d     = all_files(k).d;
    deployment = regexp(d.folder, [filesep '([^' filesep ']+)$'], 'tokens', 'once');
    deployment = deployment{1};

    src_path = fullfile(d.folder, d.name);
    dest_dir = fullfile(dest_root, deployment, destSubFor(level));
    if ~exist(dest_dir, 'dir') && ~dryRun; mkdir(dest_dir); end
    dest_path = fullfile(dest_dir, d.name);
    g = gate(k);
    instrKey = ternary(strcmp(level, 'L4_xspec'), 'xspec', regexprep(d.name, '(_processed|_L[1-4])\.mat$', ''));
    prevKey = [deployment '|' level '|' instrKey];

    % A file refused by the provenance gate is not pushed. A copy already on
    % the server stays and is inventoried from the previous manifest row.
    if refused(k)
        if isKey(prevRows, prevKey)
            pr = prevRows(prevKey);
            rows(end+1, :) = {deployment, level, instrKey, pr.depth_m, string(pr.time_start), string(pr.time_end), ...
                pr.n_segments, pr.n_valid, pr.size_MB, pr.size_bytes, string(pr.sha256), string(pr.build_id), ...
                string(pr.git_hash), pr.backfilled, string(pr.catalog_version_first)}; %#ok<SAGROW>
            fprintf('[%3d/%3d] %s REFUSED; server copy left in place and inventoried\n', k, numel(all_files), g.rel);
        elseif isfile(dest_path)
            % baseline push (old manifest has no provenance columns): still inventory the server copy
            dd = dir(dest_path);
            rows(end+1, :) = {deployment, level, instrKey, NaN, "", "", NaN, NaN, round(dd.bytes/1e6, 1), ...
                dd.bytes, "", "", "", NaN, ""}; %#ok<SAGROW>
            fprintf('[%3d/%3d] %s REFUSED; server copy left in place and inventoried (size only)\n', k, numel(all_files), g.rel);
        else
            fprintf('[%3d/%3d] %s REFUSED; nothing on the server\n', k, numel(all_files), g.rel);
        end
        continue
    end

    % An incomplete local file is never pushed. If a (good) copy is already on
    % the server, inventory THAT one so the manifest still describes the server;
    % if there is nothing there, there is nothing to inventory.
    if skipIncomplete(k)
        if isfile(dest_path)
            dd = dir(dest_path);
            src_path = dest_path;   % read metadata from the server-side copy
            d.bytes  = dd.bytes;
        else
            continue
        end
    end

    % Read metadata from local copy (fast)
    if strcmp(level, 'L4_xspec')
        instr = 'xspec';  % deployment-level product, not per instrument
    elseif strcmp(level, 'L1')
        instr = regexprep(d.name, '_processed\.mat$', '');
    else
        instr = regexprep(d.name, ['_' level '\.mat$'], '');
    end
    depth_m = NaN;
    tok = regexp(instr, '_([0-9]+)m', 'tokens', 'once');
    if ~isempty(tok); depth_m = str2double(tok{1}); end

    t_start = NaT; t_end = NaT; n_seg = NaN; n_valid = NaN;
    try
        m = matfile(src_path);
        S = whos(m);
        topvar = S(1).name;
        if any(strcmp({S.name}, level)); topvar = level; end
        Sd = m.(topvar);
        if strcmp(level, 'L1') && isfield(Sd, 'time') && ~isempty(Sd.time)
            % L1 is a sample-level timeseries — record span only, not n_seg
            t_start = Sd.time(1);
            t_end   = Sd.time(end);
            % n_seg / n_valid intentionally left as NaN for L1
        elseif isfield(Sd, 'time') && ~isempty(Sd.time)
            t_start = Sd.time(find(~isnat(Sd.time), 1, 'first'));
            t_end   = Sd.time(find(~isnat(Sd.time), 1, 'last'));
            n_seg   = numel(Sd.time);
        elseif isfield(Sd, 'eta') && isfield(Sd.eta, 'time')   % L4
            t_start = Sd.eta.time(find(~isnat(Sd.eta.time), 1, 'first'));
            t_end   = Sd.eta.time(find(~isnat(Sd.eta.time), 1, 'last'));
            n_seg   = numel(Sd.eta.time);
            if isfield(Sd.eta, 'segValid'), n_valid = sum(Sd.eta.segValid); end
        elseif isfield(Sd, 'pairs') && ~isempty(Sd.pairs)      % L4_xspec
            allT = vertcat(Sd.pairs.time);
            if ~isempty(allT)
                t_start = min(allT);
                t_end   = max(allT);
            end
            n_seg = sum(arrayfun(@(p) p.nMatched, Sd.pairs));
        end
        if isfield(Sd, 'segValid'); n_valid = sum(Sd.segValid); end
    catch ME
        fprintf('  [warn] could not read metadata from %s: %s\n', d.name, ME.message);
    end

    % Copy (skip if destination already has matching byte size)
    fprintf('[%3d/%3d] %s/%s/%s ... ', k, numel(all_files), deployment, ...
            destSubFor(level), d.name);
    % Skip only if the destination is the same size AND at least as new as
    % the source. Byte-size alone is unreliable: a content change that
    % preserves element count and magnitude (e.g. a sign flip) can produce a
    % byte-identical compressed file, which a size-only check would silently
    % skip and leave stale on the server. The mtime guard forces a re-copy
    % whenever the local file has been re-saved more recently than the
    % server copy. (Fixed 2026-05-20 after the asymmetry sign-flip re-save.)
    skipCopy = false;
    if skipIncomplete(k)
        % src_path was repointed at dest_path above; copying would be a no-op
        % onto itself. Inventory only.
        skipCopy = true;
    elseif isfile(dest_path)
        destInfo = dir(dest_path);
        if destInfo.bytes == d.bytes && destInfo.datenum >= d.datenum
            skipCopy = true;
        end
    end
    if skipCopy && skipIncomplete(k)
        fprintf('SKIPPED as incomplete; inventoried server copy (%.1f MB)\n', d.bytes/1e6);
    elseif skipCopy
        fprintf('skip (%.1f MB, already synced)\n', d.bytes/1e6);
    elseif dryRun
        fprintf('would copy (%.1f MB)\n', d.bytes/1e6);
    else
        t0 = tic;
        copyfile(src_path, dest_path);
        fprintf('%.1fs (%.1f MB)\n', toc(t0), d.bytes/1e6);
    end
    % the provenance sidecar travels with the file (it is small; always refreshed)
    sc = sidecar_path(src_path, provOpts);
    if ~skipIncomplete(k) && isfile(sc) && ~dryRun
        copyfile(sc, [dest_path '.prov.json']);
    end

    % manifest provenance columns
    shaK = g.sha; bid = ""; gh = ""; bf = 0; first = string(catVersion);
    if skipIncomplete(k) && isKey(prevRows, prevKey)
        pr = prevRows(prevKey); shaK = char(pr.sha256); bid = string(pr.build_id); gh = string(pr.git_hash);
        bf = pr.backfilled; first = string(pr.catalog_version_first);
    elseif ~isempty(g.prov)
        bid = string(g.prov.build_id); gh = string(g.prov.code.git_hash);
        bf = double(isfield(g.prov, 'backfilled') && ~isempty(g.prov.backfilled));
        if isKey(prevRows, prevKey) && strcmp(prevRows(prevKey).sha256, shaK)
            first = string(prevRows(prevKey).catalog_version_first);
        end
    end
    rows(end+1, :) = {deployment, level, instr, depth_m, ...
                      string(t_start), string(t_end), n_seg, n_valid, ...
                      round(d.bytes/1e6, 1), d.bytes, string(shaK), bid, gh, bf, first};   %#ok<SAGROW>
end

%% Manifest
if isempty(rows), error('copy_to_server: no files to inventory under %s', src_root); end
T = cell2table(rows, 'VariableNames', ...
    {'deployment','level','instrument','depth_m', ...
     'time_start','time_end','n_segments','n_valid','size_MB', ...
     'size_bytes','sha256','build_id','git_hash','backfilled','catalog_version_first'});
T = sortrows(T, {'deployment','level','instrument'});

%% CHANGELOG.md section for this version
changelog_section = build_changelog_section(catVersion, git_hash, gate, refused, CE, prevRows, T, baseline, dest_root);
if dryRun
    fprintf('\n----- CHANGELOG section that WOULD be written -----\n%s\n', changelog_section);
    fprintf('DRY RUN complete: %d files would be inventoried; nothing was copied or written.\n', height(T));
    return
end
if ~exist(fullfile(dest_root, 'manifests'), 'dir'), mkdir(fullfile(dest_root, 'manifests')); end
if isfile(prevPath), copyfile(prevPath, fullfile(dest_root, 'manifests', ['manifest_before_' catVersion '.csv'])); end
writetable(T, fullfile(dest_root, 'manifest.csv'));
writetable(T, fullfile(dest_root, 'manifests', ['manifest_' catVersion '.csv']));
fprintf('\nWrote manifest.csv (%d rows), catalog version %s\n', height(T), catVersion);
clPath = fullfile(dest_root, 'CHANGELOG.md'); old = '';
if isfile(clPath), old = fileread(clPath); old = regexprep(old, '^# PUV catalog changelog\s*', ''); end
fid = fopen(clPath, 'w');
fprintf(fid, '# PUV catalog changelog\n\n%s\n%s', changelog_header(), changelog_section);
fprintf(fid, '%s', old); fclose(fid);
fprintf('Wrote CHANGELOG.md\n');
mark_entries_published(CE, catVersion);

%% README.md
readme = sprintf([ ...
    '# PUV Vector Processed Data — Holden Leslie-Bole\n\n' ...
    'Processed Nortek Vector PUV data from %d deployments along the San Diego coast.\n' ...
    'Generated: %s.\n\n' ...
    '## Source\n\n' ...
    'Pipeline: https://github.com/holdenlesliebole/Nortek_Vector_PUV_Pipeline\n' ...
    'Commit: %s\n\n' ...
    '## Levels\n\n' ...
    '- **Level1_QC** — QC''d 2 Hz timeseries: PUV struct with `time` (UTC),\n' ...
    '  `P` (pressure, dBar), `BuoyCoord.{U,V,W}` (buoy frame, +x WEST, +y NORTH),\n' ...
    '  `InstrCoord` (instrument frame), `T` (temperature), `doffp`, `LATLON`.\n' ...
    '  Burst-merged, clock-drift-corrected, with battery cutoff truncation.\n' ...
    '  Top-of-hour alignment is applied at L2, not here — L1 covers the full\n' ...
    '  sample range.\n' ...
    '- **Level2_QC** — Spectral analysis on 1-hour segments (7200 samples @ 2 Hz):\n' ...
    '  multi-taper PSD (DPSS, NW=4, K=7), surface elevation spectrum S_eta(f),\n' ...
    '  bulk wave parameters (Hs, Tp, mean direction, spread), directional Fourier\n' ...
    '  coefficients (a1, b1, a2, b2), Z-test, radiation stress, segment-mean\n' ...
    '  cross-shore and alongshore velocity (uMean, vMean) for mean-flow analysis.\n' ...
    '  (Switched from 17-min to 1-hour default in May 2026. The legacy 17-min L2\n' ...
    '  archive was DELETED 2026-07-28 -- it carried no L1 of its own and was\n' ...
    '  derived from an L1 since superseded three times, so it was not a clean\n' ...
    '  reference. The mean-flow results it supported are tabulated in the repo at\n' ...
    '  docs/mean_flow_validation_plan.md, and the comparison is re-runnable from\n' ...
    '  the current L1 at both segment lengths.)\n' ...
    '- **Level3_QC** — Forcing-derived quantities: energy partitioning by frequency\n' ...
    '  band, bed velocity / stress, Shields parameter, Rouse number, MOP shoaled\n' ...
    '  reference, currents.\n' ...
    '- **Level4_QC** — IG / bound-wave dynamics: surface elevation timeseries by\n' ...
    '  band (eta_total, eta_swell, eta_ig), Sheremet incident/reflected IG split\n' ...
    '  with R^2(f) and IG flux, bispectrum / bicoherence with skewness and asymmetry,\n' ...
    '  swell self-coupling and swell-IG difference-coupling metrics.\n' ...
    '- **Level4_xspec** — Pairwise IG cross-spectra across co-deployed instruments:\n' ...
    '  Welch cross-spectrum S_ij(f), coherence^2(f), and cross-phase phi(f) per\n' ...
    '  segment, with pair geometry (alongshore/cross-shore separation in the pair''s\n' ...
    '  mean shore-normal frame) and aggregated band statistics. One xspec.mat per\n' ...
    '  deployment.\n\n' ...
    'L1 is included as of May 2026 so the catalog is fully reconstructible\n' ...
    'from this archive alone (raw .dat/.sen files on the lab server are no\n' ...
    'longer the only source of truth for L2+ regeneration).\n\n' ...
    '## Layout\n\n' ...
    '```\n' ...
    'Processed_HLB/\n' ...
    '  README.md\n' ...
    '  manifest.csv      — per-file index (deployment, instrument, depth, time range, sizes,\n' ...
    '                      sha256, build_id, git_hash, backfilled, catalog_version_first)\n' ...
    '  CHANGELOG.md      — what changed in each catalog version, and how to tell old from new\n' ...
    '  manifests/        — every previous manifest.csv\n' ...
    '  <file>.prov.json  — beside every .mat: how it was built (code, applied choices, parents)\n' ...
    '  <deployment>/\n' ...
    '    Level1_QC/      — *_processed.mat (raw QC''d 2 Hz timeseries)\n' ...
    '    Level2_QC/      — *_L2.mat\n' ...
    '    Level3_QC/      — *_L3.mat\n' ...
    '    Level4_QC/      — *_L4.mat\n' ...
    '    Level4_xspec/   — xspec.mat (one per deployment)\n' ...
    '```\n\n' ...
    '## Conventions\n\n' ...
    '- Coordinate system: x cross-shore (positive onshore), y alongshore (positive north)\n' ...
    '- Vertical: NAVD88 (MSL = 0.774 m, MHW = 1.344 m)\n' ...
    '- Times: UTC, datetime\n' ...
    '- File naming: `<MOP_or_site>_<depth>m_L<N>.mat` (e.g., MOP580_7m_L2.mat)\n\n' ...
    '## RUBY22 vs Ruby2D\n\n' ...
    '- **RUBY22/** is the full processed Ruby2D 2021-2022 cross-shore array at\n' ...
    '  Torrey Pines, ingested via the same pipeline as the rest of the catalog\n' ...
    '  (3 instruments at MOP578 10m, MOP579 6m, MOP582 30m).\n' ...
    '- **Ruby2D/**, if present, contains a single-instrument Level2 reprocess of\n' ...
    '  the legacy archived L1 file, used for the head-to-head validation against\n' ...
    '  the legacy pipeline (`docs/pipeline_comparison_legacy.md` in the source\n' ...
    '  repo). It is not a new deployment.\n\n' ...
    '## CAT21A / CAT21B\n\n' ...
    'Two separate Catalina Island deployments processed through the standard\n' ...
    'pipeline. CAT21A covers Feb-Mar 2021 (CATISL03_*, multi-burst, 117 days);\n' ...
    'CAT21B covers Aug 2021 (CATISL02 single-burst, ~15 days). Catalina is\n' ...
    'outside CDIP MOP coverage, so L2 was processed in buoy coords without\n' ...
    'shore-normal rotation; bulk wave parameters and segment-mean velocity are\n' ...
    'still valid in the buoy frame.\n\n' ...
    '## Contact\n\n' ...
    'Holden Leslie-Bole <hlesliebole@ucsd.edu>, Scripps Institution of Oceanography.\n'], ...
    numel(unique(T.deployment)), datestr(now, 'yyyy-mm-dd'), git_hash);
fid = fopen(fullfile(dest_root, 'README.md'), 'w'); fprintf(fid, '%s', readme); fclose(fid);
fprintf('Wrote README.md\n');

%% Ruby2D-specific README
ruby_dir = fullfile(dest_root, 'Ruby2D');
if exist(ruby_dir, 'dir')
    ruby_readme = sprintf([ ...
        '# Ruby2D — multi-taper reprocess (not a new deployment)\n\n' ...
        'This folder contains a Level2 reprocess of the archived legacy L1 file\n' ...
        '`Torrey_Ruby2D_582_6m_processed.mat` using the multi-taper pipeline\n' ...
        '(commit %s). It exists for the head-to-head validation against the\n' ...
        'legacy archived L2; see `docs/pipeline_comparison_legacy.md` and\n' ...
        '`docs/multitaper_writeup.pdf` in the source repo.\n\n' ...
        'For Ruby2D L1 and the original L2, see `/Volumes/group/Ruby2D/PUV/`.\n'], ...
        git_hash);
    fid = fopen(fullfile(ruby_dir, 'README.md'), 'w'); fprintf(fid, '%s', ruby_readme); fclose(fid);
    fprintf('Wrote Ruby2D/README.md\n');
end

%% Summary
total_bytes = sum(T.size_MB);
fprintf('\nDone. %d files, %.1f MB total, %d deployments.\n', ...
    height(T), total_bytes, numel(unique(T.deployment)));
fprintf('Destination: %s\n', dest_root);


%% ---------------------------------------------------------------- helpers
function s = ternary(c, a, b), if c, s = a; else, s = b; end, end

function CE = read_change_entries(dirPath)
% Pending change entries: docs/catalog_changes/*.md with a fenced block
%   ```catalog-change
%   status: pending
%   files:
%     - L4/TBR23/*
%   code_ack:
%     - L3: why the L3 code change does not invalidate these files
%   fallback_ack: false
%   ```
    CE = struct('path', {}, 'title', {}, 'body', {}, 'files', {}, 'code_ack', {}, 'fallback_ack', {}, 'changes', {});
    F = dir(fullfile(dirPath, '*.md'));
    for k = 1:numel(F)
        if strcmpi(F(k).name, 'README.md'), continue, end
        txt = fileread(fullfile(F(k).folder, F(k).name));
        blk = regexp(txt, '```catalog-change\s*\n(.*?)```', 'tokens', 'once');
        if isempty(blk), continue, end
        b = blk{1};
        st = regexp(b, 'status:\s*(\S+)', 'tokens', 'once');
        if isempty(st) || ~strcmpi(st{1}, 'pending'), continue, end
        e.path = fullfile(F(k).folder, F(k).name);
        t = regexp(txt, '^#\s*(.+?)\s*$', 'tokens', 'once', 'lineanchors'); e.title = ternary(isempty(t), F(k).name, t{1});
        e.body = strtrim(regexprep(txt, '```catalog-change.*?```', '', 'once'));
        e.files = list_items(b, 'files');
        ca = list_items(b, 'code_ack');
        e.code_ack = regexprep(ca, ':.*$', '');
        fa = regexp(b, 'fallback_ack:\s*(\S+)', 'tokens', 'once');
        e.fallback_ack = ~isempty(fa) && strcmpi(fa{1}, 'true');
        % 'changes: false' = acknowledgement-only entry: its code_ack/fallback_ack
        % apply to the files it names, but it does NOT explain a changed sha256, so a
        % file whose bytes changed still needs an entry that describes the change.
        ch = regexp(b, 'changes:\s*(\S+)', 'tokens', 'once');
        e.changes = isempty(ch) || ~strcmpi(ch{1}, 'false');
        CE(end+1) = e; %#ok<AGROW>
    end
end

function items = list_items(b, key)
    items = {};
    seg = regexp(b, [key ':\s*\n((?:\s*-\s*[^\n]*\n?)*)'], 'tokens', 'once');
    if isempty(seg), return, end
    it = regexp(seg{1}, '-\s*([^\n]+)', 'tokens');
    items = cellfun(@(c) strtrim(c{1}), it, 'UniformOutput', false);
end

function [ackCode, ackFb, ents] = entries_for(CE, rel)
% pending entries whose file patterns match '<level>/<deployment>/<file>'
    ackCode = {}; ackFb = false; ents = {};
    for k = 1:numel(CE)
        hit = false;
        for f = 1:numel(CE(k).files)
            rx = ['^' regexprep(regexptranslate('escape', CE(k).files{f}), '\\\*', '[^/]*') '$'];
            if ~isempty(regexp(rel, rx, 'once')), hit = true; break, end
        end
        if hit
            if CE(k).changes, ents{end+1} = CE(k).title; end %#ok<AGROW>
            ackCode = union(ackCode, CE(k).code_ack);
            ackFb = ackFb || CE(k).fallback_ack;
        end
    end
end

function v = next_catalog_version(dest_root)
    today = char(datetime('today', 'Format', 'yyyy-MM-dd'));
    n = 1; cl = fullfile(dest_root, 'CHANGELOG.md');
    if isfile(cl)
        t = regexp(fileread(cl), ['## ' today '\.(\d+)'], 'tokens');
        if ~isempty(t), n = max(cellfun(@(c) str2double(c{1}), t)) + 1; end
    end
    v = sprintf('%s.%d', today, n);
end

function h = changelog_header()
    h = sprintf(['Newest first. Each version lists the files whose bytes changed (by sha256\n' ...
        'against the previous manifest), the change entries that explain them, the\n' ...
        'applied choices that differ (from the provenance sidecars), files still\n' ...
        'carrying a backfilled "pre-stamp" provenance, and any forced pushes.\n\n' ...
        'HOW TO TELL AN OLD COPY FROM A NEW ONE: compute the sha256 of your copy and\n' ...
        'look it up in manifest.csv (current) or manifests/manifest_<version>.csv. The\n' ...
        'row gives catalog_version_first, the build_id and the git_hash; the file''s\n' ...
        '<file>.prov.json gives the same build_id and what was applied.\n\n']);
end

function sec = build_changelog_section(v, git_hash, gate, refused, CE, prevRows, T, baseline, dest_root)
    L = {sprintf('## %s  (%s, pipeline commit %s)\n', v, char(datetime('today', 'Format', 'yyyy-MM-dd')), git_hash)};
    if baseline
        L{end+1} = sprintf(['BASELINE: first manifest with sha256 and provenance columns. Files are\n' ...
                            'recorded as they stand; no earlier hashes exist to compare against.\n\n']);
    end
    if baseline
        % No earlier hashes, so "changed" is unknowable; attribute every published
        % file that a pending entry's patterns cover, so the entry text is not lost
        % (2026-10-14: the first baseline push omitted its entry entirely).
        ch = find(~refused & arrayfun(@(g) ~isempty(g.entries), gate));
        L{end+1} = sprintf('Published files covered by change entries: %d (baseline: changed-vs-previous unknown)\n', numel(ch));
    else
        ch = find(arrayfun(@(g) g.changed, gate) & ~refused);
        L{end+1} = sprintf('Changed or added files published: %d\n', numel(ch));
    end
    for e = 1:numel(CE)
        mine = ch(arrayfun(@(k) any(strcmp(gate(k).entries, CE(e).title)), ch));
        if isempty(mine), continue, end
        L{end+1} = sprintf('\n### %s  (%d files; entry %s)\n\n%s\n', CE(e).title, numel(mine), ...
            erase(CE(e).path, [fileparts(fileparts(CE(e).path)) filesep]), CE(e).body); %#ok<AGROW>
        diffs = applied_diffs(gate(mine), dest_root);
        if ~isempty(diffs), L{end+1} = sprintf('\nApplied choices that changed: %s\n', strjoin(diffs, '; ')); end %#ok<AGROW>
    end
    pre = arrayfun(@(g) any(strcmp(g.notes, 'pre-stamp (backfilled)')), gate) & ~refused;
    if any(pre), L{end+1} = sprintf('\nPre-stamp (backfilled provenance, built before stamping): %d files\n', sum(pre)); end
    fz = find(arrayfun(@(g) ~isempty(g.forced), gate));
    for k = fz', L{end+1} = sprintf('\nFORCED %s despite: %s\n  reason: %s\n', gate(k).rel, strjoin(gate(k).refusals, ' | '), gate(k).forced); end %#ok<AGROW>
    if any(refused)
        L{end+1} = sprintf('\nRefused (not published; any earlier server copy kept): %d files\n', sum(refused));
        for k = find(refused)', L{end+1} = sprintf('  - %s: %s\n', gate(k).rel, strjoin(gate(k).refusals, ' | ')); end %#ok<AGROW>
    end
    if ~isempty(prevRows)
        cur = strcat(T.deployment, "|", T.level, "|", T.instrument);
        gone = setdiff(string(keys(prevRows)), cur);
        if ~isempty(gone), L{end+1} = sprintf('\nRemoved from the manifest: %s\n', strjoin(gone, ', ')); end
    end
    sec = [strjoin(L, '') newline];
end

function D = applied_diffs(G, dest_root)
% fields of `applied` that differ between the server's current sidecar and the new one
    D = {};
    for k = 1:numel(G)
        if isempty(G(k).prov), continue, end
        parts = split(G(k).rel, '/');
        sub = containers.Map({'L1','L2','L3','L4','L4_xspec'}, {'Level1_QC','Level2_QC','Level3_QC','Level4_QC','Level4_xspec'});
        old = fullfile(dest_root, parts{2}, sub(parts{1}), [parts{3} '.prov.json']);
        if ~isfile(old), continue, end
        o = jsondecode(fileread(old));
        if ~isfield(o, 'applied'), continue, end
        f = union(fieldnames(o.applied), fieldnames(G(k).prov.applied));
        for j = 1:numel(f)
            a = []; b = [];
            if isfield(o.applied, f{j}), a = o.applied.(f{j}); end
            if isfield(G(k).prov.applied, f{j}), b = G(k).prov.applied.(f{j}); end
            if ~isequaln(a, b), D{end+1} = f{j}; end %#ok<AGROW>
        end
    end
    D = unique(D);
end

function mark_entries_published(CE, v)
    for k = 1:numel(CE)
        t = fileread(CE(k).path);
        t = regexprep(t, '(```catalog-change\s*\n(?:.*?\n)?\s*status:\s*)pending', ['$1published ' v], 'once');
        fid = fopen(CE(k).path, 'w'); fwrite(fid, t, 'char'); fclose(fid);
    end
end
