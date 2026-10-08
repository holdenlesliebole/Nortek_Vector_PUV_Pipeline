% AUDIT_L4_COVERAGE  Per-record L4 sub-product presence and L4/L2 alignment.
%
%   Prints, for every L2 record in the registry, which L4 sub-products exist
%   and whether the L4 segment grid still matches the canonical L2 grid.
%
%   Alignment is checked on EVERY per-segment sub-product, not just the first
%   one present, and by TIME rather than by count -- equal counts do not prove
%   alignment, and a record whose L2 gained a leading segment is misaligned
%   from its very first segment. See shared/l4_l2_index_map.m.
%
%   METADATA IS CHECKED TOO (added 2026-07-27). Until then this audit looked
%   only at the seven sub-products, which is how TBR23/MOP580_5m sat on the
%   server for two months with `label`, `LATLON`, `doffp` and `shorenormal`
%   stripped, and reported clean the whole time. The cause is a narrow rebuild
%   script that recomputes a few products and re-saves the struct, destroying
%   everything it did not recompute (see the "partial L4 rebuild" note in
%   PIPELINE_NOTES.md). The loss is not cosmetic: PUV_L4_xspec reads
%   L4.LATLON and L4.shorenormal, and `shorenormal` is the record of which
%   rotation was applied.
%
%   CONTENT IS CHECKED TOO (added 2026-10-08). Time alignment does not prove
%   an L4 was built from the L2 now on disk: 29 of 65 L4 files had the right
%   segment grid but carried L4.eta.depth from an earlier L2, off by 0.5 mm to
%   3.2 cm, and this audit reported 0 problems. L4.eta.depth is a straight copy
%   of L2.depth (PUV_L4_eta.m), so on a content-current record the two agree
%   EXACTLY. The check takes max |L4.eta.depth - L2.depth| over time-matched
%   segments (via l4_l2_index_map) and calls a record stale above 1e-9 m, or
%   where the NaN pattern differs. A second, independent signal: L4.builtAt
%   earlier than the L2 file's mtime. L2 carries no build stamp of its own, and
%   an mtime can move without the content moving, so this one is a lead, not
%   a verdict; the content check is the verdict.
%
%   Run from PUV_Pipeline/:
%     >> run validation/audit_L4_coverage
%   Point it at another tree (e.g. a backup) by setting auditRoot first:
%     >> auditRoot = 'outputs/_pre_heading_ws_backup_2026-10-07';
%     >> run validation/audit_L4_coverage
%   It only reads.

startup_puv;   % assigns `root` in this workspace, so set ours AFTER it
if exist('auditRoot', 'var') && ~isempty(auditRoot)
    root = auditRoot;
else
    root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');
end
fprintf('audit root: %s\n', root);
staleTol = 1e-9;   % m; L4.eta.depth is copied from L2.depth, so current = exact
reg  = deployment_registry(); names = sort(keys(reg));
want = {'eta','ref','bispectra','boundwave','moments','reflection_free','pdf'};
meta = {'label','deploymentName','LATLON','doffp','shorenormal'};

fprintf('\n%-9s %-13s %6s', 'deploy', 'label', 'nL2');
fprintf(' %-8s', want{:});
fprintf(' %-8s', 'meta');
fprintf('  %s\n', 'alignment');

seen      = containers.Map('KeyType','char','ValueType','logical');
missList  = {};
metaList  = {};
alignList = {};
contList  = {};
stampList = {};
nRec      = 0;
nCurrent  = 0;

