% TEST_PHASE_PU_LINEAR  Closure test for the P-U cross-spectral PHASE diagnostic.
%
% Companion to test_ztest_linear.m / test_qtest_linear.m. Builds a synthetic
% linear progressive wave, propagates it to pressure and cross-shore velocity
% at sensor depth, IMPOSES a known phase lag of the velocity behind the
% pressure, and asserts that the energy-weighted cross-spectral phase recovers
% that imposed lag. This guards the phase_PU field added to PUV_L2_spectral.m
% (2026-06-26) for the Bob/Steve velocity-QC thread.
%
% Convention check: Spu = cpsd(p,u) => angle(Spu) = phase(p) - phase(u). If u
% lags p by phi (u ~ cos(wt - phi)), the recovered phase is +phi. For phi = 0
% (clean in-phase progressive wave) the phase is 0 deg.
%
% Run from the L2_spectral directory:
%   >> test_phase_PU_linear
%
% Author: Holden Leslie-Bole, 2026-06-26

clear; close all;

g    = 9.81;
d    = 0.7;            % sensor height above bed (m)
fs   = 2;              % Hz
segDur = 1024;        % s
N    = round(segDur*fs);
t    = (0:N-1)' / fs;

% Energy-weighting band = the Q-test wind-wave band used in the pipeline
fQ   = [0.05, 0.20];

% A few SS-band components; the dominant one (0.10 Hz) sets the band phase
f_in = [0.07, 0.10, 0.15];   % Hz
A_in = [0.20, 0.50, 0.20];   % m surface amplitude

% Imposed velocity-lag-behind-pressure cases (deg) and depths
phi_list = [0, 20, -35, 90];
H_list   = [5, 8];

tol = 2.0;   % deg tolerance on synthetic linear input

fprintf('\n%6s | %8s | %10s | %10s | %6s\n', 'H (m)', 'phi_in', 'phi_rec', 'err', 'pass?');
fprintf('-------+----------+------------+------------+--------\n');

allPass = true;
for H = H_list
    for phi_deg = phi_list
        phi = deg2rad(phi_deg);
        p_s = zeros(N,1);
        u_s = zeros(N,1);
        for j = 1:numel(f_in)
            f = f_in(j); A = A_in(j);
            omega = 2*pi*f;
            k     = newton_dispersion(omega, H, g);
            Kp_p  = cosh(k*d) / cosh(k*H);
            Tu    = (g*k/omega) * cosh(k*d) / cosh(k*H);
            ph    = 2*pi*rand;
            p_s = p_s + A * Kp_p * cos(omega*t + ph);          % m of water
            u_s = u_s + A * Tu   * cos(omega*t + ph - phi);    % u lags p by phi
        end

        % Same Welch cross-spectrum + energy weighting the pipeline uses
        win  = hann(N);
        nfft = 2^nextpow2(N);
        [Spp, fpx] = pwelch(p_s, win, [], nfft, fs);
        [Suu, ~]   = pwelch(u_s, win, [], nfft, fs);
        [Spu, ~]   = cpsd(p_s, u_s, win, [], nfft, fs);

        % S_eta weighting (Kp^-2); proportional to surface-elevation energy
        omega_v = 2*pi*fpx;
        k_v = zeros(size(fpx));
        for ii = 2:numel(fpx), k_v(ii) = newton_dispersion(omega_v(ii), H, g); end
        Kp = cosh(k_v*d) ./ cosh(k_v*H);
        Kp(1) = 1;
        S_eta = Spp ./ (Kp.^2 + eps);

        iQ = fpx >= fQ(1) & fpx <= fQ(2);
        Spu_bar = sum(Spu(iQ) .* S_eta(iQ)) / sum(S_eta(iQ) + eps);
        phi_rec = rad2deg(angle(Spu_bar));

        err  = abs(phi_rec - phi_deg);
        pass = err < tol;
        if ~pass, allPass = false; end
        fprintf('%6d | %8.1f | %10.2f | %10.3f | %6s\n', ...
            H, phi_deg, phi_rec, err, ternary(pass,'pass','FAIL'));
    end
end

fprintf('\n');
if allPass
    fprintf('All cases pass: phase_PU recovers the imposed P-U lag on synthetic linear input.\n');
else
    error('phase_PU closure test failed for at least one case.');
end

% ---------------------------------------------------------------------
function k = newton_dispersion(omega, H, g)
    if omega == 0, k = 0; return, end
    k = omega^2 / (g * sqrt(tanh(omega^2 * H / g)));
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
