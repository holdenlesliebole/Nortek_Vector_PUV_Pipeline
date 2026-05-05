function summary = run_phase2_all_deployments(opts)
% RUN_PHASE2_ALL_DEPLOYMENTS  Run Tests 1-4 across every deployment with
% L2 outputs. Per-deployment figures are written by each test function;
% numerical results are saved to outputs/validation/mean_flow/<dep>/phase2_results.mat
% for cross-deployment aggregation.
%
%   summary = run_phase2_all_deployments()
%
% Skips Test 2 for single-instrument deployments. Skips deployments with
% no L2 outputs. LPL (lagoon) and SIO Pier (amplification anomaly) are
% included but will likely show different patterns — expected.
% Author: Holden Leslie-Bole, 2026

if nargin < 1, opts = struct(); end
thisDir = fileparts(mfilename('fullpath'));
pipelineRoot = fileparts(thisDir);
if ~isfield(opts, 'L2dir'),    opts.L2dir    = fullfile(pipelineRoot,'outputs','L2'); end
% figRoot determines where per-deployment figures go and where the
% aggregate summary is saved. Override to compare segmentations side-by-side
% without overwriting the 17-min outputs.
if ~isfield(opts, 'figRoot'),  opts.figRoot  = fullfile(pipelineRoot,'outputs','validation','mean_flow'); end
if ~isfield(opts, 'summaryName'), opts.summaryName = 'phase2_summary.mat'; end

reg = deployment_registry();
deployments = keys(reg);
deployments = deployments(:);  % column

summary = struct();
summary.deployment = {};
summary.label      = {};
summary.h_med      = [];
summary.alpha      = [];      summary.alpha_lo  = [];   summary.alpha_hi  = [];
summary.beta       = [];      summary.beta_lo   = [];   summary.beta_hi   = [];
summary.R2_Hs2     = [];
summary.alpha_th   = [];
summary.modAmp_low  = [];
summary.modAmp_mid  = [];
summary.modAmp_high = [];
summary.R_uMean_uw = [];
summary.N_segs     = [];

for iD = 1:numel(deployments)
    dep = deployments{iD};
    depDir = fullfile(opts.L2dir, dep);
    if ~isfolder(depDir), continue; end

    % Get instruments from config and intersect with files on disk
    try
        configFn = reg(dep);
        cfg = configFn();
        cfgLabels = {cfg.instruments.label};
    catch
        cfgLabels = {};
    end
    files = dir(fullfile(depDir, '*_L2.mat'));
    files = files(~contains({files.name}, '.bak'));
    fileLabels = cellfun(@(s) regexprep(s, '_L2\.mat$',''), {files.name}, 'UniformOutput', false);
    if isempty(cfgLabels)
        labels = fileLabels;
    else
        labels = intersect(cfgLabels, fileLabels, 'stable');
    end
    if isempty(labels)
        fprintf('=== %s — no L2 instruments, skipping ===\n', dep);
        continue
    end

    fprintf('\n========== %s (%d instrument%s) ==========\n', ...
        dep, numel(labels), plural(numel(labels)));

    res = struct();
    perDepOpts = struct('L2dir', opts.L2dir, 'figDir', fullfile(opts.figRoot, dep));
    try
        res.test1 = test1_Hs2_scaling(dep, labels, perDepOpts);
    catch ME
        warning('run_phase2:test1Failed', 'test1 fail: %s', ME.message);
        res.test1 = [];
    end
    try
        res.test3 = test3_tidal_modulation(dep, labels, perDepOpts);
    catch ME
        warning('run_phase2:test3Failed', 'test3 fail: %s', ME.message);
        res.test3 = [];
    end
    try
        res.test4 = test4_reynolds_consistency(dep, labels, perDepOpts);
    catch ME
        warning('run_phase2:test4Failed', 'test4 fail: %s', ME.message);
        res.test4 = [];
    end
    if numel(labels) >= 2
        try
            res.test2 = test2_cross_instrument(dep, labels, perDepOpts);
        catch ME
            warning('run_phase2:test2Failed', 'test2 fail: %s', ME.message);
            res.test2 = [];
        end
    else
        res.test2 = [];
    end
    res.labels = labels;

    outDir = fullfile(opts.figRoot, dep);
    if ~exist(outDir,'dir'), mkdir(outDir); end
    save(fullfile(outDir, 'phase2_results.mat'), 'res');

    % Append per-instrument rows to summary
    for iI = 1:numel(labels)
        lab = labels{iI};
        fld = matlab.lang.makeValidName(lab);
        summary.deployment{end+1} = dep;
        summary.label{end+1} = lab;
        if ~isempty(res.test1) && isfield(res.test1, fld)
            r = res.test1.(fld);
            summary.h_med(end+1)    = r.h_med;
            summary.alpha(end+1)    = r.alpha;
            summary.alpha_lo(end+1) = r.alpha_CI(1);
            summary.alpha_hi(end+1) = r.alpha_CI(2);
            summary.beta(end+1)     = r.beta;
            summary.beta_lo(end+1)  = r.beta_CI(1);
            summary.beta_hi(end+1)  = r.beta_CI(2);
            summary.R2_Hs2(end+1)   = r.R2;
            summary.alpha_th(end+1) = r.alpha_theory;
            summary.N_segs(end+1)   = r.N;
        else
            for f = {'h_med','alpha','alpha_lo','alpha_hi','beta','beta_lo','beta_hi','R2_Hs2','alpha_th','N_segs'}
                summary.(f{1})(end+1) = NaN;
            end
        end
        if ~isempty(res.test3) && isfield(res.test3, fld)
            r = res.test3.(fld);
            summary.modAmp_low(end+1)  = r.bin(1).modAmp;
            summary.modAmp_mid(end+1)  = r.bin(2).modAmp;
            summary.modAmp_high(end+1) = r.bin(3).modAmp;
        else
            summary.modAmp_low(end+1)  = NaN;
            summary.modAmp_mid(end+1)  = NaN;
            summary.modAmp_high(end+1) = NaN;
        end
        if ~isempty(res.test4) && isfield(res.test4, fld)
            r = res.test4.(fld);
            summary.R_uMean_uw(end+1) = r.R_uMean_uw;
        else
            summary.R_uMean_uw(end+1) = NaN;
        end
    end
end

% Save aggregate summary
aggDir = fullfile(opts.figRoot,'_aggregate');
if ~exist(aggDir,'dir'), mkdir(aggDir); end
save(fullfile(aggDir, opts.summaryName), 'summary');

fprintf('\n=== Phase 2 done. %d instruments across %d deployments. ===\n', ...
    numel(summary.label), numel(unique(summary.deployment)));
fprintf('Aggregate summary: %s\n', fullfile(aggDir, 'phase2_summary.mat'));
end


function s = plural(n)
if n == 1, s = ''; else, s = 's'; end
end
