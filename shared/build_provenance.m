function prov = build_provenance(level, S, parents, instr, opts)
% BUILD_PROVENANCE  Provenance block for one output file, recorded at build time.
%
%   prov = build_provenance(level, S, parents)
%   prov = build_provenance(level, S, parents, instr)
%   prov = build_provenance(level, S, parents, instr, opts)
%
% level    'L1' | 'L2' | 'L3' | 'L4' | 'L4_xspec'
% S        the level struct exactly as it will be saved
% parents  struct array with fields .level and .path: the upstream files this
%          build actually loaded (L2 <- L1; L3, L4 <- L2; xspec <- member L4s).
%          Each parent's build_id is read from its sidecar; a parent with no
%          sidecar is recorded as 'unstamped'.
% instr    (optional) config instrument struct used for the build
% opts     .keyFunctions  cellstr of function names whose which() must resolve
%                         inside this repo (default: per level)
%          .sidecarRoot / .outRoot  see read_prov
%
% Fields (schema 1): schema, build_id, level, builtAt (UTC), code.git_hash,
% code.dirty, code.repo_root, code.branch, code.matlab, code.resolved, parents,
% applied (prov_applied), fallbacks. The sidecar adds file_sha256 when written
% (write_prov_sidecar), because an embedded block cannot contain its own hash.
%
% WHY: on 2026-10-07/08, 29 L4 files had been built from superseded L2s, a QC
% bound was injected by a rerun script rather than the config, a stale
% settling-velocity default sat unseen in L3, a rerun silently ran another
% checkout's code, and two CDIP fetches fell back silently. None of it was
% recorded in the files. Lineage by build_id turns staleness into a string
% comparison (scripts/copy_to_server.m, shared/check_prov.m).
%
% Author: Holden Leslie-Bole, 2026

    if nargin < 3 || isempty(parents), parents = struct('level', {}, 'path', {}); end
    if nargin < 4, instr = []; end
    if nargin < 5, opts = struct(); end

    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    prov = struct();
    prov.schema   = 1;
    prov.build_id = char(java.util.UUID.randomUUID());
    prov.level    = level;
    prov.builtAt  = char(string(datetime('now', 'TimeZone', 'UTC'), 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

    code = struct();
    code.repo_root = repoRoot;
    [~, h] = system(sprintf('git -C "%s" rev-parse HEAD 2>/dev/null', repoRoot));     code.git_hash = strtrim(h);
    [~, b] = system(sprintf('git -C "%s" rev-parse --abbrev-ref HEAD 2>/dev/null', repoRoot)); code.branch = strtrim(b);
    [~, d] = system(sprintf('git -C "%s" status --porcelain -uno 2>/dev/null', repoRoot));
    code.dirty  = ~isempty(strtrim(d));
    code.matlab = version;
    if isempty(code.git_hash) || ~isempty(regexp(code.git_hash, '[^0-9a-f]', 'once'))
        error('build_provenance:git', 'cannot read the git hash of %s', repoRoot);
    end

    if isfield(opts, 'keyFunctions'), kf = opts.keyFunctions; else, kf = default_key_functions(level); end
    res = struct();
    for k = 1:numel(kf)
        w = which(kf{k});
        if isempty(w) || ~startsWith(w, [repoRoot filesep])
            error('build_provenance:shadow', '%s resolves to "%s", outside %s', kf{k}, w, repoRoot);
        end
        res.(kf{k}) = extractAfter(w, [repoRoot filesep]);
    end
    code.resolved = res;
    prov.code = code;

    P = struct('level', {}, 'path', {}, 'build_id', {});
    for k = 1:numel(parents)
        pp = read_prov(parents(k).path, opts);
        bid = 'unstamped';
        if ~isempty(pp), bid = pp.build_id; end
        P(end+1) = struct('level', parents(k).level, 'path', parents(k).path, 'build_id', bid); %#ok<AGROW>
    end
    prov.parents = P;

    [prov.applied, prov.fallbacks] = prov_applied(level, S, instr);
end

function kf = default_key_functions(level)
    switch level
        case 'L1',       kf = {'PUV_raw_process','l1_qc_opts','enu_to_buoy_frame','read_VEC'};
        case 'L2',       kf = {'PUV_L2_spectral','site_grain_size','bed_stress_ks'};
        case 'L3',       kf = {'PUV_L3_transport','PUV_L3_storms','settling_velocity','rouse_number','site_grain_size'};
        case 'L4',       kf = {'PUV_L4_eta','PUV_L4_bispectra','PUV_L4_boundwave','PUV_L4_reflection'};
        case 'L4_xspec', kf = {'PUV_L4_xspec'};
        otherwise,       kf = {};
    end
end
