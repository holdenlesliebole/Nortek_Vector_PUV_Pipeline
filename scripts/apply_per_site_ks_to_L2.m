function apply_per_site_ks_to_L2(deployment, varargin)
% APPLY_PER_SITE_KS_TO_L2  In-place L2 bed-stress patch for a deployment.
%
%   apply_per_site_ks_to_L2(deployment)
%   apply_per_site_ks_to_L2(deployment, 'force', true)
%
%   For each PUV in DEPLOYMENT whose label has a site_grain_size entry,
%   recomputes L2.tau_b, L2.fric_w, L2.Aw using bed_stress_ks with
%   ks = 2.5*D84 (per site), and stamps L2.params with the provenance
%   fields the new methodology relies on:
%       L2.params.bedstress_method      = 'bed_stress_ks'
%       L2.params.bedstress_ks_m        = ks_m
%       L2.params.bedstress_D84_m       = D84 (m)
%       L2.params.bedstress_D50_m_used  = D50 (m)
%       L2.params.bedstress_gs_status   = site_grain_size status
%
%   This is the in-place equivalent of running PUV_L2_spectral with the
%   2026-05-25 canonical patch (Paper 2 audit of bed-stress methodology;
%   Wiberg & Smith 1991 ks = 2.5*D84). It does NOT re-run MTM spectral
%   analysis — only the bed-stress block. Use it to bring legacy L2 files
%   up to the new methodology without paying the MTM cost.
%
%   For PUVs without a site_grain_size entry, the L2 file is left untouched
%   (no patch applied — keeps Shields normalization in L3 consistent).
%
%   Idempotent: a second invocation on a fully-patched deployment is a
%   no-op (skips PUVs whose bedstress_method is already 'bed_stress_ks',
%   unless 'force' is set).
%
%   Always writes a .bak_preP6 backup of each L2 file it touches.
%
%   USAGE
%       apply_per_site_ks_to_L2('TBR23');                % first run
%       apply_per_site_ks_to_L2('TBR23', 'force', true); % force-re-patch
%
%   See also: PUV_L2_spectral (canonical L2 builder with the same logic),
%             bed_stress_ks, site_grain_size, PUV_L3_transport.
%
% Author: Holden Leslie-Bole, 2026-05-25 (PUV_Pipeline canonicalization)

p = inputParser;
addParameter(p, 'force', false, @islogical);
parse(p, varargin{:});
forceFlag = p.Results.force;

% Setup
thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(thisDir);
addpath(fullfile(repoRoot, 'shared'));
addpath(fullfile(repoRoot, 'config'));

registry = deployment_registry();
if ~isKey(registry, deployment)
    error('apply_per_site_ks_to_L2:unknownDeployment', ...
        'Deployment "%s" not in registry. Available: %s', ...
        deployment, strjoin(keys(registry), ', '));
end
cfg = feval(registry(deployment));
l2Dir = fullfile(repoRoot, 'outputs', 'L2', cfg.name);
if ~isfolder(l2Dir)
    error('apply_per_site_ks_to_L2:noL2', 'L2 directory not found: %s', l2Dir);
end

rho = 1025;

fprintf('\n=== apply_per_site_ks_to_L2: %s ===\n', deployment);
fprintf('  L2 directory: %s\n\n', l2Dir);

for k = 1:numel(cfg.instruments)
    instr = cfg.instruments(k);
    l2File = fullfile(l2Dir, [instr.label '_L2.mat']);
    if ~isfile(l2File)
        fprintf('  [%d/%d] %s: no L2 file, skip\n', k, numel(cfg.instruments), instr.label);
        continue
    end

    % Check grain-size entry
    try
        gs = site_grain_size(instr.label);
    catch
        fprintf('  [%d/%d] %s: no site_grain_size entry, skip (L2 stays legacy)\n', ...
                k, numel(cfg.instruments), instr.label);
        continue
    end

    % Load + idempotency check
    S = load(l2File, 'L2');
    L2 = S.L2;
    if ~forceFlag && isfield(L2,'params') && isfield(L2.params,'bedstress_method') ...
            && strcmp(L2.params.bedstress_method, 'bed_stress_ks')
        fprintf('  [%d/%d] %s: already patched (bedstress_method=bed_stress_ks), skip\n', ...
                k, numel(cfg.instruments), instr.label);
        continue
    end

    % Backup
    bakFile = [l2File '.bak_preP6'];
    if ~isfile(bakFile), copyfile(l2File, bakFile); end

    % Patch bed-stress fields
    ks_m = 2.5 * gs.D84;
    [tau_new, fw_new, Aw_new] = bed_stress_ks(L2.Ub, L2.Tp, ks_m, rho);

    % Compare against pre-patch values for the user
    tau_old = L2.tau_b;
    valid = L2.segValid & isfinite(tau_old) & isfinite(tau_new);
    if any(valid)
        mOld = mean(tau_old(valid)); mNew = mean(tau_new(valid));
        fprintf('  [%d/%d] %s: D50=%.0f um, D84=%.0f um, ks=%.3f mm (%s)\n', ...
                k, numel(cfg.instruments), instr.label, ...
                gs.D50*1e6, gs.D84*1e6, ks_m*1e3, char(gs.status));
        fprintf('       mean tau_b: %.4f -> %.4f Pa (%.1f%% change)\n', ...
                mOld, mNew, 100*(mNew-mOld)/mOld);
    end

    L2.tau_b  = tau_new;
    L2.fric_w = fw_new;
    L2.Aw     = Aw_new;

    L2.params.bedstress_method      = 'bed_stress_ks';
    L2.params.bedstress_ks_m        = ks_m;
    L2.params.bedstress_D84_m       = gs.D84;
    L2.params.bedstress_D50_m_used  = gs.D50;
    L2.params.bedstress_gs_status   = char(gs.status);

    save(l2File, 'L2', '-v7.3');
    fprintf('       saved + backup at %s\n', bakFile);
end

fprintf('\nDone.\n');
end