for d = 1:numel(names)
    try, fn = reg(names{d}); cfg = fn(); catch, continue; end
    if isKey(seen, cfg.name), continue; end
    seen(cfg.name) = true;

    fl = dir(fullfile(root, 'L2', cfg.name, '*_L2.mat'));
    for k = 1:numel(fl)
        lab = erase(fl(k).name, '_L2.mat');
        f4  = fullfile(root, 'L4', cfg.name, [lab '_L4.mat']);
        rec = [cfg.name '/' lab];
        if ~isfile(f4)
            fprintf('%-9s %-13s %6s  NO L4 FILE\n', cfg.name, lab, '-');
            missList{end+1} = [rec ' (no file)']; %#ok<SAGROW>
            continue
        end
        nRec = nRec + 1;

        S2 = load(fullfile(fl(k).folder, fl(k).name), 'L2'); L2 = S2.L2;
        S4 = load(f4, 'L4'); L4 = S4.L4;
        nL2 = numel(L2.time);

        fprintf('%-9s %-13s %6d', cfg.name, lab, nL2);
        for j = 1:numel(want)
            has = isfield(L4, want{j});
            fprintf(' %-8s', tern(has, 'y', '--'));
            if ~has
                missList{end+1} = [rec ' (' want{j} ')']; %#ok<SAGROW>
            end
        end
        % metadata: one column, since it is all-or-nothing in practice
        missMeta = meta(~isfield(L4, meta));
        fprintf(' %-8s', tern(isempty(missMeta), 'meta', 'META!'));
        if ~isempty(missMeta)
            metaList{end+1} = sprintf('%s -- missing %s', rec, strjoin(missMeta, ', ')); %#ok<SAGROW>
        end

        % --- alignment, checked on every per-segment sub-product ---
        note = 'ok';
        try
            [~, info] = l4_l2_index_map(L2, L4);
            if ~info.identity
                note = sprintf('SHIFTED src=%s nL4=%d nL2=%d maxOffset=%d matched=%d', ...
                    info.source, info.nL4, info.nL2, info.maxOffset, info.nMatched);
                alignList{end+1} = [rec ' -- ' note]; %#ok<SAGROW>
            end
            % do the sub-products agree with each other?
            lens = NaN(1, numel(want));
            for j = 1:numel(want)
                s = want{j};
                if isfield(L4, s) && isfield(L4.(s), 'time')
                    lens(j) = numel(L4.(s).time);
                end
            end
            lens = lens(~isnan(lens));
            if numel(unique(lens)) > 1
                note = [note ' | INTERNALLY INCONSISTENT: ' mat2str(unique(lens))];
                alignList{end+1} = [rec ' -- internally inconsistent ' mat2str(unique(lens))]; %#ok<SAGROW>
            end
        catch ME
            note = ['align check failed: ' ME.message];
            alignList{end+1} = [rec ' -- ' note]; %#ok<SAGROW>
        end

        % --- content: is this L4 built from the L2 now on disk? ---
        [isCur, cnote] = l4_content_current(L2, L4, staleTol);
        nCurrent = nCurrent + isCur;
        if ~isCur, contList{end+1} = [rec ' -- ' cnote]; end %#ok<SAGROW>
        note = [note ' | content ' tern(isCur, 'current', 'STALE')];

        % --- build stamp vs the L2 file's mtime (independent lead) ---
        if isfield(L4, 'builtAt') && isdatetime(L4.builtAt)
            t2 = datetime(fl(k).datenum, 'ConvertFrom', 'datenum');
            b4 = L4.builtAt; b4.TimeZone = '';
            if b4 < t2
                stampList{end+1} = sprintf('%s -- L4 builtAt %s < L2 mtime %s', rec, ...
                    datestr(b4, 'yyyy-mm-dd HH:MM'), datestr(t2, 'yyyy-mm-dd HH:MM')); %#ok<SAGROW>
            end
        else
            stampList{end+1} = [rec ' -- L4 has no builtAt stamp']; %#ok<SAGROW>
        end
        fprintf('  %s\n', note);
    end
end

fprintf('\n%d records inspected\n', nRec);
if nRec == 0
    error('audit_L4_coverage:noRecords', ['No L2/L4 pairs found under %s. An empty ' ...
        'audit is not a clean audit.'], root);
end
fprintf('\nmissing sub-products (%d):\n', numel(missList));
for i = 1:numel(missList), fprintf('  %s\n', missList{i}); end
fprintf('\nrecords with stripped METADATA (%d):\n', numel(metaList));
for i = 1:numel(metaList), fprintf('  %s\n', metaList{i}); end
if isempty(metaList), fprintf('  none\n'); end

fprintf('\nalignment problems (%d):\n', numel(alignList));
for i = 1:numel(alignList), fprintf('  %s\n', alignList{i}); end

fprintf('\nCONTENT: %d/%d content-current (L4.eta.depth == L2.depth to %g m)\n', ...
    nCurrent, nRec, staleTol);
fprintf('content-stale records (%d):\n', numel(contList));
for i = 1:numel(contList), fprintf('  %s\n', contList{i}); end
if isempty(contList), fprintf('  none\n'); end
fprintf('\nL4 built before its L2 file was last written (%d; a lead, not a verdict):\n', numel(stampList));
for i = 1:numel(stampList), fprintf('  %s\n', stampList{i}); end
if isempty(stampList), fprintf('  none\n'); end

function [isCur, note] = l4_content_current(L2, L4, tol)
% L4.eta.depth is copied verbatim from L2.depth at build time, so any
% difference on a time-matched segment means L4 was built from another L2.
isCur = false;
if ~isfield(L4, 'eta') || ~isfield(L4.eta, 'depth')
    note = 'no L4.eta.depth to compare'; return
end
o.source = 'eta';
l4map = l4_l2_index_map(L2, L4, o);
m = ~isnan(l4map);
if ~any(m), note = 'no time-matched segments'; return, end
d2 = L2.depth(m); d4 = L4.eta.depth(l4map(m));
d2 = d2(:); d4 = d4(:);
nanDiff = sum(isnan(d2) ~= isnan(d4));
f = ~isnan(d2) & ~isnan(d4);
mx = max([0; abs(d4(f) - d2(f))]);
isCur = (mx <= tol) && nanDiff == 0;
note = sprintf('max|L4.eta.depth - L2.depth| = %.3g m over %d segments, NaN-pattern mismatches %d', ...
    mx, sum(f), nanDiff);
end

function s = tern(c, a, b), if c, s = a; else, s = b; end, end
