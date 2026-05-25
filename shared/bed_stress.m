function [tau_b, fric_w, Aw] = bed_stress(Ub, Tp, D50, rho)
% BED_STRESS  Wave-induced bed shear stress via Swart (1974).
%
%   [tau_b, fric_w, Aw] = bed_stress(Ub, Tp, D50, rho)
%
%   INPUTS
%     Ub   - near-bed orbital velocity amplitude (m/s)
%     Tp   - peak wave period (s)
%     D50  - median grain diameter (m)
%     rho  - water density (kg/m^3)
%
%   OUTPUTS
%     tau_b  - bed shear stress (Pa)
%     fric_w - wave friction factor (dimensionless)
%     Aw     - wave orbital excursion amplitude (m)
%
%   NOTE (2026-05-23)
%     This legacy form uses ks = 10*D50 internally — an unprincipled
%     middle-ground that doesn't match either the literature flat-bed grain
%     standard (ks = 2.5*D50) or a bedform-explicit movable-bed roughness.
%     For new analyses prefer bed_stress_ks, which takes ks directly and
%     pairs naturally with site_grain_size (ks = 2.5*D84 from measured PSD,
%     Wiberg & Smith 1991). Retained here for backward compatibility with
%     existing PUV L2 outputs that were generated with this default.
%
%   REFERENCE
%     Swart (1974), Coastal Engineering Proc. 14.
%
% See also: bed_stress_ks, site_grain_size
%
% Author: Holden Leslie-Bole, 2026

ks = 10 * D50;               % Nikuradse roughness (m)
Aw = (Ub .* Tp) / (2 * pi); % orbital excursion amplitude (m)
r  = Aw ./ ks;               % relative roughness

fric_w = nan(size(r));

% Smooth flow
idx = r < 5;
fric_w(idx) = 0.3 * r(idx).^(-0.5);

% Transitional
idx = r >= 5 & r <= 70;
fric_w(idx) = exp(-6.0 + 5.2 * r(idx).^(-0.19));

% Rough flow
idx = r > 70;
fric_w(idx) = 0.0521 * r(idx).^(-0.187);

tau_b = 0.5 * rho .* fric_w .* Ub.^2;
end
