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
% RESOLVED (same day): the scope limit flagged by the foundations audit -- that
% the synthetic fields shared the diagnostic's linearized-Bernoulli assumption --
% is closed. Section 6 below now builds the bound component from the COMPLETE
% second-order theory (Herbers & Guza 1991 eq. 4, via
% shared/hg91_bound_impedance.m), anchored to five published values first, so
% the test stands on external truth. The old kinematic-only case is retained,
% relabeled, to display the difference: z2_kin = (k_a/2k0)^2 = 1.217 at 8 m,
% versus the full theory's z2_full = 1.057 -- the quadratic Bernoulli pressure
% OPPOSES the forced-potential pressure (C1/C2 < 0) and cancels most of the
% kh-dependence. The beta inversion must therefore use z2_full, and its
% discriminating power is correspondingly weaker; see
% PUV_paper/docs/audit_foundations_2026-07-29.md and the findings doc.
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

%% ---- 0: anchor hg91_bound_impedance to PUBLISHED values ---------------
% Before any synthetic field is built from it, the interaction coefficient must
% reproduce numbers printed in Herbers & Guza (1991): the Miche special case
% C(dth=pi, f1=f2) = -2 pi^2 f^2/g quoted in their text, and all four Fig. 7
% caption values. This grounds the test in external truth rather than in any
% derivation made in this project.
fprintf('0. ANCHORS — HG91 eq. (4) against published values\n');
anch = { 0.20, 0.20, pi, 13.0, -2*pi^2*0.4^2/9.81, 'Miche -2pi^2 f^2/g', 1e-5; ...
         0.20, 0.20, 0,  13.0, -3.7e-3, 'Fig.7a  f=0.4 dth=0',   0.02; ...
         0.20, 0.20, pi, 13.0, -0.32,   'Fig.7a  f=0.4 dth=180', 0.01; ...
         0.25, 0.25, 0,  13.0, -7.0e-4, 'Fig.7b  f=0.5 dth=0',   0.01; ...
         0.25, 0.25, pi, 13.0, -0.50,   'Fig.7b  f=0.5 dth=180', 0.01 };
ok0 = true;
for i = 1:size(anch,1)
    [~,~,c1,c2] = hg91_bound_impedance(anch{i,1}, anch{i,2}, anch{i,3}, anch{i,4}, 0);
    Ct = c1 + c2;
    fprintf('   %-22s C = %+.6f   published %+.6f   ratio %.4f\n', ...
            anch{i,6}, Ct, anch{i,5}, Ct/anch{i,5});
    if abs(Ct/anch{i,5} - 1) > anch{i,7}, ok0 = false; end
end
if ok0, fprintf('   PASS — all five anchors reproduced.\n\n');
else,   fprintf('   *** FAIL — do not trust anything below ***\n\n'); anyFail = true; end

% Full-theory impedance for the self-sum bound harmonic at this test's geometry:
[z2full, z2kin_chk] = hg91_bound_impedance(f0, f0, 0, h, d);
fprintf('   z2 self-sum bound @ 2f0, h=%.1f, d=%.2f:  kinematic-only %.4f,  FULL %.4f\n\n', ...
        h, d, z2kin_chk, z2full);

%% ---- 1-3: single components ------------------------------------------
cases = { 'free primary  @ f0',   w0,    k0, 1.0; ...
          'free          @ 2f0',  2*w0,  ka, 1.0; ...
          'BOUND kinematic-only', 2*w0,  kb, z2pred };
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
fprintf(['(the kinematic-only row checks CODE plumbing; the physical prediction\n' ...
         ' for a real bound harmonic is the FULL-theory case next)\n']);

%% ---- 3b: bound harmonic with the COMPLETE second-order fields ----------
% p and u built from HG91 eq. (4): p2 = C1 + C2 (head), u2 = C2*g*k3/sigma3,
% both at sensor elevation d. The pipeline's ztest must return z2full — and
% must NOT return the kinematic-only value, which is what the pre-audit version
% of this test asserted. This section is what makes the test independent of the
% assumption it is testing.
fprintf('\n3b. BOUND @ 2f0, FULL second-order fields (HG91 eq. 4)\n');
[~, ~, C1v, C2v, k3v] = hg91_bound_impedance(f0, f0, 0, h, d);
apB  = 0.30;                                       % pressure-head amplitude
uampB = apB * (C2v*g*k3v/(2*w0)) / (C1v + C2v);    % full-theory u per unit p
pB = apB  * sin(2*w0*t);
uB = uampB * sin(2*w0*t);
z2m = ztest_at(pB, uB, zeros(N,1), fs, 2*f0, h, g);
fprintf('   z2 measured %.6f   z2_full %.6f   ratio %.6f\n', z2m, z2full, z2m/z2full);
fprintf('   (kinematic-only would predict %.4f — off by %.0f%%)\n', ...
        z2kin_chk, 100*abs(z2kin_chk/z2full - 1));
if abs(z2m/z2full - 1) > tol
    fprintf('   *** FAIL ***\n'); anyFail = true;
else
    fprintf('   PASS — pipeline returns the full-theory impedance.\n');
end

%% ---- 4: mixture, and the inversion -----------------------------------
% Put the bound and free parts at ADJACENT frequencies inside the harmonic band so
% they are spectrally separable rather than interfering at one frequency.
fprintf('\nMIXTURE: recover the input bound fraction (bound part = FULL theory)\n');
fprintf('%-10s %-12s %-12s %-12s %-12s\n', ...
        'E_b in','z^2 band','E_b FULL','E_b kin-only','FULL err');
