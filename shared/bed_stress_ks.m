function [tau_b, fric_w, Aw] = bed_stress_ks(Ub, T, ks, rho)
% BED_STRESS_KS  Wave-induced bed shear stress (amplitude) for a specified roughness ks.
%
%   [tau_b, fric_w, Aw] = bed_stress_ks(Ub, T, ks, rho)
%
%   INPUTS
%     Ub   - RMS near-bed orbital speed (m/s), = L2.Ub. NOT the amplitude: the
%            sqrt(2) conversion to the amplitude is done inside (see INTERFACE).
%     T    - representative wave period (s): the spectral near-bed period T_b
%            (L2.Tb, the pipeline default since 2026-11-05) or the peak period T_p
%     ks   - Nikuradse equivalent sand roughness (m). Typical choices:
%               ks = 2.5*D84     (Wiberg & Smith 1991, natural rippled
%                                  /poorly-sorted beds; RECOMMENDED)
%               ks = 2.5*D50     (literature standard, well-sorted beds)
%               ks = 3.0*D90     (van Rijn 1984; similar idea)
%               ks = bedform-explicit (Nielsen 1992; ripple geometry-aware)
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
%   For the inner-shelf sand sites in this project, the Wiberg & Smith
%   ks = 2.5*D84 form is the recommended default: it captures bed roughness
%   set by the coarsest grains the bed presents (which dominate form drag on
%   poorly-sorted natural beds; sorting sigma ~ 1.7-2.2 at Torrey) and uses
%   measured PSD data via site_grain_size.m.
%
%   CORRECTION 2026-11-11. The earlier three-branch form (r < 5, 5 <= r <= 70,
%   r > 70 with f_w = 0.0521 r^-0.187) was labeled Swart (1974). Its rough
%   branch is Soulsby's smooth-bed turbulent formula, whose argument is the
%   wave Reynolds number, applied to relative roughness; it applied to more
%   than 99% of TBR23 segments and ran 20% to 40% above the rough-bed forms
%   at the observed r of 221 to 382. The RMS speed was also used as if it were
%   the amplitude.
%
%   See also: site_grain_size (per-site D50/D84/D90 lookup),
%             bed_stress (legacy; takes D50 + uses ks = 10*D50 internally).
%
%   REFERENCES
%     Swart, D.H. (1974). Offshore sediment transport and equilibrium
%       beach profiles. Delft Hydraulics Lab. Publ. 131.
%     Soulsby, R.L. & Whitehouse, R.J.S. (1997). Threshold of sediment motion in
%       coastal environments. Proc. Combined Australasian Coastal Engineering and
%       Port Conference, Christchurch, 149-154. (Eq. 13: Swart friction factor.)
%     Wiberg, P.L. & Smith, J.D. (1991). Velocity distribution and bed
%       roughness in high-gradient streams. Water Resour. Res. 27, 825-838.
%     Soulsby, R.L. (1997). Dynamics of Marine Sands. Thomas Telford.
%
% Author: Holden Leslie-Bole, 2026-05-23; amplitude and Swart rough-flow form 2026-11-11

u_br = sqrt(2) .* Ub;                 % amplitude of the representative wave (m/s)
Aw   = (u_br .* T) / (2 * pi);        % orbital excursion amplitude (m)
r    = Aw ./ ks;                      % relative roughness

fric_w = min(0.3, 0.00251 * exp(5.21 * r.^(-0.19)));
fric_w(isnan(r)) = NaN;               % min(0.3, NaN) returns 0.3; keep missing data missing

tau_b = 0.5 * rho .* fric_w .* u_br.^2;
end
