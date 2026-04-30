% test_new_L2_fields.m
% Author: Holden Leslie-Bole, 2026
% Quick test: run L2 on one instrument and check new fields (a2, b2, Z-test, radiation stress)

cd('/Users/holden/Documents/Scripps/Research/PUV_Pipeline');
startup_puv;

loaded = load('outputs/L1/TBR23/MOP580_7m_processed.mat', 'PUV');
registry = deployment_registry();
cfg = registry('TBR23');
cfg = cfg();
instr = cfg.instruments(2);  % MOP580_7m
opts = struct();

L2 = PUV_L2_spectral(loaded.PUV, instr, opts);

v = L2.segValid;
fprintf('\n=== New L2 field validation ===\n');
fprintf('a2 size: %s\n', mat2str(size(L2.a2)));
fprintf('b2 size: %s\n', mat2str(size(L2.b2)));
fprintf('a2 range (SS band, median segment): %.3f to %.3f\n', ...
    min(median(L2.a2(:,v), 2, 'omitnan')), max(median(L2.a2(:,v), 2, 'omitnan')));
fprintf('ztest_SS: median=%.3f, range=[%.3f, %.3f]\n', ...
    median(L2.ztest_SS(v), 'omitnan'), min(L2.ztest_SS(v)), max(L2.ztest_SS(v)));
fprintf('ztest_IG: median=%.3f, range=[%.3f, %.3f]\n', ...
    median(L2.ztest_IG(v), 'omitnan'), min(L2.ztest_IG(v)), max(L2.ztest_IG(v)));
fprintf('Sxx: median=%.1f, range=[%.1f, %.1f] N/m\n', ...
    median(L2.Sxx(v), 'omitnan'), min(L2.Sxx(v)), max(L2.Sxx(v)));
fprintf('Syy: median=%.1f, range=[%.1f, %.1f] N/m\n', ...
    median(L2.Syy(v), 'omitnan'), min(L2.Syy(v)), max(L2.Syy(v)));
fprintf('Sxy: median=%.1f, range=[%.1f, %.1f] N/m\n', ...
    median(L2.Sxy(v), 'omitnan'), min(L2.Sxy(v)), max(L2.Sxy(v)));

% Sanity checks
assert(all(size(L2.a2) == size(L2.a1)), 'a2 size mismatch');
assert(all(size(L2.b2) == size(L2.b1)), 'b2 size mismatch');
assert(median(L2.ztest_SS(v), 'omitnan') > 0.5 && median(L2.ztest_SS(v), 'omitnan') < 2.0, ...
    'Z-test SS median out of expected range');
assert(all(L2.Sxx(v) > 0), 'Sxx should be positive (onshore momentum flux)');
assert(median(L2.Sxx(v), 'omitnan') > median(L2.Syy(v), 'omitnan'), ...
    'Sxx should exceed Syy for shore-normal swell');

fprintf('\nAll checks passed.\n');
