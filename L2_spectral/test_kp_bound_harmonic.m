function test_kp_bound_harmonic()
% TEST_KP_BOUND_HARMONIC  Rule-4 synthetic closure test for the z^2 bound-harmonic
% diagnostic and for the bound-fraction inversion.
%
% GATES the beta result in
% PUV_paper/docs/findings_bound_harmonic_ztest_2026-07-29.md, which currently
% rests on a hand derivation plus real data with no known-answer check.
%
% THE PHYSICS BEING TESTED. For any irrotational component of frequency sigma and
% wavenumber kappa, Laplace plus the bottom boundary condition force the potential
% to be phi = A cosh(kappa(z+h)) cos(kappa x - sigma t), whatever the surface
% condition. Hence at a sensor at elevation d,
%
%   p_dyn/(rho g) = (sigma A/g) cosh(kappa d) sin(sigma t)
%   u             = A kappa     cosh(kappa d) sin(sigma t)
%   => S_uu/S_pp  = (g kappa / sigma)^2      [no assumption linking phi to eta]
%
% The pipeline forms Spp_from_vel = (Suu+Svv)*(sigma/(g k_a))^2 using the FREE
% wavenumber k_a (PUV_L2_spectral.m:556-566), so its ztest returns
%
%   z^2 = (k_a / kappa)^2
%
% Unity for a free wave; ABOVE unity for a bound harmonic, whose kappa = 2 k0 is
% smaller than k_a = k_free(2 f0). An earlier derivation in this project gave
% z^2 = [tanh(2k0 h)/tanh(k_a h)]^2 < 1 -- wrong in sign AND magnitude, because it
% used u = sigma*eta*cosh(kappa d)/sinh(kappa h), which encodes the free-wave
% eta<->A relation that a bound wave does not satisfy. This test pins the sign.
%
% WHAT IS ASSERTED
%   1. FREE primary at f0            -> z^2 = 1
%   2. FREE component at 2 f0        -> z^2 = 1        (null that can fail)
%   3. BOUND-kinematics at 2 f0      -> z^2 = (k_a/2k0)^2, the analytic value
%   4. MIXTURE of bound and free     -> the inversion recovers the input fraction
%
% Test 4 is the load-bearing one. The mixture is RECIPROCAL, not linear: since
% each component contributes Spp_j and Spp_j*(kappa_j/k_a)^2, a band containing
% pressure-energy fraction E_b of bound and (1-E_b) of free returns
%
%   z^2_band = 1 / [ E_b/z^2_pred + (1-E_b) ]
%   => E_b   = (1 - 1/z^2_band) / (1 - 1/z^2_pred)
%
% Using the linear form 1 + beta*(z^2_pred - 1) instead UNDER-estimates the bound
% fraction by roughly 30-50% at these values, which is why this test exists.
%
% Usage: >> test_kp_bound_harmonic
%
% Author: Holden Leslie-Bole, 2026

g   = 9.81;
fs  = 2;
T   = 3600;
N   = T*fs;
t   = (0:N-1)'/fs;
h   = 8.0;                 % depth (m)
d   = 0.60;                % sensor elevation above bed (m)
f0  = 0.075;               % primary (Hz)
tol = 2e-3;

w0  = 2*pi*f0;
k0  = ndisp(w0,   h, g);
ka  = ndisp(2*w0, h, g);   % FREE wavenumber at the harmonic frequency
kb  = 2*k0;                % BOUND harmonic wavenumber
z2pred = (ka/kb)^2;

fprintf('\n=== Rule-4 closure: z^2 bound-harmonic diagnostic ===\n');
fprintf('h = %.1f m, d = %.2f m, f0 = %.4f Hz, fs = %g Hz, N = %d\n', h, d, f0, fs, N);
fprintf('k0*h = %.4f,  2k0*h = %.4f,  k_free(2f0)*h = %.4f\n', k0*h, kb*h, ka*h);
fprintf('predicted z^2 for a fully bound harmonic = (k_a/2k0)^2 = %.6f\n\n', z2pred);

anyFail = false;

%% ---- 1-3: single components ------------------------------------------
cases = { 'free primary  @ f0',   w0,    k0, 1.0; ...
          'free          @ 2f0',  2*w0,  ka, 1.0; ...
          'BOUND         @ 2f0',  2*w0,  kb, z2pred };
fprintf('%-22s %-12s %-12s %s\n','case','z^2 measured','z^2 expected','ratio');
for i = 1:size(cases,1)
    sig = cases{i,2}; kap = cases{i,3}; exp_ = cases{i,4};
    ap  = 0.30;                                   % pressure amplitude (m of water)
    p   = ap * sin(sig*t);
    u   = ap * (g*kap/sig) * sin(sig*t);
    z2  = ztest_at(p, u, zeros(N,1), fs, sig/(2*pi), h, g);
    fprintf('%-22s %-12.6f %-12.6f %.6f\n', cases{i,1}, z2, exp_, z2/exp_);
    if abs(z2/exp_ - 1) > tol
        fprintf('   *** FAIL ***\n'); anyFail = true;
    end
