% REFRESH_L4_BISPECTRA  Comprehensive post-batch refresh pass:
%
%   For every existing L4 .mat:
%     1. Compute L4.bispectra (dominant runtime, ~30 min/instrument)
%     2. Re-run L4.boundwave with the new (u-aware) module
%        - populates u_ig_bound, u_ig_free, var_u_ig_* fields
%        - also refreshes bound_frac_raw for any pre-existing files
%     3. Compute L4.reflection_free using the refreshed boundwave
%     4. Save once (single write per instrument)
%
%   Designed for a stable overnight run under caffeinate. Total
%   expected runtime ~21 hours for 42 instruments.
%
%   After this script completes, run PUV_L4_xspec_run_all once more with
%   opts.useFreeIG=true if you want xspec_free outputs as separate
%   deployment-level files (currently the catalog .xspec.mat is the
%   raw-IG version).
%
%   Run from PUV_Pipeline/:
%     >> run scripts/refresh_L4_bispectra

startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n=== Comprehensive L4 refresh: bispectra + boundwave(u) + reflection_free ===\n');
fprintf('   %d deployments\n', nDeploy);

nOk = 0; nFail = 0; tAll = tic;

for d = 1:nDeploy
    dName = deployNames{d};
    try
        configFn = registry(dName);
        cfg = configFn();
    catch
        continue
    end
    l1Dir = fullfile(cfg.outputDir, 'L1', cfg.name);
    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    l4Dir = fullfile(cfg.outputDir, 'L4', cfg.name);
    if ~isfolder(l4Dir), continue, end
    l4Files = dir(fullfile(l4Dir, '*_L4.mat'));
    if isempty(l4Files), continue, end

    fprintf('\n[%d/%d] %s (%d files)\n', d, nDeploy, dName, numel(l4Files));

    for k = 1:numel(l4Files)
        l4Path = fullfile(l4Dir, l4Files(k).name);
        instr  = regexprep(l4Files(k).name, '_L4\.mat$', '');
        l1Path = fullfile(l1Dir, [instr '_processed.mat']);
        l2Path = fullfile(l2Dir, [instr '_L2.mat']);

        if ~isfile(l1Path) || ~isfile(l2Path)
            fprintf('  [%d/%d] %s — missing L1/L2, skipping\n', k, numel(l4Files), instr);
            nFail = nFail + 1;
            continue
        end

        try
            t0 = tic;
            ld = load(l4Path, 'L4'); L4 = ld.L4;

            % Skip if already fully refreshed (idempotent for resume)
            alreadyDone = isfield(L4, 'bispectra') ...
                          && isfield(L4, 'boundwave') ...
                          && isfield(L4.boundwave, 'u_ig_bound') ...
                          && isfield(L4, 'reflection_free');
            if alreadyDone
                fprintf('  [%d/%d] %s — already refreshed, skipping\n', k, numel(l4Files), instr);
                continue
            end

            l1 = load(l1Path, 'PUV'); PUV = l1.PUV;
            l2 = load(l2Path, 'L2'); L2 = l2.L2;

            % 1. bispectra (slow)
            tB = tic;
            L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2);
            tBisp = toc(tB);

            % 2. boundwave (now with u side)
            L4.boundwave = PUV_L4_boundwave(L4.eta, L2, PUV);

            % 3. reflection on free residual
            L4.reflection_free = PUV_L4_reflection_free(PUV, L2, L4.eta, L4.boundwave);

            save(l4Path, 'L4', '-v7.3');
            mb = dir(l4Path); mb = mb.bytes/1e6;
            fprintf('  [%d/%d] %s — bisp %.1fmin, R2_free=%.3f, %.1f min, %.0f MB\n', ...
                k, numel(l4Files), instr, tBisp/60, ...
                median(L4.reflection_free.R2_IG, 'omitnan'), toc(t0)/60, mb);
            nOk = nOk + 1;
        catch ME
            fprintf('  [%d/%d] %s — FAIL: %s\n', k, numel(l4Files), instr, ME.message);
            nFail = nFail + 1;
        end
    end
end

fprintf('\nDone in %.1f hr. %d refreshed, %d failed.\n', toc(tAll)/3600, nOk, nFail);
