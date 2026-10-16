% REFRESH_L4_BOUNDWAVE  Add (or refresh) L4.boundwave for every existing
% L4 .mat without recomputing eta/ref/moments/pdf. Useful when the
% boundwave module is added or modified after a batch.
%
%   Run from PUV_Pipeline/:
%     >> run scripts/refresh_L4_boundwave

startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n=== Refreshing L4.boundwave across %d deployments ===\n', nDeploy);

nOk = 0; nFail = 0;

for d = 1:nDeploy
    dName = deployNames{d};
    try
        configFn = registry(dName);
        cfg = configFn();
    catch
        continue
    end
    l4Dir = fullfile(cfg.outputDir, 'L4', cfg.name);
    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~isfolder(l4Dir), continue, end
    l4Files = dir(fullfile(l4Dir, '*_L4.mat'));
    if isempty(l4Files), continue, end

    fprintf('\n[%d/%d] %s (%d files)\n', d, nDeploy, dName, numel(l4Files));

    for k = 1:numel(l4Files)
        l4Path = fullfile(l4Dir, l4Files(k).name);
        instr  = regexprep(l4Files(k).name, '_L4\.mat$', '');
        l2Path = fullfile(l2Dir, [instr '_L2.mat']);

        if ~isfile(l2Path)
            fprintf('  [%d/%d] %s — missing L2, skipping\n', k, numel(l4Files), instr);
            nFail = nFail + 1;
            continue
        end

        try
            t0 = tic;
            ld = load(l4Path, 'L4'); L4 = ld.L4;
            l2 = load(l2Path, 'L2'); L2 = l2.L2;
            L4.boundwave = PUV_L4_boundwave(L4.eta, L2);
            save(l4Path, 'L4', '-v7.3');
            mb = dir(l4Path); mb = mb.bytes/1e6;
            fprintf('  [%d/%d] %s — bound_frac=%.3f, %.1fs, %.0f MB\n', ...
                k, numel(l4Files), instr, ...
                median(L4.boundwave.bound_frac, 'omitnan'), toc(t0), mb);
            nOk = nOk + 1;
        catch ME
            fprintf('  [%d/%d] %s — FAIL: %s\n', k, numel(l4Files), instr, ME.message);
            nFail = nFail + 1;
        end
    end
end

fprintf('\nDone. %d refreshed, %d failed.\n', nOk, nFail);
