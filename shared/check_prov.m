function res = check_prov(req)
% CHECK_PROV  Decide whether one output file may be published, from its
% provenance against the CURRENT file bytes, code, config and parent files.
%
%   res = check_prov(req)
%
% req fields
%   .matPath        the .mat to check
%   .level          'L1' | 'L2' | 'L3' | 'L4' | 'L4_xspec'
%   .instr, .cfg    the record's CURRENT config instrument and deployment cfg
%                   (cfg is used for l1_qc_opts)
%   .parents        struct array (.level, .path) of the CURRENT parent files
%   .repoRoot       repository to run git in (default: this repo)
%   .ackCodeLevels  cellstr of levels whose code changes since the build are
%                   acknowledged by a pending change entry (B2)
%   .ackFallback    true if a pending change entry acknowledges fallbacks
%   .fileSha        (optional) precomputed SHA-256 of matPath
%   .opts           sidecar location options (see read_prov)
%
% res fields
%   .ok         true when nothing refuses the file
%   .refusals   cellstr; each starts with HARD: or SOFT: and names the field,
%               the value expected and the value found
%   .notes      cellstr (e.g. 'pre-stamp (backfilled)')
%   .prov       the provenance read
%
% HARD refusals cannot be acknowledged away:
%   - no provenance; no file_sha256; file bytes differ from file_sha256
%     ("modified outside the pipeline": another repo or a hand edit rewrote it)
%   - config or derived value now differs from what was applied
%   - a parent's current build_id differs from the one recorded (built from a
%     superseded parent -- the 29 stale L4s of 2026-10-07 would refuse here)
% SOFT refusals clear when a pending change entry acknowledges them:
%   - the level's code changed since the build commit
%   - an external (out-of-repo) dependency's bytes changed since the build
%   - the build recorded a fallback
%   - built from uncommitted code (dirty)
%
% Author: Holden Leslie-Bole, 2026

    res = struct('ok', false, 'refusals', {{}}, 'notes', {{}}, 'prov', []);
    if ~isfield(req, 'opts'), req.opts = struct(); end
    if ~isfield(req, 'repoRoot') || isempty(req.repoRoot), req.repoRoot = fileparts(fileparts(mfilename('fullpath'))); end
    if ~isfield(req, 'ackCodeLevels'), req.ackCodeLevels = {}; end
    if ~isfield(req, 'ackFallback'), req.ackFallback = false; end
    if ~isfield(req, 'instr'), req.instr = []; end
    if ~isfield(req, 'cfg'), req.cfg = []; end
    if ~isfield(req, 'parents'), req.parents = struct('level', {}, 'path', {}); end

    P = read_prov(req.matPath, req.opts);
    res.prov = P;
    if isempty(P)
        res.refusals{end+1} = 'HARD: no provenance (no sidecar, no embedded block)';
        return
    end
    backfilled = isfield(P, 'backfilled') && ~isempty(P.backfilled);
    if backfilled, res.notes{end+1} = 'pre-stamp (backfilled)'; end

    % --- bytes: the sidecar must describe THIS file ---
    if ~isfield(P, 'file_sha256') || isempty(P.file_sha256)
        res.refusals{end+1} = 'HARD: provenance has no file_sha256 (sidecar missing?)';
    else
        if isfield(req, 'fileSha') && ~isempty(req.fileSha), sha = req.fileSha; else, sha = file_sha256(req.matPath); end
        if ~strcmp(sha, P.file_sha256)
            res.refusals{end+1} = sprintf('HARD: modified outside the pipeline: sha256 %s, recorded %s', sha(1:16), P.file_sha256(1:16));
        end
    end

    % --- code ---
    if ~backfilled
        if isfield(P.code, 'dirty') && P.code.dirty && ~any(strcmp(req.ackCodeLevels, req.level))
            res.refusals{end+1} = 'SOFT: built from uncommitted code (dirty), not acknowledged';
        end
        h = P.code.git_hash;
        [st, ~] = system(sprintf('git -C "%s" cat-file -e %s^{commit} 2>/dev/null', req.repoRoot, h));
        if st ~= 0
            res.refusals{end+1} = sprintf('HARD: build commit %s is not in this repository', h(1:min(12,end)));
        else
            paths = strjoin(cellfun(@(p) ['"' p '"'], level_code_paths(req.level), 'UniformOutput', false), ' ');
            [st2, ~] = system(sprintf('git -C "%s" diff --quiet %s HEAD -- %s', req.repoRoot, h, paths));
            if st2 ~= 0 && ~any(strcmp(req.ackCodeLevels, req.level))
                res.refusals{end+1} = sprintf('SOFT: %s code changed since build commit %s, not acknowledged by a change entry', ...
                    req.level, h(1:12));
            end
        end
    end

    % --- external (out-of-repo) dependencies: same files, same bytes? ---
    if ~backfilled && isfield(P, 'external') && ~isempty(P.external) && ~any(strcmp(req.ackCodeLevels, req.level))
        E = P.external; if iscell(E), E = [E{:}]; end
        for k = 1:numel(E)
            now = which(E(k).name); nowSha = 'missing';
            if ~isempty(now) && isfile(now), nowSha = file_sha256(now); end
            if ~strcmp(nowSha, E(k).sha256)
                res.refusals{end+1} = sprintf('SOFT: external dependency %s changed since the build (recorded %s at %s, now %s at %s), not acknowledged', ...
                    E(k).name, short(E(k).sha256), E(k).path, short(nowSha), now);
            end
        end
    end

    % --- fallbacks ---
    if isfield(P, 'fallbacks') && ~isempty(P.fallbacks) && ~req.ackFallback
        fb = P.fallbacks; if ischar(fb), fb = {fb}; end
        res.refusals{end+1} = ['SOFT: build fell back: ' strjoin(cellstr(fb), '; ')];
    end

    % --- config / applied (HARD) ---
    res.refusals = [res.refusals, config_refusals(req, P)];

    % --- lineage (HARD) ---
    PP = P.parents;
    if isempty(PP), PP = struct('level', {}, 'path', {}, 'build_id', {}); end
    for k = 1:numel(PP)
        if iscell(PP), pk = PP{k}; else, pk = PP(k); end
        if strcmp(pk.build_id, 'unstamped') || strcmp(pk.build_id, 'unverified')
            res.refusals{end+1} = sprintf('HARD: parent %s lineage %s', pk.level, pk.build_id);
            continue
        end
        cur = req.parents(strcmp({req.parents.level}, pk.level));
        if isempty(cur)
            res.refusals{end+1} = sprintf('HARD: current %s parent not supplied for lineage check', pk.level);
            continue
        end
        ok = false;
        for c = 1:numel(cur)
            cp = read_prov(cur(c).path, req.opts);
            if ~isempty(cp) && strcmp(cp.build_id, pk.build_id), ok = true; end
        end
        if ~ok
            cp = read_prov(cur(1).path, req.opts); now_id = 'unstamped';
            if ~isempty(cp), now_id = cp.build_id; end
            res.refusals{end+1} = sprintf('HARD: built from a superseded %s: recorded parent %s, current %s', ...
                pk.level, short(pk.build_id), short(now_id));
        end
    end

    res.ok = isempty(res.refusals);
