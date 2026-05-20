function stats = compute_velocity_moments(u, fs)
% COMPUTE_VELOCITY_MOMENTS  Wave velocity moments and nonlinearity statistics.
%
%   stats = compute_velocity_moments(u, fs)
%
%   INPUTS
%     u   - velocity time series (m/s), NaN-free segment (e.g. 2048 samples)
%     fs  - sampling frequency (Hz)
%
%   OUTPUT
%     stats - struct with fields:
%       .u_abs3    - mean(|u|^3)           (m^3/s^3) — related to energetics bedload
%       .u_abs4    - mean(|u|^4)           (m^4/s^4)
%       .u_uabs2   - mean(u*|u|^2)         (m^3/s^3) — wave skewness flux
%       .u_uabs3   - mean(u*|u|^3)         (m^4/s^4)
%       .skewness  - velocity skewness (Sk) — positive = onshore-dominant crests
%       .kurtosis  - velocity kurtosis
%       .asymmetry - acceleration asymmetry (As) — positive = steep front faces
%       .a2        - mean(a^2)   — mean squared acceleration
%       .a3        - mean(a^3)   — mean cubed acceleration
%       .a_spike   - max(|a|) / (2*pi*max(|u|)) — spike indicator
% Author: Holden Leslie-Bole, 2026

u = u(~isnan(u));
dt = 1 / fs;

abs_u = abs(u);

stats.u_abs3  = mean(abs_u.^3);
stats.u_abs4  = mean(abs_u.^4);
stats.u_uabs2 = mean(u .* abs_u.^2);
stats.u_uabs3 = mean(u .* abs_u.^3);

stats.skewness = skewness(u);
stats.kurtosis = kurtosis(u);

% Velocity asymmetry via Hilbert transform (Elgar & Guza 1985; Ruessink et al. 2012).
% Sign convention: A_s < 0 for the forward-pitched (steep-front) shoaling wave,
% growing more negative with Ursell number.
%   A_s = mean(H(u)^3) / mean(u^2)^(3/2),  with H(u) the Hilbert transform of u.
% NOTE (2026-05-20): the leading minus sign previously here produced A_s with the
% SAME sign as the acceleration skewness <a^3> (i.e. POSITIVE for forward-pitched
% waves), which is opposite to the Elgar-Guza / Ruessink convention. MATLAB's
% imag(hilbert(u)) ~ -du/dt (a negative normalized derivative), so the explicit
% minus double-negated. Verified on a synthetic steep-front wave: this form now
% returns A_s < 0 for forward-pitched, matching Ruessink (2012).
u_hilbert = imag(hilbert(u));
stats.asymmetry = mean(u_hilbert.^3) / mean(u.^2)^(3/2);

a = gradient(u, dt);
stats.a2 = mean(a.^2);
stats.a3 = mean(a.^3);

umax = max(abs_u);
amax = max(abs(a));
stats.a_spike = amax / (2 * pi * umax);
end
