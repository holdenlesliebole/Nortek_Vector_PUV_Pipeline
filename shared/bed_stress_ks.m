function [tau_b, fric_w, Aw] = bed_stress_ks(Ub, Tp, ks, rho)
% BED_STRESS_KS  Wave-induced bed shear stress for a specified roughness ks.
%
%   [tau_b, fric_w, Aw] = bed_stress_ks(Ub, Tp, ks, rho)
%
%   INPUTS
%     Ub   - near-bed orbital velocity (m/s, RMS over the sea-swell band)
%     Tp   - peak wave period (s)
%     ks   - Nikuradse equivalent sand roughness (m). Typical choices:
%               ks = 2.5*D84     (Wiberg & Smith 1991, natural rippled
%                                  /poorly-sorted beds; RECOMMENDED)
%               ks = 2.5*D50     (literature standard, well-sorted beds)
%               ks = 3.0*D90     (van Rijn 1984; similar idea)
%               ks = bedform-explicit (Nielsen 1992; ripple geometry-aware)
%     rho  - water density (kg/m^3)
%
%   OUTPUTS
%     tau_b  - bed shear stress (Pa)
%     fric_w - wave friction factor (dimensionless)
%     Aw     - wave orbital excursion amplitude (m)
%
%   METHOD
%     Wave friction factor from Swart (1974) piecewise:
%
%       r = A_w / k_s   (relative roughness)
%
%       r < 5            f_w = 0.3 * r^(-0.5)              (smooth/laminar)
%       5 <= r <= 70     f_w = exp(-6.0 + 5.2 * r^(-0.19)) (transitional)
%       r > 70           f_w = 0.0521 * r^(-0.187)         (rough turbulent)
%
%       tau_b = 0.5 * rho * f_w * U_b^2
%
%   For the inner-shelf sand sites in this project, the Wiberg & Smith
%   ks = 2.5*D84 form is the recommended default — it captures bed
%   roughness set by the coarsest grains the bed presents (which dominate
%   form drag on poorly-sorted natural beds; sorting sigma ~ 1.7-2.2 at
%   Torrey) and uses measured PSD data via site_grain_size.m.
%
%   See also: site_grain_size (per-site D50/D84/D90 lookup),
%             bed_stress (legacy; takes D50 + uses ks = 10*D50 internally).
%
%   REFERENCES
%     Swart, D.H. (1974). Offshore sediment transport and equilibrium
%       beach profiles. Delft Hydraulics Lab. Publ. 131.
%     Wiberg, P.L. & Smith, J.D. (1991). Velocity distribution and bed
%       roughness in high-gradient streams. Water Resour. Res. 27, 825-838.
%     Soulsby, R.L. (1997). Dynamics of Marine Sands. Thomas Telford.
%
% Author: Holden Leslie-Bole, 2026-05-23 (Paper 2 audit of bed-stress methods)

Aw = (Ub .* Tp) / (2 * pi);
r  = Aw ./ ks;

fric_w = nan(size(r));

idx = r < 5;
fric_w(idx) = 0.3 * r(idx).^(-0.5);

idx = r >= 5 & r <= 70;
fric_w(idx) = exp(-6.0 + 5.2 * r(idx).^(-0.19));

idx = r > 70;
fric_w(idx) = 0.0521 * r(idx).^(-0.187);

tau_b = 0.5 * rho .* fric_w .* Ub.^2;
end
