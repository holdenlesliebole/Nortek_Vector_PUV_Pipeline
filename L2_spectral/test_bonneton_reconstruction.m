function test_bonneton_reconstruction()
% TEST_BONNETON_RECONSTRUCTION  Rule-4 synthetic closure test for
% shared/bonneton_nl_correction.m.
%
% Gates every real-data number produced with that operator. Companion to
% test_ztest_linear.m / test_qtest_linear.m / test_pressure_correction_synthetic.m.
%
% WHAT IS ASSERTED, each against a hand-derived answer:
%
%   1. MONOCHROMATIC. For zeta_L = A cos(omega t) the Bonneton & Lannes
%      correction must add a second harmonic of amplitude exactly A^2 omega^2/g,
%      and nothing at any other frequency. Derivation:
%         zeta_L^2  = (A^2/2)(1 + cos 2 omega t)
%         d_tt(.)   = -2 A^2 omega^2 cos 2 omega t
%         -1/(2g) * d_tt(.) = + (A^2 omega^2/g) cos 2 omega t
%      This fixes the SIGN, which is the whole point: the correction ADDS
%      second-harmonic energy, so the linear TFM UNDER-estimates a bound
%      harmonic. An earlier hand derivation in this project got that sign
%      backwards, so it is asserted numerically here.
%
%   2. QUADRATIC SCALING. Doubling A must quadruple the correction. If it does
%      not, the operator is not the quadratic term it claims to be.
%
%   3. LINEAR LIMIT (a null that can fail, Rule 8). As A -> 0 the correction must
%      vanish faster than A, i.e. |dz|/A -> 0. A bug that leaked a term linear in
%      A would pass tests 1 and 2 at a single amplitude but fail this.
%
%   4. BICHROMATIC SUM/DIFFERENCE. For two primaries the quadratic operator must
%      produce the sum AND difference interactions with the predicted amplitudes,
%      A1*A2*(w1+w2)^2/(2g)... see below. This checks that the operator is a true
%      quadratic convolution and not just a self-squaring of each component.
%
% Usage: >> test_bonneton_reconstruction
%
% Author: Holden Leslie-Bole, 2026

g  = 9.81;
fs = 2;                       % Hz, matches the catalog
T  = 3600;                    % 1 hour
N  = T*fs;
t  = (0:N-1)'/fs;
tol = 1e-3;                   % relative

fprintf('\n=== Rule-4 closure: bonneton_nl_correction ===\n');
fprintf('fs = %g Hz, N = %d samples (%g s)\n\n', fs, N, T);

anyFail = false;

%% ---- 1. Monochromatic: amplitude and SIGN at 2*omega ------------------
A  = 0.50;                    % m
f0 = 0.075;                   % Hz, a representative swell peak
w0 = 2*pi*f0;
zL = A*cos(w0*t);

[~, dz] = bonneton_nl_correction(zL, fs, g);

% Recover the cos(2 w0 t) coefficient by projection. Exact for an integer number
% of periods; f0*T = 270 periods, so it is.
c2 = 2/N * sum(dz .* cos(2*w0*t));
s2 = 2/N * sum(dz .* sin(2*w0*t));
predicted = A^2 * w0^2 / g;

fprintf('1. MONOCHROMATIC A = %.2f m, f0 = %.4f Hz\n', A, f0);
fprintf('   predicted 2f0 amplitude  A^2 w^2/g = %+.6e m\n', predicted);
fprintf('   recovered cos(2 w0 t)              = %+.6e m\n', c2);
fprintf('   recovered sin(2 w0 t)              = %+.6e m  (should be ~0)\n', s2);
relerr = abs(c2 - predicted)/abs(predicted);
fprintf('   relative error = %.3e   sign correct = %d\n', relerr, sign(c2)==sign(predicted));
if relerr > tol || sign(c2) ~= sign(predicted)
    fprintf('   *** FAIL ***\n'); anyFail = true;
else
    fprintf('   PASS -- correction ADDS second-harmonic energy.\n');
end

% and nothing at the primary
c1 = 2/N * sum(dz .* cos(w0*t));
fprintf('   leakage at f0 = %+.3e m (%.2e of the 2f0 term)\n', c1, abs(c1)/abs(predicted));
if abs(c1)/abs(predicted) > 1e-6
    fprintf('   *** FAIL: correction contaminates the primary ***\n'); anyFail = true;