end

function p = level_code_paths(level)
    switch level
        case 'L1',       p = {'L1_raw_to_qc', 'shared'};
        case 'L2',       p = {'L2_spectral', 'shared'};
        case 'L3',       p = {'L3_forcing', 'L3_transport', 'shared'};
        case 'L4',       p = {'L4_ig', 'shared'};
        case 'L4_xspec', p = {'L4_ig'};
        otherwise,       p = {'.'};
    end
end

function R = config_refusals(req, P)
    R = {};
    A = P.applied; I = req.instr;
    if isempty(I) || ~isstruct(I), return, end
    chk = @(name, rec, now) cmp(name, rec, now);
    switch req.level
    case 'L1'
        R = [R chk('doffp', field(A,'doffp'), field(I,'doffp'))];
        R = [R chk('LATLON', field(A,'LATLON'), field(I,'latlon'))];
        if isfield(A, 'qc_opts') && isstruct(A.qc_opts) && ~isempty(req.cfg)
            R = [R chk('qc.opts', A.qc_opts, l1_qc_opts(req.cfg))];
        end
        if isfield(A, 'coordSystem') && strcmp(A.coordSystem, 'XYZ') && isfield(I, 'heading') && isfinite(I.heading)
            R = [R chk('heading', field(A,'heading_deg'), I.heading)];
        end
        if isfield(A, 'coordSystem') && strcmp(A.coordSystem, 'ENU') && isfield(A, 'declinationApplied') && ~isequal(A.declinationApplied, true)
            R{end+1} = 'HARD: ENU record without declinationApplied (pre-2026-10-07 L1)';
        end
    case 'L2'
        R = [R chk('doffp', field(A,'doffp'), field(I,'doffp'))];
        if isfield(I, 'shorenormal') && ~isempty(I.shorenormal) && isfinite(I.shorenormal)
            R = [R chk('shorenormal', field(A,'shorenormal'), I.shorenormal)];
        end
        if exist('site_grain_size', 'file') == 2 && isnumeric(field(A,'bedstress_D84_m'))
            try
                gs = site_grain_size(I.label);
                R = [R chk('bedstress_D84_m', A.bedstress_D84_m, gs.D84)];
                if isnumeric(field(A,'bedstress_D50_m_used')), R = [R chk('bedstress_D50_m_used', A.bedstress_D50_m_used, gs.D50)]; end
            catch
            end
        end
    case 'L3'
        % ws depends on the per-segment viscosity, so the comparable facts are the
        % settling-velocity CONSTANTS: those recorded must equal today's default.
        % A file with no recorded constants (built before 2026-10-07) is refused.
        [~, c1Now, c2Now] = settling_velocity(2.5e-4, 2650, 1025, 1e-6);
        c1 = field(A,'ws_C1'); c2 = field(A,'ws_C2');
        if ischar(c2) && strcmp(c2, 'not recorded')
            R{end+1} = 'HARD: config/applied mismatch on ws constants: not recorded (built before 2026-10-07)';
        else
            R = [R chk('ws_C2', c2, c2Now)];
            if ischar(c1) && strcmp(c1, 'not recorded')
                R{end+1} = sprintf('HARD: config/applied mismatch on ws_C1: not recorded, now %g', c1Now);
            else
                R = [R chk('ws_C1', c1, c1Now)];
            end
        end
        if ischar(field(A,'D50_source')) && startsWith(A.D50_source, 'site_grain_size')
            try, gs = site_grain_size(I.label); R = [R chk('D50', A.D50, gs.D50)]; catch, end
        end
    case 'L4'
        R = [R chk('doffp', field(A,'doffp'), field(I,'doffp'))];
        R = [R chk('LATLON', field(A,'LATLON'), field(I,'latlon'))];
    end
