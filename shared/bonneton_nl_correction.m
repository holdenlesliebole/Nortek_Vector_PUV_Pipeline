function [zNL, dz] = bonneton_nl_correction(zL, fs, g)
% BONNETON_NL_CORRECTION  Weakly-nonlinear correction to a linear surface
% elevation reconstruction (Bonneton & Lannes).
%
%   [zNL, dz] = bonneton_nl_correction(zL, fs, g)
%
% Bonneton & Lannes, "Recovering water wave elevation from pressure
% measurements" (arXiv:1709.06457; Coastal Engineering 138, 2018), eq. (19):
%
%     zeta_NL = zeta_L - (1/g) * d/dt ( zeta_L * d(zeta_L)/dt )
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
%   zL  - linear surface elevation reconstruction, zero-mean [N x 1] (m)
%   fs  - sampling frequency (Hz)
%   g   - gravity (m/s^2), default 9.81
%
% OUTPUTS
%   zNL - nonlinear reconstruction (m)
%   dz  - the correction itself, zNL - zL (m)
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

if nargin < 3 || isempty(g), g = 9.81; end

zL = zL(:);
N  = numel(zL);
if N < 8, zNL = zL; dz = zeros(size(zL)); return; end

% Angular frequency vector matching MATLAB's fft ordering, including the
% negative-frequency half, so the inverse transform is real.
k     = (0:N-1)';
kk    = min(k, N - k);                 % |index| distance from DC
omega = 2*pi * (kk * fs / N);

Z2    = fft(zL.^2);
dzhat = (omega.^2) / (2*g) .* Z2;

dz  = real(ifft(dzhat));
zNL = zL + dz;
end
