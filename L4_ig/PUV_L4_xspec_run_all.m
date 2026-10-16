% PUV_L4_XSPEC_RUN_ALL  Pairwise IG cross-spectra for all deployments.
%
%   For every deployment in deployment_registry with >=2 L4 files,
%   runs PUV_L4_xspec across all instrument pairs and writes
%   outputs/L4_xspec/{deployment}/xspec.mat. Idempotent: deployments
%   whose xspec.mat already exists are skipped.
%
%   Each xspec.mat carries provenance (shared/save_with_provenance) whose
%   parents are every member L4 file, as scripts/copy_to_server requires.
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
problems     = {};   % config errors and failed deployments, reported at the end

for d = 1:nDeploy
    dName = deployNames{d};
    fprintf('\n=== [%d/%d] %s ===\n', d, nDeploy, dName);

    try
        configFn = registry(dName);
        cfg = configFn();
    catch ME
        fprintf('  ERROR loading config: %s\n', ME.message);
        resultStatus{d} = 'config_error';
        problems{end+1} = sprintf('%s: config error: %s', dName, ME.message); %#ok<SAGROW>
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
        save_with_provenance(outFile, 'L4_xspec', 'L4xs', L4xs, ...
            struct('level', repmat({'L4'}, 1, numel(L4list)), 'path', L4list(:)'));
        resultPairs(d)  = numel(L4xs.pairs);
        resultStatus{d} = sprintf('%d pairs, %.1fs', resultPairs(d), toc(t0));
        fprintf('  %s\n', resultStatus{d});
    catch ME
        warning('PUV_L4_xspec_run_all:failed', '%s: %s', dName, ME.message);
        resultStatus{d} = sprintf('failed: %s', ME.message);
        problems{end+1} = sprintf('%s: %s', dName, ME.message); %#ok<SAGROW>
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

% Fail loudly. Every deployment and record runs inside try/catch so one failure
% cannot abort the batch, but a config that throws or a record that fails must
% not end the run looking like success (TOR18A, 2026-07-27, was invisible for a
% day this way). An error here makes `matlab -batch` exit nonzero.
if ~isempty(problems)
    error('PUV_L4_xspec_run_all:failures', '%d problem(s); details in the log above:\n  %s', ...
        numel(problems), strjoin(problems, '\n  '));
end