end

function v = field(s, f)
    if isstruct(s) && isfield(s, f), v = s.(f); else, v = 'not recorded'; end
end

function R = cmp(name, rec, now)
% One HARD refusal if a recorded value differs from the current one. A value
% the file does not record is not compared (and is visible as 'not recorded').
    R = {};
    if ischar(rec) && strcmp(rec, 'not recorded'), return, end
    if ischar(now) && strcmp(now, 'not recorded'), return, end
    if ~values_equal(rec, now)
        R{1} = sprintf('HARD: config/applied mismatch on %s: applied %s, now %s', name, show(rec), show(now));
    end
end

function tf = values_equal(a, b)
    if isstruct(a) && isstruct(b)
        fa = fieldnames(a); fb = fieldnames(b);
        if ~isempty(setxor(fa, fb)), tf = false; return, end
        tf = true;
        for k = 1:numel(fa), tf = tf && values_equal(a.(fa{k}), b.(fa{k})); end
    elseif (isnumeric(a) || islogical(a)) && (isnumeric(b) || islogical(b))
        a = double(a(:)); b = double(b(:));
        tf = numel(a) == numel(b) && all((isnan(a) & isnan(b)) | abs(a - b) <= 1e-9 * max(1, abs(b)));
    elseif (ischar(a) || isstring(a)) && (ischar(b) || isstring(b))
        tf = strcmp(char(a), char(b));
    else
        tf = isequaln(a, b);
    end
end

function s = show(v)
    if isnumeric(v) || islogical(v), s = mat2str(double(v(:)'), 8);
    elseif ischar(v) || isstring(v), s = char(v);
    else, s = class(v); end
end

function s = short(id), s = id(1:min(8, numel(id))); end