end

%% ---- 4: mixture, and the inversion -----------------------------------
% Put the bound and free parts at ADJACENT frequencies inside the harmonic band so
% they are spectrally separable rather than interfering at one frequency.
fprintf('\nMIXTURE: recover the input bound fraction\n');
fprintf('%-10s %-12s %-12s %-12s %-12s\n', ...
        'E_b in','z^2 band','E_b recip','E_b linear','recip err');
okMix = true;
for Eb = [0.0 0.05 0.125 0.25 0.50 1.0]
    fh   = 2*f0;
    fh2  = 2*f0 + 0.006;                          % separable neighbour
    apb  = sqrt(Eb);
    apf  = sqrt(1-Eb);
    sig1 = 2*pi*fh; sig2 = 2*pi*fh2;
    kb1  = kb;                       kf2 = ndisp(sig2, h, g);
    p    = apb*sin(sig1*t)                    + apf*sin(sig2*t);
    u    = apb*(g*kb1/sig1)*sin(sig1*t)       + apf*(g*kf2/sig2)*sin(sig2*t);
    % band-integrated z^2 across both components
    z2b  = ztest_band(p, u, zeros(N,1), fs, [fh-0.004 fh2+0.004], h, g);
    EbR  = (1 - 1/z2b) / (1 - 1/z2pred);          % correct, reciprocal
    EbL  = (z2b - 1)   / (z2pred - 1);            % the linear approximation
    fprintf('%-10.3f %-12.6f %-12.6f %-12.6f %+.4f\n', Eb, z2b, EbR, EbL, EbR-Eb);
    if abs(EbR - Eb) > 0.02, okMix = false; end
end
if okMix
    fprintf('PASS -- reciprocal inversion recovers E_b to within 0.02.\n');
else
    fprintf('*** FAIL: inversion does not recover the input fraction ***\n');
    anyFail = true;
end
fprintf('\nNote how the LINEAR column sits below the input: using it under-states\n');
fprintf('the bound fraction. Use the reciprocal form.\n');

%% ---- verdict ---------------------------------------------------------
fprintf('\n=====================================================\n');
if anyFail
    fprintf(' RESULT: FAIL — the z^2 diagnostic or its inversion is wrong.\n');
    fprintf('=====================================================\n\n');
    error('test_kp_bound_harmonic failed.');
else
    fprintf(' RESULT: PASS — z^2 = (k_a/kappa)^2 confirmed, above unity for a\n');
    fprintf(' bound harmonic, and the reciprocal inversion recovers E_b.\n');
    fprintf('=====================================================\n\n');
end
end

%% ---- helpers ---------------------------------------------------------
function k = ndisp(w, h, g)
    k = w^2/g;
    for ii = 1:200, k = w^2/(g*tanh(k*h)); end
end

function z2 = ztest_at(p, u, v, fs, fEval, h, g)
    [z2f, ff] = ztest_spec(p, u, v, fs, h, g);
    [~, i0] = min(abs(ff - fEval));
    z2 = z2f(i0);
end

function z2 = ztest_band(p, u, v, fs, band, h, g)
    [Spp, Spv, ff] = ztest_parts(p, u, v, fs, h, g);
    b = ff >= band(1) & ff <= band(2);
    z2 = sum(Spp(b)) / sum(Spv(b));
end

function [z2f, ff] = ztest_spec(p, u, v, fs, h, g)
    [Spp, Spv, ff] = ztest_parts(p, u, v, fs, h, g);
    z2f = Spp ./ max(Spv, eps);
end

function [Spp, Spv, ff] = ztest_parts(p, u, v, fs, h, g)
    nfft = 2^nextpow2(numel(p)/4);
    [Spp, ff] = pwelch(p, hanning(nfft), nfft/2, nfft, fs);
    Suu       = pwelch(u, hanning(nfft), nfft/2, nfft, fs);
    Svv       = pwelch(v, hanning(nfft), nfft/2, nfft, fs);
    % exactly the pipeline's form, PUV_L2_spectral.m:556-566
    kf = zeros(numel(ff),1);
    for ii = 2:numel(ff), kf(ii) = ndisp(2*pi*ff(ii), h, g); end
    u2p = zeros(numel(ff),1);
    u2p(2:end) = (2*pi*ff(2:end)) ./ (g * kf(2:end));
    Spv = (Suu + Svv) .* u2p.^2;
end
