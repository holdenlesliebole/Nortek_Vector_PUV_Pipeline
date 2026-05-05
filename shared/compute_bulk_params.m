function bulk = compute_bulk_params(S_eta, Suu, Svv, Spu, Spv, f, H, opts)
% COMPUTE_BULK_PARAMS  Bulk wave parameters from spectral estimates.
%
%   bulk = compute_bulk_params(S_eta, Suu, Svv, Spu, Spv, f, H, opts)
%
%   INPUTS
%     S_eta - surface elevation PSD (m^2/Hz) [nf x 1]
%     Suu   - cross-shore velocity PSD (m^2/s^2/Hz) [nf x 1]
%     Svv   - alongshore velocity PSD (m^2/s^2/Hz) [nf x 1]
%     Spu   - pressure-U cross-spectrum (complex) [nf x 1]
%     Spv   - pressure-V cross-spectrum (complex) [nf x 1]
%     f     - frequency vector (Hz) [nf x 1]
%     H     - total water depth, bed to surface (m)
%     opts  - struct with fields:
%               .fIG  - [fLow, fHigh] infragravity band (Hz), default [0.004, 0.04]
%               .fSS  - [fLow, fHigh] sea-swell band (Hz), default [0.04, 0.25]
%               .rho  - seawater density (kg/m^3), default 1025
%               .g    - gravitational acceleration (m/s^2), default 9.81
%
%   OUTPUT
%     bulk - struct with fields:
%       .Hs      - total significant wave height (m)
%       .Hs_SS   - sea-swell Hs (m)
%       .Hs_IG   - infragravity Hs (m)
%       .Tp      - peak period (s), from SS band
%       .fp      - peak frequency (Hz)
%       .Tm02    - mean zero-crossing period (s)
%       .meanDir - energy-weighted mean direction (deg), SS band
%       .Ef      - total energy flux (W/m)
%
%   REQUIRES
%     get_wavenumber.m, get_cg.m on the MATLAB path
% Author: Holden Leslie-Bole, 2026

% Defaults
if ~isfield(opts, 'fIG'),  opts.fIG  = [0.004, 0.04]; end
if ~isfield(opts, 'fSS'),  opts.fSS  = [0.04, 0.25];  end
if ~isfield(opts, 'rho'),  opts.rho  = 1025;           end
if ~isfield(opts, 'g'),    opts.g    = 9.81;            end

% Band masks
iIG  = f >= opts.fIG(1)  & f < opts.fIG(2);
iSS  = f >= opts.fSS(1)  & f <= opts.fSS(2);
iTot = f >= opts.fIG(1)  & f <= opts.fSS(2);

% --- Significant wave height ---
m0_total = trapz(f(iTot), S_eta(iTot));
m0_SS    = trapz(f(iSS),  S_eta(iSS));
m0_IG    = trapz(f(iIG),  S_eta(iIG));

bulk.Hs    = 4 * sqrt(max(m0_total, 0));
bulk.Hs_SS = 4 * sqrt(max(m0_SS, 0));
bulk.Hs_IG = 4 * sqrt(max(m0_IG, 0));

% --- Peak period (SS band) ---
fSS_vec = f(iSS);
S_SS    = S_eta(iSS);
[~, iPeak] = max(S_SS);
if ~isempty(iPeak) && fSS_vec(iPeak) > 0
    bulk.fp = fSS_vec(iPeak);
    bulk.Tp = 1 / bulk.fp;
else
    bulk.fp = NaN;
    bulk.Tp = NaN;
end

% --- Mean zero-crossing period ---
m2 = trapz(f(iTot), f(iTot).^2 .* S_eta(iTot));
if m2 > 0
    bulk.Tm02 = sqrt(m0_total / m2);
else
    bulk.Tm02 = NaN;
end

% --- Mean wave direction (energy-weighted over SS band) ---
% Directional coefficients from PUV cross-spectra.
% Kp factors cancel in the ratio, so use raw (uncorrected) spectra.
Spp_uv = Suu + Svv;
denom  = sqrt(abs(Spu).^2 + abs(Spv).^2 + eps) ./ sqrt(Spp_uv + eps);
% Standard PUV formulation:
a1 = real(Spu) ./ sqrt(S_eta .* Spp_uv + eps);
b1 = real(Spv) ./ sqrt(S_eta .* Spp_uv + eps);

% Energy-weighted mean direction in SS band
E_ss = S_eta(iSS);
E_sum = sum(E_ss);
if E_sum > 0
    a1_mean = sum(a1(iSS) .* E_ss) / E_sum;
    b1_mean = sum(b1(iSS) .* E_ss) / E_sum;
    bulk.meanDir = atan2d(b1_mean, a1_mean);
else
    bulk.meanDir = NaN;
end

% --- Energy flux ---
% F = rho * g * integral(cg(f) * S_eta(f) df)
fTot = f(iTot);
omega_tot = 2 * pi * fTot;
k_tot = get_wavenumber(omega_tot, H);
cg_tot = get_cg(k_tot, H);
bulk.Ef = opts.rho * opts.g * trapz(fTot, cg_tot(:) .* S_eta(iTot));

end
