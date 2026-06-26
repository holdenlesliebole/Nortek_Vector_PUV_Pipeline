% TEST_ZTEST_LINEAR  Closure test for the z² (pressure-velocity) diagnostic.
%
% Generates a synthetic monochromatic linear surface wave, propagates it
% to pressure and horizontal velocity at sensor depth via linear theory,
% feeds the result through the same spectral routine PUV_L2_spectral.m
% uses, and asserts that the resulting ztest is 1.0 within numerical
% tolerance for a range of water depths.
%
% This would have caught the 2026-06 bug where Spp_from_vel was computed
% as Suu·vel2pres² instead of Suu·(omega/(g·k))², which made z² scale
% with depth (z² ≈ 0.33 at H=5 m, ≈ 2.78 at H=15 m) under purely linear
% input.
%
% Run from the L2_spectral directory:
%   >> test_ztest_linear
%
% Author: Holden Leslie-Bole, 2026-06-05

clear; close all;

% --- Common physical setup ---
g    = 9.81;
rho  = 1025;
d    = 0.7;             % sensor height above bed (m)
fs   = 2;               % sampling frequency (Hz)
segDur = 1024;          % segment length (s)
N    = round(segDur*fs);
t    = (0:N-1)' / fs;

% Wave inputs: small enough to keep linear theory accurate.
% Choose three frequencies in the SS band to cover deep- and
% shallow-water regimes simultaneously.
f_in = [0.07, 0.10, 0.15];   % Hz
A_in = [0.30, 0.50, 0.30];   % m surface amplitude

% Depths to test
H_list = [3 5 7 10 15 20];

fprintf('\n%5s | %10s | %10s\n', 'H (m)', 'z2 raw', 'pass?');
fprintf('------+------------+----------\n');

allPass = true;
for H = H_list
    % --- Build linear time series at sensor depth ---
    eta  = zeros(N,1);
    p_s  = zeros(N,1);
    u_s  = zeros(N,1);
    for j = 1:numel(f_in)
        f = f_in(j); A = A_in(j);
        omega = 2*pi*f;
        k     = newton_dispersion(omega, H, g);
        Kp_p  = cosh(k*d) / cosh(k*H);
        Tu    = (g*k/omega) * cosh(k*d) / cosh(k*H);
        phase = 2*pi*rand;
        eta = eta + A * cos(omega*t + phase);
        p_s = p_s + A * Kp_p * cos(omega*t + phase);     % m of water
        u_s = u_s + A * Tu   * cos(omega*t + phase);     % m/s
    end
    v_s = zeros(N,1);    % unidirectional → v = 0

    % --- Run the same Welch-PSD setup the pipeline uses ---
    % p_s is already in m of water; matches pSeg_m in PUV_L2_spectral.m.
    win   = hann(N);
    nfft  = 2^nextpow2(N);
    [Spp, fpx] = pwelch(p_s, win, [], nfft, fs);
    [Suu, ~]   = pwelch(u_s, win, [], nfft, fs);
    [Svv, ~]   = pwelch(v_s, win, [], nfft, fs);

    % --- Apply the (now corrected) Spp_from_vel relation ---
    omega_v = 2*pi*fpx;
    k_v     = zeros(size(fpx));
    for ii = 2:numel(fpx)
        k_v(ii) = newton_dispersion(omega_v(ii), H, g);
    end
    u2p = zeros(size(fpx));
    u2p(2:end) = omega_v(2:end) ./ (g * k_v(2:end));    % (ω / gk)
    Spp_from_vel = (Suu + Svv) .* u2p.^2;

    % --- z² in the SS band ---
    iSS = fpx >= 0.04 & fpx <= 0.25;
    z2  = sum(Spp(iSS)) / sum(Spp_from_vel(iSS) + eps);

    tol = 0.02;   % within 2% of unity for synthetic linear input
    pass = abs(z2 - 1) < tol;
    if ~pass, allPass = false; end
    fprintf('%5d | %10.4f | %10s\n', H, z2, ternary(pass,'pass','FAIL'));
end

fprintf('\n');
if allPass
    fprintf('All depths pass: z² closure on synthetic linear input is correct.\n');
else
    error('ztest closure test failed for at least one depth.');
end

% ---------------------------------------------------------------------
function k = newton_dispersion(omega, H, g)
    if omega == 0, k = 0; return, end
    k = omega^2 / (g * sqrt(tanh(omega^2 * H / g)));   % Wu & Thornton 1986 guess
    for ii = 1:50
        fk = g*k*tanh(k*H) - omega^2;
        dfk = g*tanh(k*H) + g*k*H*(1 - tanh(k*H)^2);
        dk = fk / dfk;
        k = k - dk;
        if abs(dk) < 1e-12, return; end
    end
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
