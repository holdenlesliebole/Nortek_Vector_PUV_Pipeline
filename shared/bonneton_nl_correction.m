function [zNL, dz, dz3] = bonneton_nl_correction(zL, fs, g, delta_m, h0)
% BONNETON_NL_CORRECTION  Weakly-nonlinear correction to a linear surface
% elevation reconstruction (Bonneton & Lannes).
%
%   [zNL, dz]      = bonneton_nl_correction(zL, fs, g)                  % eq. (19)
%   [zNL, dz, dz3] = bonneton_nl_correction(zL, fs, g, delta_m, h0)     % eq. (46)
%
% Bonneton & Lannes, "Recovering water wave elevation from pressure
% measurements" (arXiv:1709.06457; Coastal Engineering 138, 2018), eq. (19) for a
% BOTTOM-mounted sensor:
%
%     zeta_NL = zeta_L - (1/g) * d/dt ( zeta_L * d(zeta_L)/dt )
%
% and their eq. (46) (Appendix C, dimensional) for a sensor at height delta_m
% above the bed in depth h0, which adds a third term:
%
%     zeta_NL = zeta_L - (1/g) d_t( zeta_L d_t zeta_L )
%                      + (1/g) M(D) * [ N(D) d_t zeta_L ]^2
%     M = cosh(h0|D|)/cosh(delta_m|D|),   N = sinh(delta_m|D|)/sinh(h0|D|)
%
% evaluated as Fourier multipliers in time via k(omega) from
% omega^2 = g k tanh(h0 k), which is their eq. (51) route for irregular waves.
%
% WHAT THE THIRD TERM IS, PHYSICALLY. It is the vertical-velocity quadratic term
% |d_z Phi|^2 in the Bernoulli equation evaluated AT THE SENSOR. At the bed w = 0,
% so sinh(delta_m|D|) -> 0 and the term vanishes, recovering eq. (19) exactly.
% That limit is asserted in the closure test.
%
% HOW BIG IS IT. For delta_m << h0, N -> delta_m/h0, so the monochromatic 2*omega
% part of the third term is -(M N^2/2)(A^2 omega^2/g), i.e. about
% -(1/2)(delta_m/h0)^2 times the main term. Their shallow-water form (47) confirms
% the coefficient exactly as (delta_m/h0)^2. For a sensor 0.6-0.95 m above the bed
% in 5-16 m, delta_m/h0 = 0.05-0.14, so the third term is -0.1% to -1% OF THE
% CORRECTION -- negligible here, but included so the approximation is a measured
% bound rather than an assumption.
%
% WHY THIS EXISTS. The classical transfer-function method (TFM) applies the
% LINEAR pressure transfer function frequency by frequency, using the free-wave
% dispersion relation at each frequency. A bound harmonic is phase-locked to its
% primary and does not satisfy that relation, so the TFM mis-estimates it. This
% is the published correction, and the paper's own framing is that the TFM
% "cannot reproduce the peaked and skewed shape of nonlinear wave fields".
%
% IMPLEMENTATION. Use the identity zeta_L * d_t zeta_L = (1/2) d_t(zeta_L^2), so
%
%     zeta_NL = zeta_L - (1/(2g)) * d_tt ( zeta_L^2 )
%
% and evaluate d_tt spectrally (multiply by -omega^2). That is exact for a
% periodic record and avoids finite differencing entirely, which matters because
% the correction lives at high frequency where a finite difference is noisiest.
% In the frequency domain the correction is a single multiply:
%
%     dz_hat(f) = + (omega^2 / (2g)) * F[ zeta_L^2 ](f)
%
% HAND CHECK (Rule 1). For a monochromatic zeta_L = A cos(omega t):
%   zeta_L^2   = (A^2/2)(1 + cos 2 omega t)
%   d_tt(...)  = -2 A^2 omega^2 cos 2 omega t
%   correction = + (A^2 omega^2 / g) cos 2 omega t
% i.e. the correction ADDS a second harmonic of amplitude A^2 omega^2 / g. So the
% linear reconstruction UNDER-estimates bound second-harmonic energy. Asserted in
% L2_spectral/test_bonneton_reconstruction.m.
%
% INPUTS
%   zL      - linear surface elevation reconstruction, zero-mean [N x 1] (m)
%   fs      - sampling frequency (Hz)
%   g       - gravity (m/s^2), default 9.81
%   delta_m - sensor height above the bed (m). Omit or 0 for the eq. (19) form.
%   h0      - total water depth (m). Required if delta_m > 0.
%
% OUTPUTS
%   zNL - nonlinear reconstruction (m)
%   dz  - the total correction, zNL - zL (m)
%   dz3 - the elevated-sensor third term alone (m), zero when delta_m = 0
%
% SCOPE AND LIMITS
%   - Derived for small steepness sigma = eps*sqrt(mu) << 1 with eps, mu <~ 1,
%     i.e. shallow to intermediate depth. Bonneton & Lannes state deep water
%     (mu >> 1) is NOT covered, so do not apply this at the deep end of a
%     catalog without checking mu.
%   - Derived for a bottom-mounted sensor over a flat bottom. Their Appendix B
%     (eq. 41/42) generalizes to a sensor at some height above the bottom; that
%     generalization has NOT been read or implemented here. Our sensors sit
%     0.6-0.8 m above the bed in 5-30 m, so d/h ~ 0.03-0.15 and the sensor
%     elevation is carried through zL (computed with the elevated Kp) rather than
%     in the correction term. Treat the correction as leading-order in d/h.
%
% Author: Holden Leslie-Bole, 2026