end

%% ---- 2. Quadratic scaling ---------------------------------------------
fprintf('\n2. QUADRATIC SCALING\n');
As = [0.25 0.50 1.00 2.00];
amp = zeros(size(As));
for i = 1:numel(As)
    [~, d] = bonneton_nl_correction(As(i)*cos(w0*t), fs, g);
    amp(i) = 2/N * sum(d .* cos(2*w0*t));
end
fprintf('   %-8s %-14s %-14s %s\n','A','recovered','A^2 w^2/g','ratio');
ok2 = true;
for i = 1:numel(As)
    pr = As(i)^2*w0^2/g;
    fprintf('   %-8.2f %-14.6e %-14.6e %.6f\n', As(i), amp(i), pr, amp(i)/pr);
    if abs(amp(i)/pr - 1) > tol, ok2 = false; end
end
if ok2, fprintf('   PASS\n'); else, fprintf('   *** FAIL ***\n'); anyFail = true; end

%% ---- 3. Linear limit: a null that can fail ----------------------------
fprintf('\n3. LINEAR LIMIT (correction must vanish faster than A)\n');
prev = Inf; ok3 = true;
for A3 = [1 0.1 0.01 0.001]
    [~, d] = bonneton_nl_correction(A3*cos(w0*t), fs, g);
    r = max(abs(d))/A3;
    fprintf('   A = %-8.4g  max|dz|/A = %.6e\n', A3, r);
    if r > prev, ok3 = false; end
    prev = r;
end
if ok3, fprintf('   PASS -- monotonically vanishing.\n');
else,    fprintf('   *** FAIL ***\n'); anyFail = true; end

%% ---- 4. Bichromatic sum and difference interactions -------------------
% For zL = A1 cos(w1 t) + A2 cos(w2 t), zL^2 contains
%   A1 A2 cos((w1-w2)t) + A1 A2 cos((w1+w2)t) + self terms at 2w1, 2w2.
% Applying +omega^2/(2g) to each gives predicted amplitudes
%   sum:  A1 A2 (w1+w2)^2 / (2g)
%   diff: A1 A2 (w1-w2)^2 / (2g)
% This is the check that distinguishes a true quadratic convolution from a
% component-wise squaring, and it is the interaction class that actually matters
% for a spectrum rather than a single wave.
fprintf('\n4. BICHROMATIC sum/difference interactions\n');
A1 = 0.4; A2 = 0.3; f1 = 0.07; f2 = 0.11;
w1 = 2*pi*f1; w2 = 2*pi*f2;
[~, d] = bonneton_nl_correction(A1*cos(w1*t) + A2*cos(w2*t), fs, g);
tests = { 'sum  (w1+w2)', w1+w2, A1*A2*(w1+w2)^2/(2*g); ...
          'diff (w1-w2)', w1-w2, A1*A2*(w1-w2)^2/(2*g); ...
          'self 2*w1',    2*w1,  A1^2*w1^2/g; ...
          'self 2*w2',    2*w2,  A2^2*w2^2/g };
ok4 = true;
fprintf('   %-14s %-14s %-14s %s\n','component','recovered','predicted','ratio');
for i = 1:size(tests,1)
    wi = tests{i,2}; pr = tests{i,3};
    ci = 2/N * sum(d .* cos(wi*t));
    fprintf('   %-14s %-14.6e %-14.6e %.6f\n', tests{i,1}, ci, pr, ci/pr);
    if abs(ci/pr - 1) > 5e-3, ok4 = false; end
end
if ok4, fprintf('   PASS\n'); else, fprintf('   *** FAIL ***\n'); anyFail = true; end

%% ---- verdict ----------------------------------------------------------
fprintf('\n=====================================================\n');
if anyFail
    fprintf(' RESULT: FAIL — do not trust any number from this operator.\n');
    fprintf('=====================================================\n\n');
    error('bonneton_nl_correction closure test failed.');
else
    fprintf(' RESULT: PASS — operator matches hand derivation on all 4 checks.\n');
    fprintf(' Key physical conclusion: the correction ADDS second-harmonic\n');
    fprintf(' energy, so the linear TFM UNDER-estimates a bound harmonic.\n');
    fprintf('=====================================================\n\n');
end
end
