% REPAIR_L4_METADATA_2026_07_27  Fill in L4 fields that a partial rebuild dropped.
%
%   Some L4 records were rebuilt by narrow scripts that recompute only the
%   products they care about and re-save the struct, silently dropping
%   everything else. `scripts/reprocess_heading_fix.m` is the known offender:
%   it writes only eta / bispectra / boundwave / ref / reflection_free, with no
%   `pdf` and no metadata block. It damaged TBR23/MOP580_5m in May 2026 and
%   TOR16B/C/D on 2026-07-27, both times during a heading fix.
%
%   The loss matters beyond tidiness: PUV_L4_xspec reads L4.LATLON and
%   L4.shorenormal, so a stripped record breaks any multi-instrument run, and
%   `shorenormal` is the record of which rotation was applied -- exactly the
%   provenance you want after correcting a heading.
%
%   This script is ADDITIVE. It never overwrites a field that is already
%   present, so an existing computed product is preserved bit-for-bit; it only
%   fills gaps. Metadata is taken from L1/L2 exactly as PUV_L4_driver does.
%   `pdf` and `moments` are recomputed if absent (both are cheap -- no
%   per-segment FFTs -- unlike bispectra, which is never touched).
%
%   Detection is by scan, not hardcoded, so it also catches records damaged in
%   ways not yet seen. Backups go to outputs/_pre_L4meta_backup_2026-07-27/.
%
%   Run from PUV_Pipeline/:
%     >> run scripts/repair_L4_metadata_2026_07_27

startup_puv

outRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
bkRoot  = fullfile(outRoot, '_pre_L4meta_backup_2026-07-27');

META = {'label','deploymentName','LATLON','doffp','shorenormal','mopStation'};
PROD = {'eta','ref','bispectra','boundwave','moments','reflection_free','pdf'};

reg = deployment_registry(); ks = sort(keys(reg));
seen = containers.Map('KeyType','char','ValueType','logical');

todo = {};
fprintf('\n=== Scanning for L4 records with missing fields ===\n');
for i = 1:numel(ks)
    try, fn = reg(ks{i}); cfg = fn(); catch, continue, end
    if isKey(seen, cfg.name), continue, end
    seen(cfg.name) = true;
    fl = dir(fullfile(outRoot, 'L4', cfg.name, '*_L4.mat'));
    for k = 1:numel(fl)
        p = fullfile(fl(k).folder, fl(k).name);
        try
            info = h5info(p, '/L4');
            present = erase([{info.Groups.Name}, {info.Datasets.Name}], '/L4/');
        catch
            S = load(p, 'L4'); present = fieldnames(S.L4).';
        end
        miss = setdiff([META, PROD], present);
        if ~isempty(miss)
            lab = erase(fl(k).name, '_L4.mat');
            todo(end+1,:) = {cfg.name, lab, p, miss}; %#ok<SAGROW>
            fprintf('  %-9s %-13s missing: %s\n', cfg.name, lab, strjoin(miss, ', '));
        end
    end
end

fprintf('\n%d record(s) need repair\n', size(todo,1));
if isempty(todo), fprintf('Nothing to do.\n'); return, end

nOk = 0; nFail = 0;
for r = 1:size(todo,1)
    dep = todo{r,1}; lab = todo{r,2}; l4Path = todo{r,3}; miss = todo{r,4};
    fprintf('\n[%d/%d] %s/%s\n', r, size(todo,1), dep, lab);
    try
        l1Path = fullfile(outRoot, 'L1', dep, [lab '_processed.mat']);
        l2Path = fullfile(outRoot, 'L2', dep, [lab '_L2.mat']);
        if ~isfile(l1Path) || ~isfile(l2Path)
            error('missing L1 or L2 for %s/%s', dep, lab);
        end

        rel = extractAfter(l4Path, [outRoot filesep]);
        dst = fullfile(bkRoot, rel);
        if ~isfolder(fileparts(dst)), mkdir(fileparts(dst)); end
        if ~isfile(dst), copyfile(l4Path, dst); end

        S4 = load(l4Path, 'L4'); L4 = S4.L4;
        PUV = getfield(load(l1Path, 'PUV'), 'PUV'); %#ok<GFLD>
        L2  = getfield(load(l2Path, 'L2'),  'L2');  %#ok<GFLD>

        % Guard: the grid the products were built on must match the L2 we are
        % about to take metadata from, or they describe different hours.
        [~, ainfo] = l4_l2_index_map(L2, L4);
        if ~ainfo.identity
            error(['L4 grid does not match L2 (nL4=%d nL2=%d maxOffset=%d); ' ...
                   'rebuild rather than patch'], ainfo.nL4, ainfo.nL2, ainfo.maxOffset);
        end

        added = {};
        % --- metadata, straight from L1/L2 exactly as PUV_L4_driver sets it ---
        if ~isfield(L4,'label'),          L4.label = PUV.label;                   added{end+1}='label'; end %#ok<SAGROW>
        if ~isfield(L4,'deploymentName'), L4.deploymentName = PUV.deploymentName; added{end+1}='deploymentName'; end %#ok<SAGROW>
        if ~isfield(L4,'LATLON'),         L4.LATLON = PUV.LATLON;                 added{end+1}='LATLON'; end %#ok<SAGROW>
        if ~isfield(L4,'doffp'),          L4.doffp = PUV.doffp;                   added{end+1}='doffp'; end %#ok<SAGROW>
        if ~isfield(L4,'shorenormal'),    L4.shorenormal = L2.shorenormal;        added{end+1}='shorenormal'; end %#ok<SAGROW>
        if ~isfield(L4,'mopStation') && isfield(L2,'mopStation')
            L4.mopStation = L2.mopStation;                                        added{end+1}='mopStation'; %#ok<SAGROW>
        end

        % --- cheap products, recomputed only if absent ---
        if ~isfield(L4,'moments'), L4.moments = PUV_L4_moments(L2);            added{end+1}='moments'; end %#ok<SAGROW>
        if ~isfield(L4,'pdf'),     L4.pdf = PUV_L4_velocity_pdf(PUV, L2);      added{end+1}='pdf'; end %#ok<SAGROW>

        % builtAt: preserve the original build stamp if it survived.
        if ~isfield(L4,'builtAt'), L4.builtAt = datetime('now'); added{end+1}='builtAt'; end %#ok<SAGROW>

        save(l4Path, 'L4', '-v7.3');

        info = h5info(l4Path, '/L4');
        present = erase([{info.Groups.Name}, {info.Datasets.Name}], '/L4/');
        stillMissing = setdiff([META, PROD], present);
        fprintf('  added: %s\n', strjoin(added, ', '));
        if isempty(stillMissing)
            fprintf('  COMPLETE (shorenormal=%.2f doffp=%.2f)\n', L4.shorenormal, L4.doffp);
            nOk = nOk + 1;
        else
            fprintf(2, '  STILL MISSING: %s\n', strjoin(stillMissing, ', '));
            nFail = nFail + 1;
        end
    catch ME
        fprintf(2, '  FAIL: %s\n', ME.message);
        nFail = nFail + 1;
    end
end

fprintf('\n=== Done: %d repaired, %d failed ===\n', nOk, nFail);
fprintf('Next: validation/audit_L4_coverage, then scripts/copy_to_server.m\n');