if nargin < 3 || isempty(g),       g = 9.81;    end
if nargin < 4 || isempty(delta_m), delta_m = 0; end
if nargin < 5, h0 = []; end
if delta_m > 0 && (isempty(h0) || ~isfinite(h0) || h0 <= delta_m)
    error('bonneton_nl_correction:badDepth', ...
          'h0 must be supplied and exceed delta_m when delta_m > 0.');
end

zL = zL(:);
N  = numel(zL);
if N < 8
    zNL = zL; dz = zeros(size(zL)); dz3 = zeros(size(zL)); return
end

% Angular frequency vector matching MATLAB's fft ordering, including the
% negative-frequency half, so the inverse transform is real.
kidx  = (0:N-1)';
kk    = min(kidx, N - kidx);            % |index| distance from DC
omega = 2*pi * (kk * fs / N);           % |omega|, for EVEN multipliers

% SIGNED angular frequency, required for the time derivative. Multiplying a real
% signal's fft by i*|omega| breaks Hermitian symmetry, so real(ifft(.)) returns
% ~0 -- which is exactly the bug this replaces. Even multipliers (omega^2, M, N)
% can use the folded |omega| above; d_t cannot.
kSig  = kidx; kSig(kidx > N/2) = kidx(kidx > N/2) - N;
omegaS = 2*pi * (kSig * fs / N);
if mod(N,2) == 0, omegaS(N/2 + 1) = 0; end   % Nyquist sign is ambiguous

% --- main term: -(1/2g) d_tt(zL^2), identical to -(1/g) d_t(zL d_t zL) -----
dz2 = real(ifft( (omega.^2)/(2*g) .* fft(zL.^2) ));

% --- eq. (46) third term, only for a sensor above the bed -----------------
dz3 = zeros(N,1);
if delta_m > 0
    % wavenumber per frequency from the dispersion relation (their eq. 51 route)
    kw = zeros(N,1);
    nz = omega > 0;
    kw(nz) = get_wavenumber(omega(nz), h0);

    % M = cosh(h0 k)/cosh(delta_m k),  N = sinh(delta_m k)/sinh(h0 k)
    Mm = ones(N,1); Nn = zeros(N,1);
    Mm(nz) = cosh(h0*kw(nz)) ./ cosh(delta_m*kw(nz));
    Nn(nz) = sinh(delta_m*kw(nz)) ./ sinh(h0*kw(nz));

    % q = N(D) d_t zeta_L  -> square in time -> apply M(D)
    dzLdt = real(ifft( 1i*omegaS .* fft(zL) ));  % d_t zeta_L (SIGNED omega)
    q     = real(ifft( Nn      .* fft(dzLdt) )); % N(D) d_t zeta_L
    dz3   = real(ifft( Mm      .* fft(q.^2) )) / g;
end

dz  = dz2 + dz3;
zNL = zL + dz;
end
