% REGEN_L3_ROUSE_2026_08_13  Rebuild L3 after the Rouse stress correction.
%
%   PUV_L3_transport was corrected on 2026-08-13. It had fed L2.tau_b, the
%   oscillatory WAVE stress amplitude 0.5*rho*f_w*Ub^2, into a Rouse number. The
%   Rouse profile assumes a steady boundary layer with diffusivity kappa*u_star*z
%   over the water column; the wave boundary layer is centimetres thick and an
%   amplitude is not a mean, so both errors inflate u_star and the old field
%   OVERSTATES suspension. Measured at MOP580_5m: corrected median Rouse 40.6
%   against a legacy 7.4, larger in 100% of segments.
%
%   THIS REGEN IS PURELY ADDITIVE. Verified across all 66 L3 files before
%   running: every field that any downstream code consumes (Fb, Fb_cum, shields,
%   mobilized, tau_b, Ub, uMean, vMean) reproduces to a worst-case relative
%   difference of 0.000e+00. Nothing that feeds a published or in-review number
%   changes. What the regen adds:
%
%       L3.rouse         now from tau_m (Soulsby 1997 wave-current mean stress)
%       L3.tau_c         current-related stress, rho*Cd*|U_mean|^2, Cd = 2.5e-3
%       L3.tau_m         mean combined stress
%       L3.tau_max       max combined stress
%
%   L3.shields and L3.mobilized are deliberately UNCHANGED and were never wrong:
%   the wave stress amplitude IS the correct quantity for a wave-mobilization
%   Shields number. Only the Rouse number needed a different stress.
%
%   BLAST RADIUS: none. An audit on 2026-08-13 found no consumer of L3.rouse
%   anywhere in the research tree; L4 pulls shields and mobilized only.
%
%   Run from PUV_Pipeline/:
%     >> run scripts/regen_L3_rouse_2026_08_13
%
% Author: Holden Leslie-Bole, 2026-08-13

startup_puv

repoRoot = fileparts(fileparts(mfilename('fullpath')));
outRoot  = fullfile(repoRoot, 'outputs');
bkRoot   = fullfile(outRoot, '_pre_rouse_backup_2026-08-13');

% Only touch registered deployments -- outputs/ can hold held-out exploratory
% runs (same guard as scripts/copy_to_server.m and the 2026-07-31 regen).
reg = deployment_registry();
regKeys = keys(reg);

files = dir(fullfile(outRoot, 'L3', '*', '*_L3.mat'));
fprintf('found %d L3 files under %d deployment folders\n', numel(files), ...
    numel(unique({files.folder})));

nDone = 0; nSkip = 0; nFail = 0;
for i = 1:numel(files)
    f3  = fullfile(files(i).folder, files(i).name);
    [~, dep] = fileparts(files(i).folder);

    if ~any(strcmp(regKeys, dep))
        fprintf('  SKIP (unregistered): %s/%s\n', dep, files(i).name);
        nSkip = nSkip + 1;
        continue
    end

    f2 = strrep(strrep(f3, [filesep 'L3' filesep], [filesep 'L2' filesep]), ...
                '_L3.mat', '_L2.mat');
    if ~isfile(f2)
        fprintf('  SKIP (no L2): %s/%s\n', dep, files(i).name);
        nSkip = nSkip + 1;
        continue
    end

    % Back up before touching anything. NEVER overwrite an existing backup: this
    % script may be run more than once (it was, on 2026-08-13, to drop the
    % rouse_legacy field), and a second copy would replace the true pre-change
    % file with an already-regenerated one and destroy the only rollback point.
    bkDir = fullfile(bkRoot, dep);
    if ~isfolder(bkDir), mkdir(bkDir); end
    bkFile = fullfile(bkDir, files(i).name);
    if ~isfile(bkFile)
        copyfile(f3, bkFile);
    end

    try
        A = load(f3); L3 = A.L3;
        B = load(f2); L2 = B.L2;

        % recompute only the transport block; bands/storms/currents untouched
        evalc('L3 = PUV_L3_transport(L3, L2);');

        save(f3, 'L3', '-v7.3');
        nDone = nDone + 1;
        fprintf('  ok: %s/%s  (median Rouse %.1f)\n', dep, files(i).name, ...
            median(L3.rouse(isfinite(L3.rouse))));
    catch err
        nFail = nFail + 1;
        fprintf('  FAIL: %s/%s -- %s\n', dep, files(i).name, err.message);
    end
end

fprintf('\nregenerated %d, skipped %d, failed %d\n', nDone, nSkip, nFail);
fprintf('backups in %s\n', bkRoot);
fprintf(['\nNEXT: push to reefbreak with scripts/copy_to_server.m once\n' ...
         '/Volumes/group is mounted. Nothing downstream needs re-running.\n']);
