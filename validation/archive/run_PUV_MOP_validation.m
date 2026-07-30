% RUN_PUV_MOP_VALIDATION  Compare all L2 instruments against MOP wave model.
%
%   Loads each L2 output file for a deployment, runs compare_PUV_MOP,
%   and prints a summary table of comparison statistics.
%
%   To run a different deployment, change deployment_name below.
% Author: Holden Leslie-Bole, 2026

%% ======================== USER SETTINGS ========================
deployment_name = 'TBR23';

%% ======================== SETUP ========================
startup_puv

registry = deployment_registry();
if ~isKey(registry, deployment_name)
    error('Unknown deployment: %s', deployment_name);
end
configFn = registry(deployment_name);
cfg = configFn();

l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
if ~isfolder(l2Dir)
    error('L2 directory not found: %s\nRun PUV_L2_driver first.', l2Dir);
end

nInstr = numel(cfg.instruments);

fprintf('\n========================================\n');
fprintf(' PUV vs MOP Validation — %s (%d instruments)\n', deployment_name, nInstr);
fprintf('========================================\n');

%% ======================== RUN COMPARISONS ========================
allResults = cell(nInstr, 1);

for k = 1:nInstr
    instr = cfg.instruments(k);
    l2File = fullfile(l2Dir, [instr.label '_L2.mat']);

    if ~isfile(l2File)
        fprintf('\n[%d/%d] %s — no L2 file, skipping\n', k, nInstr, instr.label);
        continue
    end

    fprintf('\n[%d/%d] %s\n', k, nInstr, instr.label);

    try
        loaded = load(l2File, 'L2');
        allResults{k} = compare_PUV_MOP(loaded.L2);
    catch ME
        warning('Comparison failed for %s: %s', instr.label, ME.message);
    end
end

%% ======================== SUMMARY TABLE ========================
fprintf('\n\n========================================\n');
fprintf(' Validation Summary: %s\n', deployment_name);
fprintf('========================================\n');
fprintf('  %-14s  %6s  %6s  %7s  %6s  %6s  %7s  %6s\n', ...
    'Instrument', 'Hs_R2', 'Hs_RMS', 'Hs_bias', 'Tm_R2', 'Tm_RMS', 'Tm_bias', 'N');
fprintf('  %s\n', repmat('-', 1, 72));

for k = 1:nInstr
    instr = cfg.instruments(k);
    if isempty(allResults{k}), continue; end
    s = allResults{k}.stats;
    fprintf('  %-14s  %6.3f  %6.3f  %+7.3f  %6.3f  %6.3f  %+7.3f  %6d\n', ...
        instr.label, ...
        s.Hs.R2, s.Hs.RMSE, s.Hs.bias, ...
        s.Tm.R2, s.Tm.RMSE, s.Tm.bias, ...
        s.Hs.N);
end
fprintf('\n');
