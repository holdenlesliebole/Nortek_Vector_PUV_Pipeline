function [tau_b, fric_w, Aw] = bed_stress(Ub, T, D50, rho)
% BED_STRESS  Wave-induced bed shear stress (amplitude), LEGACY roughness ks = 10*D50.
%
%   [tau_b, fric_w, Aw] = bed_stress(Ub, T, D50, rho)
%
%   INPUTS
%     Ub   - RMS near-bed orbital speed (m/s), = L2.Ub. NOT the amplitude: the
%            sqrt(2) conversion to the amplitude is done inside (see INTERFACE).
%     T    - representative wave period (s) (T_b or T_p)
%     D50  - median grain diameter (m); the roughness is ks = 10*D50
%     rho  - water density (kg/m^3)
%
%   OUTPUTS
%     tau_b  - amplitude bed shear stress (Pa)
%     fric_w - wave friction factor (dimensionless)
%     Aw     - orbital excursion amplitude A = sqrt(2)*Ub*T/(2 pi) (m)
%
%   INTERFACE (read this before calling)
%     The FIRST ARGUMENT IS THE RMS near-bed orbital speed Ub (m/s), the
%     quantity stored as L2.Ub = sqrt(mean(uBed.^2 + vBed.^2)). The routine
%     converts it INSIDE to the orbital-velocity AMPLITUDE of the
%     representative wave,
%
%       u_br = sqrt(2) * Ub                       (m/s)
%
%     because both the friction factor and the Shields threshold are defined
%     for the amplitude. Callers therefore pass the RMS speed, never u_br.
%     (Before 2026-11-11 the RMS speed was used directly as the amplitude,
%     which underestimated the stress by a factor of 2.)
%
%   METHOD
%       u_br = sqrt(2) * Ub                       amplitude (m/s)
%       A    = u_br * T / (2*pi)                  orbital excursion amplitude (m)
%       r    = A / k_s                            relative roughness
%       f_w  = min(0.3, 0.00251 * exp(5.21 * r^(-0.19)))
%                                                 Swart (1974) rough-flow friction
%                                                 factor in the form of Soulsby &
%                                                 Whitehouse (1997, Eq. 13); one
%                                                 expression for all r, no branches
%       tau_b = 0.5 * rho * f_w * u_br^2          amplitude bed shear stress (Pa)
%
%   Hand-derived check values (tests/test_bed_stress_swart.m):
%     r = 1: 0.300000 (cap), 10: 0.072540, 100: 0.022025, 300: 0.014629, 1000: 0.010202.
%
%   OUTPUT NOTE: Aw is the excursion AMPLITUDE A = u_br*T/(2 pi) above (it was
%   Ub*T/(2 pi) before 2026-11-11, i.e. a factor sqrt(2) smaller).
%
%   NOTE (2026-05-23)
%     This legacy form uses ks = 10*D50 internally, an unprincipled
%     middle-ground that doesn't match either the literature flat-bed grain
%     standard (ks = 2.5*D50) or a bedform-explicit movable-bed roughness.
%     For new analyses prefer bed_stress_ks, which takes ks directly and
%     pairs naturally with site_grain_size (ks = 2.5*D84 from measured PSD,
%     Wiberg & Smith 1991). Retained for sites without a site_grain_size
%     entry. The roughness rule is unchanged by the 2026-11-11 correction;
%     only the formula and the amplitude changed (see bed_stress_ks).
%
%   REFERENCES
%     Swart (1974), Delft Hydraulics Lab. Publ. 131.
%     Soulsby & Whitehouse (1997), Eq. 13.
%
% See also: bed_stress_ks, site_grain_size
%
% Author: Holden Leslie-Bole, 2026; amplitude and Swart rough-flow form 2026-11-11

ks   = 10 * D50;                      % Nikuradse roughness (m)
u_br = sqrt(2) .* Ub;                 % amplitude of the representative wave (m/s)
Aw   = (u_br .* T) / (2 * pi);        % orbital excursion amplitude (m)
r    = Aw ./ ks;                      % relative roughness

fric_w = min(0.3, 0.00251 * exp(5.21 * r.^(-0.19)));
fric_w(isnan(r)) = NaN;               % keep missing data missing

tau_b = 0.5 * rho .* fric_w .* u_br.^2;
end
