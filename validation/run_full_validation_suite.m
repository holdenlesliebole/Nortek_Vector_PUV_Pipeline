% RUN_FULL_VALIDATION_SUITE  Run all validation analyses for every L2 instrument.
%
%   Runs compare_PUV_MOP, compare_PUV_MOP_spectra, and analyze_spectral_shape
%   for each instrument that has L2 output, then prints a cross-deployment
%   summary table of spectral shape metrics.
%
%   To process more deployments, first run PUV_L1_driver and PUV_L2_driver
%   for each deployment.

startup_puv

registry    = deployment_registry();
deployNames = sort(keys(registry));
nDeploy     = numel(deployNames);

toolboxPath = fullfile(getenv('HOME'), 'Documents', 'Scripps', 'Research', 'toolbox');
if ~exist('read_MOPline2', 'file')
    addpath(toolboxPath);
end

fprintf('\n================================================================\n');
fprintf(' Full Validation Suite — %d registered deployments\n', nDeploy);
fprintf('================================================================\n');

% Collect cross-deployment results
allRows = {};  % cell array of table rows

for d = 1:nDeploy
    dName = deployNames{d};
    configFn = registry(dName);

    try
        cfg = configFn();
    catch
        continue
    end

    l2Dir = fullfile(cfg.outputDir, 'L2', cfg.name);
    if ~isfolder(l2Dir)
        continue
    end

    nInstr = numel(cfg.instruments);

    for k = 1:nInstr
        instr = cfg.instruments(k);
        l2File = fullfile(l2Dir, [instr.label '_L2.mat']);
        if ~isfile(l2File), continue; end

        fprintf('\n\n============================================================\n');
        fprintf(' %s — %s\n', cfg.name, instr.label);
        fprintf('============================================================\n');

        try
            loaded = load(l2File, 'L2');
            L2 = loaded.L2;

            % Skip instruments without MOP station
            if ~isfield(L2, 'mopStation') || isempty(L2.mopStation)
                % Fallback: try to parse from label
                mopNum = regexp(L2.label, 'MOP(\d+)', 'tokens', 'once');
                if isempty(mopNum)
                    fprintf('  No MOP station — skipping validation\n');
                    continue
                end
            end

            % Run spectral shape analysis
            shapeResults = analyze_spectral_shape(L2, toolboxPath);

            % Collect summary row
            validIdx = L2.segValid;
            goodQ = ~isnan(shapeResults.seg_Qp_puv) & ~isnan(shapeResults.seg_Qp_mop);
            goodCorr = goodQ & ~isnan(shapeResults.seg_Hs_ratio);

            Qp_diff = shapeResults.seg_Qp_puv - shapeResults.seg_Qp_mop;
            if sum(goodCorr) > 20
                R = corrcoef(Qp_diff(goodCorr), shapeResults.seg_Hs_ratio(goodCorr));
                R_qp = R(1,2);
            else
                R_qp = NaN;
            end

            row = struct();
            row.deploy = cfg.name;
            row.label = instr.label;
            row.depth = shapeResults.h_puv;
            row.nValid = sum(validIdx);
            row.nTotal = length(validIdx);
            row.validPct = 100 * sum(validIdx) / length(validIdx);
            row.Qp_puv = median(shapeResults.seg_Qp_puv(goodQ));
            row.Qp_mop = median(shapeResults.seg_Qp_mop(goodQ));
            row.Qp_ratio = row.Qp_puv / row.Qp_mop;
            row.bw_puv = median(shapeResults.seg_bw_puv(goodQ));
            row.bw_mop = median(shapeResults.seg_bw_mop(goodQ));
            row.bw_narrow = 100 * (1 - row.bw_puv / row.bw_mop);
            row.peakS_ratio = median(shapeResults.seg_peakS_puv(goodQ)) / ...
                              median(shapeResults.seg_peakS_mop(goodQ));
            row.Hs_ratio = median(shapeResults.seg_Hs_ratio(goodQ));
            row.R_qp_Hs = R_qp;
            row.N = sum(goodQ);

            allRows{end+1} = row; %#ok<SAGROW>

        catch ME
            warning('Failed %s/%s: %s', cfg.name, instr.label, ME.message);
        end
    end
end

%% Cross-deployment summary
fprintf('\n\n================================================================\n');
fprintf(' CROSS-DEPLOYMENT SPECTRAL SHAPE SUMMARY\n');
fprintf('================================================================\n\n');

fprintf('  %-8s  %-14s  %5s  %5s  %5s  %6s  %6s  %6s  %5s  %6s  %5s\n', ...
    'Deploy', 'Instrument', 'Depth', 'Qp_P', 'Qp_M', 'Qp_rat', 'BW_nar', 'Pk_rat', 'Hs_r', 'R(Qp)', 'N');
fprintf('  %s\n', repmat('-', 1, 95));

for i = 1:length(allRows)
    r = allRows{i};
    fprintf('  %-8s  %-14s  %5.1f  %5.2f  %5.2f  %6.3f  %5.1f%%  %6.3f  %5.3f  %6.3f  %5d\n', ...
        r.deploy, r.label, r.depth, r.Qp_puv, r.Qp_mop, r.Qp_ratio, ...
        r.bw_narrow, r.peakS_ratio, r.Hs_ratio, r.R_qp_Hs, r.N);
end

fprintf('\n  Legend:\n');
fprintf('    Qp_P/M  = Goda peakedness (PUV/MOP)\n');
fprintf('    Qp_rat  = PUV/MOP Qp ratio (>1 = PUV more peaked)\n');
fprintf('    BW_nar  = PUV bandwidth narrowing vs MOP (%%)\n');
fprintf('    Pk_rat  = PUV/MOP peak spectral density ratio\n');
fprintf('    Hs_r    = median Hs ratio (PUV/MOP)\n');
fprintf('    R(Qp)   = correlation between dQp and Hs ratio\n');
fprintf('\n');

% Save summary to .mat
diagDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs', 'validation');
if ~exist(diagDir, 'dir'), mkdir(diagDir); end
save(fullfile(diagDir, 'cross_deployment_shape_summary.mat'), 'allRows');
fprintf('  Summary saved to %s\n', fullfile(diagDir, 'cross_deployment_shape_summary.mat'));
