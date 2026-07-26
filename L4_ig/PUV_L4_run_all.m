% PUV_L4_RUN_ALL  Run L4 IG / bound-wave dynamics for all registered deployments.
%
%   Iterates over every deployment in deployment_registry, loads each
%   instrument's L1 and L2 .mat, runs PUV_L4_eta → PUV_L4_reflection →
%   PUV_L4_moments → PUV_L4_velocity_pdf → PUV_L4_boundwave →
%   PUV_L4_reflection_free, and writes one _L4.mat per instrument.
%   Already-processed instruments are skipped (idempotent).
%
%   BISPECTRA IS OFF BY DEFAULT. It is by far the slowest module (~2.3 s per
%   valid segment serial, ~0.57 s with a parallel pool), so a full-catalog batch
%   would run for hours. Records built by this script therefore carry every L4
%   sub-product EXCEPT `bispectra` until a separate pass fills it in — and the
%   script prints a loud reminder listing exactly which records it left
%   incomplete.
%
%   This omission is not free: in July 2026 the 23 pre-2023 archive records were
%   ingested through this script after the one-time bispectra backfill pass had
%   already run, so they silently lacked `bispectra` for weeks and quietly
%   excluded the whole 2014-2020 record from every catalog-wide bispectral
%   result. Set runBispectra = true, or run the backfill immediately after.
%
%   Set below:
%     runBispectra  false (default) — skip it, warn at the end
%                   true            — compute it inline, under a parallel pool
% Author: Holden Leslie-Bole, 2026

runBispectra = false;

startup_puv

if runBispectra && isempty(gcp('nocreate'))
    parpool('Processes');
end

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

fprintf('\n========================================\n');
fprintf(' PUV L4 IG / Bound-Wave Dynamics — %d deployments\n', nDeploy);
fprintf('========================================\n');

resultStatus = cell(nDeploy, 1);
resultNInstr = zeros(nDeploy, 1);
builtWithoutBisp = {};

for d = 1:nDeploy
    dName = deployNames{d};
    fprintf('\n\n=== [%d/%d] %s ===\n', d, nDeploy, dName);

    try
        configFn = registry(dName);
        cfg = configFn();
    catch ME
        fprintf('  ERROR loading config: %s\n', ME.message);
        resultStatus{d} = 'config_error';
        continue
    end

    l1Dir = fullfile(cfg.outputDir, 'L1', cfg.name);
    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~isfolder(l1Dir) || ~isfolder(l2Dir)
        fprintf('  Missing L1 or L2 directory — skipping.\n');
        resultStatus{d} = 'no_input_data';
        continue
    end

    outDir = fullfile(cfg.outputDir, 'L4', cfg.name);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    nInstr = numel(cfg.instruments);
    resultNInstr(d) = nInstr;
    nProcessed = 0;
    nSkipped   = 0;
    nFailed    = 0;

    for k = 1:nInstr
        instr = cfg.instruments(k);
        outFile = fullfile(outDir, [instr.label '_L4.mat']);

        if isfile(outFile)
            fprintf('  [%d/%d] %s — already processed, skipping\n', k, nInstr, instr.label);
            nSkipped = nSkipped + 1;
            continue
        end

        l1File = fullfile(l1Dir, [instr.label '_processed.mat']);
        l2File = fullfile(l2Dir, [instr.label '_L2.mat']);
        if ~isfile(l1File) || ~isfile(l2File)
            fprintf('  [%d/%d] %s — missing L1 or L2 file, skipping\n', k, nInstr, instr.label);
            nFailed = nFailed + 1;
            continue
        end

        fprintf('\n  [%d/%d] Processing %s — %s\n', k, nInstr, cfg.name, instr.label);

        try
            l1 = load(l1File, 'PUV');
            l2 = load(l2File, 'L2');
            PUV = l1.PUV;
            L2  = l2.L2;

            L4 = struct();
            L4.eta       = PUV_L4_eta(PUV, L2);
            L4.ref       = PUV_L4_reflection(PUV, L2, L4.eta);
            if runBispectra
                L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2, ...
                                                struct('useParallel', true));
            end
            L4.moments         = PUV_L4_moments(L2);
            L4.pdf             = PUV_L4_velocity_pdf(PUV, L2);
            L4.boundwave       = PUV_L4_boundwave(L4.eta, L2, PUV);
            L4.reflection_free = PUV_L4_reflection_free(PUV, L2, L4.eta, L4.boundwave);

            L4.label          = PUV.label;
            L4.deploymentName = PUV.deploymentName;
            L4.LATLON         = PUV.LATLON;
            L4.doffp          = PUV.doffp;
            L4.shorenormal    = L2.shorenormal;
            if isfield(L2, 'mopStation'), L4.mopStation = L2.mopStation; end
            L4.builtAt        = datetime('now');

            save(outFile, 'L4', '-v7.3');
            nProcessed = nProcessed + 1;
            if ~runBispectra
                builtWithoutBisp{end+1} = sprintf('%s/%s', cfg.name, instr.label); %#ok<SAGROW>
            end
        catch ME
            warning('PUV_L4_run_all:failed', '%s/%s: %s', dName, instr.label, ME.message);
            nFailed = nFailed + 1;
        end
    end

    resultStatus{d} = sprintf('%d ok, %d skip, %d fail', nProcessed, nSkipped, nFailed);
    fprintf('\n  Summary: %s\n', resultStatus{d});
end

%% Summary
fprintf('\n\n========================================\n');
fprintf(' L4 IG / Bound-Wave Dynamics Complete\n');
fprintf('========================================\n');
fprintf('  %-10s  %6s  %s\n', 'Deploy', 'Instr', 'Status');
fprintf('  %s\n', repmat('-', 1, 45));
for d = 1:nDeploy
    fprintf('  %-10s  %6d  %s\n', deployNames{d}, resultNInstr(d), resultStatus{d});
end
fprintf('\n');

if ~isempty(builtWithoutBisp)
    fprintf(2, '\n**********************************************************\n');
    fprintf(2, '  L4 IS INCOMPLETE: %d record(s) written WITHOUT bispectra\n', ...
        numel(builtWithoutBisp));
    fprintf(2, '**********************************************************\n');
    for i = 1:numel(builtWithoutBisp)
        fprintf(2, '    %s\n', builtWithoutBisp{i});
    end
    fprintf(2, ['\n  Until bispectra is filled in, these records are silently\n' ...
                '  excluded from every bispectral / nonlinearity analysis.\n' ...
                '  Fill them in with a pass that computes ONLY bispectra, e.g.\n\n' ...
                '    L4.bispectra = PUV_L4_bispectra(L4.eta.eta_total, L2, ...\n' ...
                '                       struct(''useParallel'', true));\n\n' ...
                '  and check the L4 grid still matches L2 first --\n' ...
                '  see shared/l4_l2_index_map.m. Then confirm with\n' ...
                '  validation/audit_L4_coverage.m\n\n']);
end
