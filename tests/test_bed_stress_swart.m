function test_bed_stress_swart()
%TEST_BED_STRESS_SWART  Closure test of bed_stress_ks and bed_stress against hand-derived values.
%
%   Run:  test_bed_stress_swart        (errors if any check fails; prints "n/n checks")
%
%   The expected values below were derived by hand (independently of the routines) on
%   2026-11-11 and fixed BEFORE the routines were changed. Tolerances were fixed with them:
%   relative 1e-4 on f_w, 1e-4 Pa absolute on the worked-case tau_b, relative 1e-4 on the
%   scaled r-cases. Do not widen a tolerance to let a case through.
%
%   Formula under test (Swart 1974 as in Soulsby & Whitehouse 1997, Eq. 13), with the RMS
%   speed Ub passed in and the amplitude u_br = sqrt(2)*Ub formed inside:
%       A = u_br*T/(2 pi),  r = A/ks,  f_w = min(0.3, 0.00251*exp(5.21*r^-0.19)),
%       tau_b = 0.5*rho*f_w*u_br^2.
%   Hand values of f_w: r=1 -> 0.300000 (cap), 10 -> 0.072540, 100 -> 0.022025,
%   300 -> 0.014629, 1000 -> 0.010202.
%   Worked case: Ub = 0.15 m/s, T = 11.5 s, ks = 0.00085 m, rho = 1025 kg/m^3 gives
%   u_br = 0.212132 m/s, A = 0.388261 m, r = 456.778, f_w = 0.012777, tau_b = 0.294680 Pa.
%
% Author: Holden Leslie-Bole, 2026-11-11

addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'shared'));
npass = 0; ntest = 0;
    function check(c, msg)
        ntest = ntest + 1; npass = npass + c;
        if c, fprintf('  ok    %s\n', msg); else, fprintf('  [FAIL] %s\n', msg); end
    end
rho = 1025;

% (1) f_w at five relative roughnesses. T = 2 pi s and ks = 1 m make A = sqrt(2)*Ub, so
%     Ub = r/sqrt(2) gives r exactly and u_br = r (m/s).
rr  = [1 10 100 300 1000];
fwH = [0.300000 0.072540 0.022025 0.014629 0.010202];
for k = 1:numel(rr)
    [tau, fw, Aw] = bed_stress_ks(rr(k)/sqrt(2), 2*pi, 1, rho);
    tauH = 0.5*rho*fwH(k)*rr(k)^2;
    check(abs(fw/fwH(k) - 1) < 1e-4, sprintf('f_w(r=%g) = %.6f, hand %.6f', rr(k), fw, fwH(k)));
    check(abs(tau/tauH - 1) < 1e-4 && abs(Aw/rr(k) - 1) < 1e-12, ...
        sprintf('tau_b(r=%g) = %.5g Pa, hand %.5g Pa; Aw = %.6g m (r)', rr(k), tau, tauH, Aw));
end

% (2) worked case
[tau, fw, Aw] = bed_stress_ks(0.15, 11.5, 0.00085, rho);
check(abs(Aw - 0.388261) < 1e-6,  sprintf('worked A = %.6f m, hand 0.388261', Aw));
check(abs(Aw/0.00085 - 456.778) < 1e-3, sprintf('worked r = %.3f, hand 456.778', Aw/0.00085));
check(abs(fw/0.012777 - 1) < 1e-4, sprintf('worked f_w = %.6f, hand 0.012777', fw));
check(abs(tau - 0.294680) < 1e-4, sprintf('worked tau_b = %.6f Pa, hand 0.294680', tau));

% (3) legacy routine: ks = 10*D50, so D50 = 8.5e-5 m reproduces the worked case
[tauL, fwL, AwL] = bed_stress(0.15, 11.5, 0.000085, rho);
check(abs(tauL - 0.294680) < 1e-4 && abs(fwL/0.012777 - 1) < 1e-4 && abs(AwL - 0.388261) < 1e-6, ...
    sprintf('legacy bed_stress, worked case: tau_b %.6f Pa, f_w %.6f, A %.6f m', tauL, fwL, AwL));

% (4) missing data stay missing (min(0.3, NaN) is 0.3 in MATLAB)
[tauN, fwN, AwN] = bed_stress_ks([NaN 0.15], [11.5 NaN], 0.00085, rho);
check(all(isnan(tauN)) && all(isnan(fwN)) && all(isnan(AwN)), 'NaN in Ub or T gives NaN tau_b, f_w, Aw');

fprintf('test_bed_stress_swart: %d/%d checks passed\n', npass, ntest);
if npass ~= ntest, error('test_bed_stress_swart:fail', '%d of %d checks failed', ntest - npass, ntest); end
end
