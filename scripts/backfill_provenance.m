% BACKFILL_PROVENANCE  Write provenance sidecars for catalog files built before
% stamping (B1 backfill). Never modifies a .mat.
%
%   >> dryRun = true;  run scripts/backfill_provenance          % report only (default)
%   >> dryRun = false; run scripts/backfill_provenance          % write sidecars beside the .mat
%   >> sidecarRoot = '<scratch>'; dryRun = false; run ...       % write into a parallel tree
%
% Optional workspace variables: outRoot (default: this repo's outputs),
% sidecarRoot, onlyDeps (cellstr), refresh (true: rewrite existing BACKFILLED
% sidecars; real build sidecars are never touched).
%
% Each sidecar is marked
%   backfilled = 'backfilled <date>; built before stamping; values read from the
%                 file, not recorded at build'
% with code.git_hash 'unknown (pre-stamp)'. `applied` comes only from what the
% file stores (shared/prov_applied with no build-time config); anything else is
% 'not recorded'. Parent links are set ONLY when a content check passes;
% otherwise the parent build_id is 'unverified', which copy_to_server refuses:
%   L2 -> L1   L2 time grid inside the L1 span, and doffp equal
%   L3 -> L2   identical time grid and segValid
%   L4 -> L2   time-matched (l4_l2_index_map) eta.depth == L2.depth to 1e-9 m
%   xspec -> L4  every member's median eta.depth equals the stored medDepth
% Records are processed parents first, so a verified link carries the parent's
% (possibly just-written) build_id.
%
% Author: Holden Leslie-Bole, 2026

repoRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(repoRoot, 'startup_puv.m'));
if ~exist('outRoot', 'var'), outRoot = fullfile(repoRoot, 'outputs'); end
if ~exist('dryRun', 'var'), dryRun = true; end
if ~exist('refresh', 'var'), refresh = false; end
opts = struct();
if exist('sidecarRoot', 'var') && ~isempty(sidecarRoot), opts.sidecarRoot = sidecarRoot; opts.outRoot = outRoot; end
stampDate = char(datetime('today', 'Format', 'yyyy-MM-dd'));
NOTE = sprintf('backfilled %s; built before stamping; values read from the file, not recorded at build', stampDate);
if isfield(opts, 'sidecarRoot'), where = opts.sidecarRoot; else, where = 'beside each .mat'; end   % (a ternary() call would evaluate opts.sidecarRoot even when absent)
fprintf('backfill_provenance: outRoot %s | dryRun %d | sidecars %s\n', outRoot, dryRun, where);

