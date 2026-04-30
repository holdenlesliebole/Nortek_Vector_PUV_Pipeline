% rerun_validation_mtm.m
% Author: Holden Leslie-Bole, 2026
% Reprocess TBR23 MOP580_7m with full multi-taper, then run MOP validation.
% Compares hypothesis results between Welch and MTM full.

cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

%% Step 1: Load L1 and reprocess with full MTM
fprintf('\n=== Reprocessing TBR23 MOP580_7m with full multi-taper ===\n');
loaded = load('outputs/L1/TBR23/MOP580_7m_processed.mat', 'PUV');
registry = deployment_registry();
cfg = registry('TBR23');
cfg = cfg();
instr = cfg.instruments(2);  % MOP580_7m

opts = struct();
opts.spectralMethod = 'mtm_full';
opts.NW = 4;
opts.nfft = 2048;

L2_mtm = PUV_L2_spectral(loaded.PUV, instr, opts);

% Save temporarily for validation scripts
outFile = 'outputs/L2/TBR23/MOP580_7m_L2_mtm.mat';
L2 = L2_mtm;
save(outFile, 'L2', '-v7.3');
fprintf('Saved MTM L2 to %s\n', outFile);

%% Step 2: Also load the Welch version for side-by-side
L2_welch = load('outputs/L2/TBR23/MOP580_7m_L2.mat', 'L2').L2;

%% Step 3: Run bound wave analysis on both
fprintf('\n=== Bound wave analysis: Welch ===\n');
results_welch = analyze_bound_waves(L2_welch);

fprintf('\n=== Bound wave analysis: MTM full ===\n');
results_mtm = analyze_bound_waves(L2_mtm);

%% Step 4: Run spectral shape analysis on both
fprintf('\n=== Spectral shape analysis: Welch ===\n');
shape_welch = analyze_spectral_shape(L2_welch);

fprintf('\n=== Spectral shape analysis: MTM full ===\n');
shape_mtm = analyze_spectral_shape(L2_mtm);

%% Step 5: Run directional spread comparison on both
fprintf('\n=== Directional spread: Welch ===\n');
spread_welch = compare_directional_spread(L2_welch);

fprintf('\n=== Directional spread: MTM full ===\n');
spread_mtm = compare_directional_spread(L2_mtm);

%% Step 6: Print side-by-side hypothesis summary
fprintf('\n\n');
fprintf('=====================================================================\n');
fprintf(' HYPOTHESIS TEST COMPARISON: Welch vs Full Multi-Taper\n');
fprintf(' TBR23 MOP580_7m (8.3 m depth)\n');
fprintf('=====================================================================\n\n');

fprintf('%-40s  %12s  %12s\n', 'Metric', 'Welch', 'MTM Full');
fprintf('%s\n', repmat('-', 1, 66));

% Bulk params
v_w = L2_welch.segValid;
v_m = L2_mtm.segValid;
fprintf('%-40s  %12.3f  %12.3f\n', 'Median Hs (m)', ...
    median(L2_welch.Hs(v_w), 'omitnan'), median(L2_mtm.Hs(v_m), 'omitnan'));
fprintf('%-40s  %12.2f  %12.2f\n', 'Median Tp (s)', ...
    median(L2_welch.Tp(v_w), 'omitnan'), median(L2_mtm.Tp(v_m), 'omitnan'));

% Spectral shape: Qp
goodQ_w = ~isnan(shape_welch.seg_Qp_puv) & ~isnan(shape_welch.seg_Qp_mop);
goodQ_m = ~isnan(shape_mtm.seg_Qp_puv) & ~isnan(shape_mtm.seg_Qp_mop);

fprintf('%-40s  %12.2f  %12.2f\n', 'Median Qp (PUV)', ...
    median(shape_welch.seg_Qp_puv(goodQ_w)), median(shape_mtm.seg_Qp_puv(goodQ_m)));
fprintf('%-40s  %12.2f  %12.2f\n', 'Median Qp (MOP)', ...
    median(shape_welch.seg_Qp_mop(goodQ_w)), median(shape_mtm.seg_Qp_mop(goodQ_m)));
fprintf('%-40s  %12.2f  %12.2f\n', 'Median Qp ratio (PUV/MOP)', ...
    median(shape_welch.seg_Qp_puv(goodQ_w)) / median(shape_welch.seg_Qp_mop(goodQ_w)), ...
    median(shape_mtm.seg_Qp_puv(goodQ_m)) / median(shape_mtm.seg_Qp_mop(goodQ_m)));

% H4 correlation: dQp vs Hs ratio
goodCorr_w = goodQ_w & ~isnan(shape_welch.seg_Hs_ratio);
goodCorr_m = goodQ_m & ~isnan(shape_mtm.seg_Hs_ratio);

dQp_w = shape_welch.seg_Qp_puv(goodCorr_w) - shape_welch.seg_Qp_mop(goodCorr_w);
R_w = corrcoef(dQp_w, shape_welch.seg_Hs_ratio(goodCorr_w));

dQp_m = shape_mtm.seg_Qp_puv(goodCorr_m) - shape_mtm.seg_Qp_mop(goodCorr_m);
R_m = corrcoef(dQp_m, shape_mtm.seg_Hs_ratio(goodCorr_m));

fprintf('\n%-40s  %12.3f  %12.3f\n', 'H4: R(dQp, Hs ratio)', R_w(1,2), R_m(1,2));
fprintf('%-40s  %12.3f  %12.3f\n', 'H4: R^2', R_w(1,2)^2, R_m(1,2)^2);

% H3: bound wave scaling
fprintf('\n%-40s  %12.3f  %12.3f\n', 'H3: Low-swell median ratio (PUV/MOP)', ...
    median(results_welch.seg_ratio_lowSW, 'omitnan'), ...
    median(results_mtm.seg_ratio_lowSW, 'omitnan'));

% Directional spread
fprintf('\n%-40s  %12.1f  %12.1f\n', 'Median PUV spread (deg)', ...
    median(spread_welch.hourly_puv_spread, 'omitnan'), ...
    median(spread_mtm.hourly_puv_spread, 'omitnan'));
fprintf('%-40s  %12.1f  %12.1f\n', 'Median MOP spread (deg)', ...
    median(spread_welch.hourly_mop_spread, 'omitnan'), ...
    median(spread_mtm.hourly_mop_spread, 'omitnan'));

% Radiation stress
fprintf('\n%-40s  %12.1f  %12.1f\n', 'Median Sxx (N/m)', ...
    median(L2_welch.Sxx(v_w), 'omitnan'), median(L2_mtm.Sxx(v_m), 'omitnan'));

fprintf('\n');

% Clean up temp file
delete(outFile);
fprintf('Cleaned up temporary MTM L2 file.\n');
fprintf('\nDone.\n');
