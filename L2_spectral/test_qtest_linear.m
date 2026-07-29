% TEST_QTEST_LINEAR  Closure test for the P-U coherence (Q-test) diagnostic.
%
% The Q-test reports the magnitude-squared coherence between pressure and
% cross-shore velocity, energy-weighted over the wind-wave band
% [0.05, 0.20] Hz (Steve Elgar's suggested QC follow-up to the z-test).
%
% Hand-derived expected value (Rule 1, AnalysisDeliberationGuardrails):
%   For a clean linear progressive wave, p(t) and u(t) are both linear in the
%   same surface elevation and IN PHASE, so at every frequency
%     gamma^2 = |Spu|^2 / (Spp*Suu)
%             = (a*b*Seta)^2 / (a^2*Seta * b^2*Seta) = 1   exactly,
%   independent of Kp and of the (gk/omega) velocity transfer factor. The
%   Q-test therefore must return 1.0 (within taper/leakage tolerance) on a
%   noise-free unidirectional linear input.
%
% Sensitivity check: adding independent white noise to the velocity channel
%   must drive the band coherence measurably below 1, otherwise the test
%   would pass trivially regardless of implementation.
%
% Directional / per-segment note (Rule 2): a directionally spread sea reduces
%   P-U(cross-shore) coherence below 1 because u weights each wave direction by
%   cos(theta) while p does not, with ENSEMBLE reduction
%   gamma^2 = [<cos theta>_E]^2 / <cos^2 theta>_E. BUT this is an across-segment
%   (ensemble) effect: a single segment's taper-averaged coherence sees fixed
%   within-segment phases and is biased toward 1, so it primarily measures
%   WITHIN-SEGMENT NOISE rather than directional spread. That is exactly what we
%   want from a per-segment noise-QC indicator: clean -> ~1, sensor noise -> drop,
%   directional spread mostly cancelling out. For the narrow Torrey spread
%   (sigma_theta ~ 14-21 deg) the ensemble reduction is >~0.98 anyway, so it does
%   not mask a noise problem either way.
%
% Run from the L2_spectral directory:
%   >> test_qtest_linear
%
% Author: Holden Leslie-Bole, 2026-06-06

clear; close all;

% --- Common physical setup (mirrors test_ztest_linear.m) ---
g    = 9.81;
d    = 0.7;             % sensor height above bed (m)
fs   = 2;               % sampling frequency (Hz)
segDur = 1024;          % segment length (s)
N    = round(segDur*fs);
t    = (0:N-1)' / fs;
NW   = 4;              % time-bandwidth product, matches pipeline default

f_in = [0.07, 0.10, 0.15];   % Hz, in the [0.05 0.20] wind-wave band
A_in = [0.30, 0.50, 0.30];   % m surface amplitude
H_list = [3 5 7 10 15 20];
band = [0.05 0.20];

tol_clean = 0.02;    % within 2% of unity for noise-free linear input
nfft = N;            % mtm_full style: one segment, taper-averaged only

fprintf('\n--- Block 1: clean unidirectional linear wave (expect gamma^2 = 1) ---\n');
fprintf('%5s | %12s | %8s\n', 'H (m)', 'gamma2 band', 'pass?');
fprintf('------+--------------+---------\n');
allPass = true;
for H = H_list
    [p_s, u_s, ~] = build_linear_PU(f_in, A_in, H, d, g, t);
    g2 = band_coherence(p_s, u_s, nfft, fs, NW, band);
    pass = abs(g2 - 1) < tol_clean;
    allPass = allPass & pass;
    fprintf('%5d | %12.4f | %8s\n', H, g2, ternary(pass,'pass','FAIL'));
end

fprintf('\n--- Block 2: velocity-channel white noise (expect monotonic drop) ---\n');
% Coherence is robust to broadband noise when wave energy is concentrated in
% spectral lines, so a strong (SNR~1) contamination is needed to move it far.
% Sensitivity requires (i) coherence decreases monotonically as noise grows and
% (ii) the strongest contamination drops it clearly below 1.
fprintf('%5s | %10s | %10s\n', 'H (m)', 'noise SNR', 'gamma2');
fprintf('------+------------+------------\n');
H = 7;
[p_s, u_s, u_amp] = build_linear_PU(f_in, A_in, H, d, g, t);
rng(1);   % deterministic
snr_list = [10 3 1];
g2_noise = zeros(size(snr_list));
for is = 1:numel(snr_list)
    noise = (u_amp/snr_list(is)) * randn(N,1);
    g2_noise(is) = band_coherence(p_s, u_s + noise, nfft, fs, NW, band);
    fprintf('%5d | %10.1f | %10.4f\n', H, snr_list(is), g2_noise(is));
end
monotonic = all(diff(g2_noise) < 0);
strongDrop = g2_noise(end) < 0.95;
sensitivityOK = monotonic && strongDrop;
fprintf('   monotonic decrease: %s | SNR=1 drops below 0.95: %s\n', ...
    ternary(monotonic,'yes','NO'), ternary(strongDrop,'yes','NO'));

fprintf('\n');
if allPass && sensitivityOK
    fprintf('PASS: Q-test closure correct (clean linear input = 1; noise drives it down).\n');
else
    error('Q-test closure test failed (clean=%d, sensitivity=%d).', allPass, sensitivityOK);
end

% ---------------------------------------------------------------------
function [p_s, u_s, u_amp] = build_linear_PU(f_in, A_in, H, d, g, t)
    N = numel(t); p_s = zeros(N,1); u_s = zeros(N,1); u_amp = 0;
    for j = 1:numel(f_in)
        f = f_in(j); A = A_in(j); omega = 2*pi*f;
        k  = newton_dispersion(omega, H, g);
        Kp = cosh(k*d)/cosh(k*H);
        Tu = (g*k/omega)*cosh(k*d)/cosh(k*H);
        phase = 2*pi*(0.13*j);   % deterministic, distinct
        p_s = p_s + A*Kp*cos(omega*t + phase);   % m of water
        u_s = u_s + A*Tu*cos(omega*t + phase);   % m/s
        u_amp = u_amp + A*Tu;                    % crude scale for SNR
    end
end

function g2 = band_coherence(p, u, nfft, fs, NW, band)
    p = detrend(p); u = detrend(u);
    [Spp, Spu, f] = psd_multitaper(p, u, nfft, fs, NW);
    [Suu, ~,   ~] = psd_multitaper(u, [], nfft, fs, NW);
    coh2 = abs(Spu).^2 ./ (Spp .* Suu + eps);
    ib = f >= band(1) & f <= band(2);
    % energy-weighted over the band (weight by pressure energy)
    w = Spp(ib);
    g2 = sum(coh2(ib) .* w) / (sum(w) + eps);
end

function k = newton_dispersion(omega, H, g)
    if omega == 0, k = 0; return, end
    k = omega^2 / (g * sqrt(tanh(omega^2 * H / g)));
    for ii = 1:50
        fk = g*k*tanh(k*H) - omega^2;
        dfk = g*tanh(k*H) + g*k*H*(1 - tanh(k*H)^2);
        dk = fk / dfk; k = k - dk;
        if abs(dk) < 1e-12, return; end
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