reg = deployment_registry(); ks = reg.keys;
assigned = containers.Map();   % path -> build_id given in THIS run (so dry runs link correctly)
counts = struct('written', 0, 'kept_real', 0, 'kept_backfilled', 0, 'missing', 0, 'unverified', 0);
log = {};
for i = 1:numel(ks)
    fn = reg(ks{i}); cfg = fn();
    if ~strcmp(cfg.name, ks{i}), continue, end                 % registry alias
    if exist('onlyDeps', 'var') && ~any(strcmp(onlyDeps, cfg.name)), continue, end
    dep = cfg.name; l4medDepth = containers.Map();
    for j = 1:numel(cfg.instruments)
        lab = cfg.instruments(j).label;
        stub = struct('label', lab, 'mopStation', getf(cfg.instruments(j), 'mopStation', ''));
        F = struct('L1', fullfile(outRoot,'L1',dep,[lab '_processed.mat']), 'L2', fullfile(outRoot,'L2',dep,[lab '_L2.mat']), ...
                   'L3', fullfile(outRoot,'L3',dep,[lab '_L3.mat']),        'L4', fullfile(outRoot,'L4',dep,[lab '_L4.mat']));
        S1 = []; S2 = [];
        for lv = {'L1','L2','L3','L4'}
            L = lv{1}; f = F.(L);
            if ~isfile(f), counts.missing = counts.missing + 1; continue, end
            ex = read_prov_sidecar_only(f, opts);
            if ~isempty(ex) && ~(isfield(ex, 'backfilled') && ~isempty(ex.backfilled))
                counts.kept_real = counts.kept_real + 1; continue          % a real build stamp: never touched
            end
            if ~isempty(ex) && ~refresh
                counts.kept_backfilled = counts.kept_backfilled + 1; continue
            end
            q = load(f); vn = fieldnames(q); S = q.(vn{1}); clear q
            par = struct('level', {}, 'path', {}, 'build_id', {}, 'link', {});
            switch L
            case 'L1'
                S1 = S;
            case 'L2'
                S2 = S;
                if isempty(S1) && isfile(F.L1), q = load(F.L1); vn = fieldnames(q); S1 = q.(vn{1}); clear q, end
                okL = ~isempty(S1) && utc(S2.time(1)) >= utc(S1.time(1)) - minutes(30) && utc(S2.time(end)) <= utc(S1.time(end)) + minutes(30) ...
                      && isequal(getf(S2,'doffp',NaN), getf(S1,'doffp',NaN));
                par(1) = link('L1', F.L1, okL, 'L2 time grid inside L1 span, doffp equal', opts, assigned);
            case 'L3'
                if isempty(S2), q = load(F.L2); S2 = q.L2; clear q, end
                okL = isequal(S.time, S2.time) && (~isfield(S, 'segValid') || isequal(S.segValid, S2.segValid));
                par(1) = link('L2', F.L2, okL, 'identical time grid and segValid', opts, assigned);
            case 'L4'
                if isempty(S2), q = load(F.L2); S2 = q.L2; clear q, end
                m = l4_l2_index_map(S2, S); v = S2.segValid(:) & ~isnan(m(:));
                d = max(abs(S.eta.depth(m(v)) - S2.depth(v)));
                okL = ~isempty(d) && d <= 1e-9;
                par(1) = link('L2', F.L2, okL, sprintf('time-matched eta.depth == L2.depth (max diff %.1e m)', d), opts, assigned);
                l4medDepth(lab) = median(S.eta.depth, 'omitnan');
            end
            [applied, fb] = prov_applied(L, S, stub);
            P = stamp(L, applied, fb, par, NOTE);
            nUnv = sum(strcmp({par.build_id}, 'unverified'));
            counts.unverified = counts.unverified + nUnv;
            log{end+1} = sprintf('%-7s %-11s %-3s %s%s', dep, lab, L, ternary(dryRun, 'would write', 'wrote'), ...
                ternary(nUnv > 0, ['  [UNVERIFIED parent: ' strjoin({par.link}, '; ') ']'], '')); %#ok<SAGROW>
            assigned(f) = P.build_id;
            if ~dryRun, write_prov_sidecar(f, P, opts); end
            counts.written = counts.written + 1;
            clear S
        end
    end
    % deployment-level xspec
    fx = fullfile(outRoot, 'L4_xspec', dep, 'xspec.mat');
    if isfile(fx)
        ex = read_prov_sidecar_only(fx, opts);
        if ~isempty(ex) && ~(isfield(ex, 'backfilled') && ~isempty(ex.backfilled))
            counts.kept_real = counts.kept_real + 1;
        elseif ~isempty(ex) && ~refresh
            counts.kept_backfilled = counts.kept_backfilled + 1;
        else
            q = load(fx, 'L4xs'); X = q.L4xs; clear q
            par = struct('level', {}, 'path', {}, 'build_id', {}, 'link', {});
            for k = 1:numel(X.instruments)
                lab = X.instruments(k).label; f4 = fullfile(outRoot, 'L4', dep, [lab '_L4.mat']);
                if isKey(l4medDepth, lab), md = l4medDepth(lab);
                else, q = load(f4, 'L4'); md = median(q.L4.eta.depth, 'omitnan'); clear q, end
                okL = abs(md - X.instruments(k).medDepth) <= 1e-9;
                par(end+1) = link('L4', f4, okL, sprintf('%s medDepth equal', lab), opts, assigned); %#ok<SAGROW>
            end
            [applied, fb] = prov_applied('L4_xspec', X);
            P = stamp('L4_xspec', applied, fb, par, NOTE);
            nUnv = sum(strcmp({par.build_id}, 'unverified'));
            counts.unverified = counts.unverified + nUnv;
            log{end+1} = sprintf('%-7s %-11s %-3s %s%s', dep, 'xspec', 'X', ternary(dryRun, 'would write', 'wrote'), ...
                ternary(nUnv > 0, '  [UNVERIFIED member]', '')); %#ok<SAGROW>
            assigned(fx) = P.build_id;
            if ~dryRun, write_prov_sidecar(fx, P, opts); end
            counts.written = counts.written + 1;
        end
    end
end
fprintf('%s\n', log{:});
fprintf(['\nbackfill_provenance: %s %d sidecars; kept %d real and %d existing backfilled; ' ...
         '%d level files missing; %d parent links UNVERIFIED\n'], ternary(dryRun, 'would write', 'wrote'), ...
    counts.written, counts.kept_real, counts.kept_backfilled, counts.missing, counts.unverified);

function P = stamp(level, applied, fb, par, note)
    P = struct();
    P.schema = 1; P.build_id = char(java.util.UUID.randomUUID()); P.level = level;
    P.builtAt = 'not recorded (built before stamping)';
    P.backfilled = note;
    P.code = struct('git_hash', 'unknown (pre-stamp)', 'dirty', false, 'repo_root', '', 'branch', '', ...
                    'matlab', '', 'resolved', struct());
    P.parents = rmfield(par, 'link'); if isempty(par), P.parents = []; end
    P.parent_links = {par.link};
    P.applied = applied; P.fallbacks = fb;
end

function p = link(level, path, ok, what, opts, assigned)
    p = struct('level', level, 'path', path, 'build_id', 'unverified', 'link', ['unverified: ' what]);
    if ok
        if isKey(assigned, path)
            p.build_id = assigned(path); p.link = ['content-verified: ' what]; return
        end
        pp = read_prov_sidecar_only(path, opts);
        if ~isempty(pp)
            p.build_id = pp.build_id; p.link = ['content-verified: ' what];
        else
            p.link = ['content check passed but parent has no sidecar: ' what];
        end
    end
end

function P = read_prov_sidecar_only(f, opts)
    P = []; sc = sidecar_path(f, opts);
    if isfile(sc), P = jsondecode(fileread(sc)); end
end

function t = utc(t)
% times are stored both with and without a zone; all are UTC
    if isempty(t.TimeZone), t.TimeZone = 'UTC'; end
end

function v = getf(s, f, d), if isstruct(s) && isfield(s, f), v = s.(f); else, v = d; end, end
function s = ternary(c, a, b), if c, s = a; else, s = b; end, end
