% PUV_L4_XSPEC_RUN_ALL  Pairwise IG cross-spectra for all deployments.
%
%   For every deployment in deployment_registry with >=2 L4 files,
%   runs PUV_L4_xspec across all instrument pairs and writes
%   outputs/L4_xspec/{deployment}/xspec.mat. Idempotent: deployments
%   whose xspec.mat already exists are skipped.
% Author: Holden Leslie-Bole, 2026

startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n========================================\n');
fprintf(' PUV L4 cross-spectra — %d deployments\n', nDeploy);
fprintf('========================================\n');

resultStatus = cell(nDeploy, 1);
resultPairs  = zeros(nDeploy, 1);

for d = 1:nDeploy
    dName = deployNames{d};
    fprintf('\n=== [%d/%d] %s ===\n', d, nDeploy, dName);

    try
        configFn = registry(dName);
        cfg = configFn();
    catch ME
        fprintf('  ERROR loading config: %s\n', ME.message);
        resultStatus{d} = 'config_error';
        continue
    end

    l4Dir = fullfile(cfg.outputDir, 'L4', cfg.name);
    if ~isfolder(l4Dir)
        fprintf('  No L4 directory — skipping.\n');
        resultStatus{d} = 'no_L4';
        continue
    end

    l4Files = dir(fullfile(l4Dir, '*_L4.mat'));
    if numel(l4Files) < 2
        fprintf('  Only %d L4 file(s) — need >=2; skipping.\n', numel(l4Files));
        resultStatus{d} = 'too_few_L4';
        continue
    end

    outDir  = fullfile(cfg.outputDir, 'L4_xspec', cfg.name);
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    outFile = fullfile(outDir, 'xspec.mat');
    if isfile(outFile)
        fprintf('  xspec.mat already exists — skipping.\n');
        resultStatus{d} = 'already_done';
        continue
    end

    L4list = cell(numel(l4Files), 1);
    for k = 1:numel(l4Files)
        L4list{k} = fullfile(l4Dir, l4Files(k).name);
    end

    try
        t0   = tic;
        L4xs = PUV_L4_xspec(L4list);
        save(outFile, 'L4xs', '-v7.3');
        resultPairs(d)  = numel(L4xs.pairs);
        resultStatus{d} = sprintf('%d pairs, %.1fs', resultPairs(d), toc(t0));
        fprintf('  %s\n', resultStatus{d});
    catch ME
        warning('PUV_L4_xspec_run_all:failed', '%s: %s', dName, ME.message);
        resultStatus{d} = sprintf('failed: %s', ME.message);
    end
end

%% Summary
fprintf('\n\n========================================\n');
fprintf(' L4 cross-spectra complete\n');
fprintf('========================================\n');
fprintf('  %-12s  %6s  %s\n', 'Deploy', 'Pairs', 'Status');
fprintf('  %s\n', repmat('-', 1, 50));
for d = 1:nDeploy
    fprintf('  %-12s  %6d  %s\n', deployNames{d}, resultPairs(d), resultStatus{d});
end
fprintf('\n');
