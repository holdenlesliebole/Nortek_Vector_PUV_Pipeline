% TEST_L3_TRANSPORT_CLOSURE  Synthetic closure test for PUV_L3_transport after the
% 2026-10-09 changes: viscosity per segment from the measured temperature
% (shared/seawater_nu), Ferguson & Church natural_nominal settling velocity
% (C1 = 20, C2 = 1.1), Soulsby-Whitehouse theta_cr per segment, and per-fraction
% Rouse numbers (D16, D50, D84 from site_grain_size).
% Replaces test_l3_ws_natural_grain.m (2026-10-07), whose C2 = 1.0 and nu = 1e-6
% expectations no longer hold.
%
% Expected values written out by hand (Python, from the published formulas, NOT
% from the code under test), at S = 33.5 psu, rho = 1025, rho_s = 2650, D = 250 um:
%   nu(17 C) = 1.127822e-6 m^2/s     nu(10 C) = 1.357404e-6 m^2/s
%   ws(17 C, C1 20, C2 1.1) = 0.026475 m/s
%   D*(17 C) = 5.75943, theta_cr(17 C) = 0.043904, tau_cr(17 C) = 0.174973 Pa
%
% Criteria fixed before running (relative tolerances cover the 6-7 significant
% figures the hand values are quoted to):
%   A  Tmean [17 17 NaN 50 17]: nu, ws, theta_cr, tau_cr equal the 17 C values on
%      every valid segment (the NaN and the out-of-range 50 C fall back to the
%      record median, 17 C); T_source counts 3 segment / 2 fallback
%   B  Tmean all NaN: 17 C fallback on every segment, stated in the source string
%   C  Tmean all 10 C: nu equals nu(10 C) (temperature really is used)
%   D  ws_C1 = 20, ws_C2 = 1.1, ws_shape natural_nominal stamped
%   E  per-fraction Rouse: D_source 'measured' for MOP586_7m, rouse_D16 <
%      rouse_D50 < rouse_D84 where finite, and rouse_Dk / ws_Dk the same for
%      every fraction (Rouse is linear in ws at fixed stress)
%
% Run from PUV_Pipeline/:  >> run validation/test_L3_transport_closure

if ~exist('PUV_L3_transport', 'file'), startup_puv; end
fprintf('PUV_L3_transport under test: %s\n', which('PUV_L3_transport'));
fprintf('settling_velocity under test: %s\n', which('settling_velocity'));
fprintf('seawater_nu under test      : %s\n', which('seawater_nu'));

NU17 = 1.127822e-6; NU10 = 1.357404e-6; WS17 = 0.026475; TH17 = 0.043904; TAU17 = 0.174973;
rel = @(a, b) max(abs(a(:) - b) ./ abs(b));
pass = 0; total = 0;
function_check = @(ok, msg) fprintf('  %-66s %d\n', msg, ok);

mkL2 = @(Tmean) struct('time', datetime(2025,1,1) + hours(0:numel(Tmean)-1)', 'segValid', true(numel(Tmean),1), ...
    'depth', 7*ones(numel(Tmean),1), 'f', (0.005:0.005:0.5)', ...
    'S_eta', repmat(exp(-(((0.005:0.005:0.5)' - 0.08).^2)/(2*0.015^2))*0.5, 1, numel(Tmean)), ...
    'tau_b', 0.5*ones(numel(Tmean),1), 'Ub', 0.4*ones(numel(Tmean),1), ...
    'uMean', 0.05*ones(numel(Tmean),1), 'vMean', 0.10*ones(numel(Tmean),1), 'Tmean', Tmean(:), ...
    'label', 'MOP586_7m', 'params', struct('D50', 250e-6, 'bedstress_method', 'bed_stress_legacy'));

% ---- A ----
L3 = PUV_L3_transport(struct(), mkL2([17 17 NaN 50 17]), struct('Tvalid', [9 26]));
tp = L3.transport_params;
total = total + 1; ok = rel(L3.nu, NU17) < 1e-6; pass = pass + ok; function_check(ok, sprintf('A nu = nu(17 C) on all 5 segs (max rel %.1e)', rel(L3.nu, NU17)));
total = total + 1; ok = rel(L3.ws, WS17) < 2e-5; pass = pass + ok; function_check(ok, sprintf('A ws = %.6f (hand %.6f, max rel %.1e)', L3.ws(1), WS17, rel(L3.ws, WS17)));
total = total + 1; ok = rel(L3.theta_cr, TH17) < 2e-5; pass = pass + ok; function_check(ok, sprintf('A theta_cr = %.6f (hand %.6f)', L3.theta_cr(1), TH17));
total = total + 1; ok = rel(L3.tau_cr, TAU17) < 2e-5; pass = pass + ok; function_check(ok, sprintf('A tau_cr = %.6f Pa (hand %.6f)', L3.tau_cr(1), TAU17));
total = total + 1; ok = tp.T_source.segment_Tmean == 3 && tp.T_source.record_fallback == 2 && tp.T_source.record_fallback_value == 17;
pass = pass + ok; function_check(ok, sprintf('A T_source: %d segment, %d fallback at %g C', tp.T_source.segment_Tmean, tp.T_source.record_fallback, tp.T_source.record_fallback_value));

% ---- B ----
LB = PUV_L3_transport(struct(), mkL2([NaN NaN NaN]));
total = total + 1; ok = rel(LB.nu, NU17) < 1e-6 && contains(LB.transport_params.T_source.record_fallback_source, '17 C') ...
    && LB.transport_params.T_source.record_fallback == 3;
pass = pass + ok; function_check(ok, sprintf('B no usable T: 17 C fallback on 3/3 ("%s")', LB.transport_params.T_source.record_fallback_source));

% ---- C ----
LC = PUV_L3_transport(struct(), mkL2([10 10 10]));
total = total + 1; ok = rel(LC.nu, NU10) < 1e-6; pass = pass + ok; function_check(ok, sprintf('C nu = nu(10 C) (%.6e, hand %.6e)', LC.nu(1), NU10));

% ---- D ----
total = total + 1; ok = tp.ws_C1 == 20 && tp.ws_C2 == 1.1 && strcmp(tp.ws_shape, 'natural_nominal');
pass = pass + ok; function_check(ok, sprintf('D constants stamped: C1 %g, C2 %g, %s', tp.ws_C1, tp.ws_C2, tp.ws_shape));

% ---- E ----
r = [L3.rouse_D16 L3.rouse_D50 L3.rouse_D84]; fin = all(isfinite(r), 2);
gsE = site_grain_size('MOP586_7m');
wsF = [settling_velocity(gsE.D16, 2650, 1025, L3.nu(1)), settling_velocity(gsE.D50, 2650, 1025, L3.nu(1)), ...
       settling_velocity(gsE.D84, 2650, 1025, L3.nu(1))];
ratio = r(find(fin, 1), :) ./ wsF;
total = total + 1; ok = strcmp(tp.D_source, 'measured') && any(fin) && all(r(fin,1) < r(fin,2) & r(fin,2) < r(fin,3)) ...
    && max(abs(ratio - ratio(1))) / ratio(1) < 1e-12;
pass = pass + ok; function_check(ok, sprintf('E per-fraction Rouse ordered, linear in ws (spread %.1e), D_source %s', ...
    max(abs(ratio - ratio(1))) / ratio(1), tp.D_source));

fprintf('\n=== L3 transport closure: %d/%d checks as required\n', pass, total);
if pass ~= total, error('test_L3_transport_closure:failed', 'L3 transport closure FAILED (%d/%d)', pass, total); end
fprintf('  PASS\n');
