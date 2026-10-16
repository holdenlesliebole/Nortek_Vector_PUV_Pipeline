% REFRESH_L4_REFLECTION_BANDS  Refresh L4.ref with the new band-aware
% PUV_L4_reflection (adds L4ref.byBand.{IG,swell,sea}, Hs_over_h,
% saturation_flag while preserving the flat IG-only field names).
%
% No bispectra recompute — only re-runs the reflection module, which is
% fast (seconds per instrument).
%
% Idempotent skip: if L4.ref already has the byBand field, skip.
%
% Run from PUV_Pipeline/:
%   >> run scripts/refresh_L4_reflection_bands

startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n=== L4 reflection refresh: add byBand.{IG,swell,sea} ===\n');
fprintf('   %d deployments\n', nDeploy);

nOk = 0; nSkip = 0; nFail = 0; tAll = tic;

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

            if isfield(L4, 'ref') && isfield(L4.ref, 'byBand')
                fprintf('  [%d/%d] %s — byBand already present, skipping\n', k, numel(l4Files), instr);
                nSkip = nSkip + 1;
                continue
            end

            l1 = load(l1Path, 'PUV'); PUV = l1.PUV;
            l2 = load(l2Path, 'L2'); L2 = l2.L2;

            L4.ref = PUV_L4_reflection(PUV, L2, L4.eta);

            save(l4Path, 'L4', '-v7.3');

            r_ig    = median(L4.ref.byBand.IG.R2,    'omitnan');
            r_swell = median(L4.ref.byBand.swell.R2, 'omitnan');
            r_sea   = median(L4.ref.byBand.sea.R2,   'omitnan');
            satFrac = mean(L4.ref.saturation_flag,   'omitnan');
            fprintf('  [%d/%d] %s — R2 IG=%.2f swell=%.2f sea=%.2f, sat=%.0f%%, %.1f s\n', ...
                k, numel(l4Files), instr, r_ig, r_swell, r_sea, 100*satFrac, toc(t0));
            nOk = nOk + 1;
        catch ME
            fprintf('  [%d/%d] %s — FAIL: %s\n', k, numel(l4Files), instr, ME.message);
            nFail = nFail + 1;
        end
    end
end

fprintf('\nDone in %.1f min. %d refreshed, %d skipped, %d failed.\n', ...
    toc(tAll)/60, nOk, nSkip, nFail);