okMix = true;
for Eb = [0.0 0.05 0.125 0.25 0.50 1.0]
    fh   = 2*f0;
    fh2  = 2*f0 + 0.006;                          % separable neighbour
    apb  = sqrt(Eb);
    apf  = sqrt(1-Eb);
    sig1 = 2*pi*fh; sig2 = 2*pi*fh2;
    kf2  = ndisp(sig2, h, g);
    % bound part now carries the FULL-theory impedance (3b), not kinematic-only
    p    = apb*sin(sig1*t)                              + apf*sin(sig2*t);
    u    = apb*(C2v*g*k3v/sig1)/(C1v+C2v)*sin(sig1*t)   + apf*(g*kf2/sig2)*sin(sig2*t);
    % band-integrated z^2 across both components
    z2b  = ztest_band(p, u, zeros(N,1), fs, [fh-0.004 fh2+0.004], h, g);
    EbR  = (1 - 1/z2b) / (1 - 1/z2full);          % reciprocal, FULL z2_pred
    EbK  = (1 - 1/z2b) / (1 - 1/z2pred);          % with the kinematic-only z2_pred
    fprintf('%-10.3f %-12.6f %-12.6f %-12.6f %+.4f\n', Eb, z2b, EbR, EbK, EbR-Eb);
    if abs(EbR - Eb) > 0.02, okMix = false; end
end
if okMix
    fprintf('PASS -- reciprocal inversion recovers E_b to within 0.02.\n');
else
    fprintf('*** FAIL: inversion does not recover the input fraction ***\n');
    anyFail = true;
end
fprintf('\nNote the kin-only column: inverting with the kinematic z2_pred UNDER-states\n');
fprintf('the bound fraction, because the full z2_pred is much closer to unity.\n');

%% ---- 5: the reference-free bound wavenumber ---------------------------
% shared/bound_wavenumber_spectral.m computes the expected bound wavenumber at
% EVERY frequency from the full spectral shape, with no peak and no band:
%   kb = 2 conv(k.*S, S) / conv(S, S)
% Two limits pin it down:
%   (a) monochromatic primary at f0 -> the only pair summing to 2 f0 is (f0,f0),
%       so kb(2 f0) must equal 2 k(f0) EXACTLY.
%   (b) bichromatic f1, f2 -> at f1+f2 the only pair is (f1,f2), so
%       kb(f1+f2) = k(f1) + k(f2). This is the case a peak-referenced band cannot
%       represent at all, and it is why the reference-free form matters for the
%       mixed sea/swell states that make up a quarter of the catalog.
% Use NARROW GAUSSIANS, not single-bin deltas. A delta whose centre is not an
% exact multiple of df puts conv(S,S) one bin away from the queried frequency, so
% the weight there is zero and kb comes back NaN. That is a grid artifact, not a
% physics failure -- real spectra are broad -- but it also exposed a test bug
% worth recording: the first version compared abs(NaN/x - 1) > tol, which is
% FALSE, so a NaN silently PASSED. Every check below now requires finiteness
% explicitly.
fprintf('\n5. REFERENCE-FREE BOUND WAVENUMBER (full spectral shape)\n');
dfg = 1/2048; fg = (0:dfg:0.6)';
sig = 4*dfg;                                  % narrow but resolved
gauss = @(fc) exp(-0.5*((fg - fc)/sig).^2) / (sig*sqrt(2*pi));
ok5 = true;

Sg  = gauss(f0);
kbA = bound_wavenumber_spectral(fg, Sg, h, g);
[~, j2] = min(abs(fg - 2*f0));
rA = kbA(j2)/(2*k0);
fprintf('   (a) monochromatic: kb(2f0) = %.6f, 2*k0 = %.6f, ratio %.6f\n', ...
        kbA(j2), 2*k0, rA);
if ~isfinite(rA) || abs(rA - 1) > 2e-3, ok5 = false; end

fa = 0.06; fb = 0.11;
Sg2 = gauss(fa) + gauss(fb);
[kbB, ~, z2p2] = bound_wavenumber_spectral(fg, Sg2, h, g);
ka_ = ndisp(2*pi*fa, h, g); kb_ = ndisp(2*pi*fb, h, g);
[~, js] = min(abs(fg - (fa+fb)));
rB = kbB(js)/(ka_+kb_);
fprintf('   (b) bichromatic:   kb(f1+f2) = %.6f, k(f1)+k(f2) = %.6f, ratio %.6f\n', ...
        kbB(js), ka_+kb_, rB);
if ~isfinite(rB) || abs(rB - 1) > 5e-3, ok5 = false; end

fprintf('   (c) z2pred at f1+f2 = %.6f  (must exceed 1 for a bound component)\n', z2p2(js));
if ~isfinite(z2p2(js)) || ~(z2p2(js) > 1.001), ok5 = false; end

% (d) a failable null: for a purely FREE field the diagnostic must not report
% boundness. Here that means kb at the sum frequency differs from k_free(f),
% which is the whole point -- if kb ever equalled k_free the method would be
% blind. Assert they are distinguishable by more than 5%.
kfr = ndisp(2*pi*(fa+fb), h, g);
fprintf('   (d) k_free(f1+f2) = %.6f vs kb = %.6f  -> separation %.1f%%\n', ...
        kfr, kbB(js), 100*(kfr/kbB(js) - 1));
if ~(kfr/kbB(js) > 1.05), ok5 = false; end

if ok5
    fprintf('   PASS -- recovers 2*k0 monochromatically and k(f1)+k(f2)\n');
    fprintf('   bichromatically, with no peak frequency in the calculation at all.\n');
else
    fprintf('   *** FAIL ***\n'); anyFail = true;
end

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
