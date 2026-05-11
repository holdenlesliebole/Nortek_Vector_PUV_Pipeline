% PUV_L4_XSPEC_DRIVER  Pairwise IG cross-spectra for one deployment.
%
%   Loads every L4 .mat in outputs/L4/{deployment}/ for the deployment
%   specified below, runs PUV_L4_xspec across all instrument pairs, and
%   saves outputs/L4_xspec/{deployment}/xspec.mat (one struct per
%   deployment).
%
%   To process a different deployment, change deployment_name below.
% Author: Holden Leslie-Bole, 2026

%% ======================== USER SETTINGS ========================
deployment_name = 'TBR23';

% Per-module option overrides. Leave struct empty for module defaults.
xspecOpts = struct();

%% ======================== SETUP ========================
startup_puv

registry = deployment_registry();
if ~isKey(registry, deployment_name)
    error('PUV_L4_xspec_driver:unknownDeployment', ...
        'Deployment "%s" not found in registry. Available: %s', ...
        deployment_name, strjoin(keys(registry), ', '));
end
configFn = registry(deployment_name);
cfg      = configFn();

l4Dir = fullfile(cfg.outputDir, 'L4', cfg.name);
if ~isfolder(l4Dir)
    error('PUV_L4_xspec_driver:noL4', ...
        'L4 directory not found: %s\nRun PUV_L4_driver first.', l4Dir);
end

outDir = fullfile(cfg.outputDir, 'L4_xspec', cfg.name);
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% ======================== LOAD L4 FILES ========================
l4Files = dir(fullfile(l4Dir, '*_L4.mat'));
if numel(l4Files) < 2
    error('PUV_L4_xspec_driver:tooFewL4', ...
        'Need >=2 L4 files in %s; found %d.', l4Dir, numel(l4Files));
end

fprintf('\n=== L4 cross-spectra: %s (%d instruments → %d pairs) ===\n', ...
        deployment_name, numel(l4Files), nchoosek(numel(l4Files), 2));

L4list = cell(numel(l4Files), 1);
for k = 1:numel(l4Files)
    fname = fullfile(l4Dir, l4Files(k).name);
    fprintf('  Loading %s\n', l4Files(k).name);
    L4list{k} = fname;
end

%% ======================== RUN ========================
t0   = tic;
L4xs = PUV_L4_xspec(L4list, xspecOpts);
fprintf('\nDone in %.1f s. %d pairs, %d IG-band freq bins.\n', ...
        toc(t0), numel(L4xs.pairs), numel(L4xs.fIG));

%% ======================== SAVE ========================
outFile = fullfile(outDir, 'xspec.mat');
save(outFile, 'L4xs', '-v7.3');
fprintf('Saved: %s\n', outFile);

%% ======================== SUMMARY ========================
fprintf('\n  %-30s  %-10s  %-10s  %-8s  %-8s\n', ...
        'pair', 'sep_along', 'sep_cross', 'nMatch', 'mean_coh2');
fprintf('  %s\n', repmat('-', 1, 75));
for p = 1:numel(L4xs.pairs)
    pp = L4xs.pairs(p);
    fprintf('  %-30s  %10.1f  %10.1f  %8d  %8.3f\n', ...
            sprintf('%s — %s', pp.labels{1}, pp.labels{2}), ...
            pp.sep_alongshore, pp.sep_crossshore, ...
            pp.nMatched, pp.mean_coh2_IG);
end
fprintf('\n');
