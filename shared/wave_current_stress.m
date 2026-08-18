function [tau_m, tau_max] = wave_current_stress(tau_c, tau_w, phi)
%WAVE_CURRENT_STRESS  Combined wave-current bed shear stress, Soulsby (1997).
%
%   [tau_m, tau_max] = wave_current_stress(tau_c, tau_w)
%   [tau_m, tau_max] = wave_current_stress(tau_c, tau_w, phi)
%
%   INPUTS
%     tau_c  - current-only bed shear stress (Pa). From the mean flow:
%              tau_c = rho * Cd * |U|^2, Cd from a log profile or ~2.5e-3.
%     tau_w  - wave-only bed shear stress AMPLITUDE (Pa):
%              tau_w = 0.5 * rho * f_w * U_bed^2.   This is what L2.tau_b holds.
%     phi    - angle between current and wave directions (rad). Default 0
%              (collinear), which maximises tau_max.
%
%   OUTPUTS
%     tau_m    - MEAN combined stress over a wave cycle (Pa). Governs the
%                time-averaged turbulent diffusivity, so this is the stress that
%                belongs in a Rouse exponent.
%     tau_max  - MAXIMUM combined stress within a wave cycle (Pa). Governs
%                entrainment, so this is the stress to compare against a
%                critical Shields stress.
%
%   WHY THIS EXISTS
%
%   Passing the wave stress amplitude tau_w straight into a Rouse number is a
%   category error, and it was what PUV_L3_transport.m did until 2026-08-13.
%   The Rouse profile assumes a steady boundary layer with sediment diffusivity
%   kappa*u_star*z acting over the water column. The WAVE boundary layer is only
%   a few centimetres thick, so u_star derived from tau_w does not describe
%   column-scale mixing, and using the oscillatory PEAK rather than a mean
%   overstates suspension on top of that.
%
%   The physically meaningful split is:
%     entrainment  -> tau_max vs tau_cr    (does the bed mobilise at all)
%     suspension   -> Rouse from tau_m     (does it mix up into the column)
%     advection    -> the MEAN current      (does it go anywhere)
%
%   NON-LINEARITY WORTH KNOWING. tau_m is NOT tau_c + tau_w. Waves enhance the
%   current-related stress through boundary-layer interaction, so a large tau_w
%   with a small tau_c still yields tau_m only modestly above tau_c. In the limit
%   tau_c -> 0 this formula gives tau_m -> 0: waves alone produce no mean stress
%   and therefore no Rouse-type suspension profile. That is physically right and
%   is exactly the behaviour the old code was missing.
%
%   REFERENCE
%     Soulsby, R.L. (1997), Dynamics of Marine Sands, Thomas Telford. The
%     "DATA13" mean/max combined-stress parameterisation.
%
% Author: Holden Leslie-Bole, 2026-08-13
%
% See also ROUSE_NUMBER, SETTLING_VELOCITY.

if nargin < 3 || isempty(phi), phi = 0; end

tau_c = max(tau_c, 0);
tau_w = max(tau_w, 0);

denom = tau_c + tau_w;
ratio = zeros(size(denom));
g = denom > 0;
ratio(g) = tau_w(g) ./ denom(g);

tau_m   = tau_c .* (1 + 1.2 * ratio.^3.2);
tau_max = sqrt((tau_m + tau_w .* cos(phi)).^2 + (tau_w .* sin(phi)).^2);
end
