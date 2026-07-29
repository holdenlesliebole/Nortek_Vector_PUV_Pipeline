% test_new_L2_fields.m
% Author: Holden Leslie-Bole, 2026
%
% Combined L2 regression check. Two parts:
%   (1) Synthetic linear closure: a known surface wave is fed through
%       PUV_L2_spectral's spectral routines; Z must return 1.0 ± 2%.
%       This catches Z-formula errors that real-data sanity checks miss
%       (see PIPELINE_NOTES.md, 2026-06-05 Z-test fix).
%   (2) Real-data sanity: run L2 on one TBR23 instrument and check that
%       the new fields (a2, b2, Z-test, radiation stress) have the right
%       shapes and physically sensible values.
% Run before any change to L2_spectral/ or any publication that cites Z.

cd(fileparts(fileparts(mfilename('fullpath'))));  % repo root
startup_puv;

%% Part 1 — synthetic closure test
fprintf('\n=== Part 1: synthetic Z closure (linear input → Z = 1) ===\n');
test_ztest_linear;
fprintf('Synthetic closure test passed.\n\n');

%% Part 2 — real-data sanity

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
