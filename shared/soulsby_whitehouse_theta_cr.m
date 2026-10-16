function [theta_cr, D_star] = soulsby_whitehouse_theta_cr(D50, rho_s, rho_w, nu, g)
%SOULSBY_WHITEHOUSE_THETA_CR  Critical Shields parameter from Soulsby & Whitehouse (1997).
%   [theta_cr, D_star] = soulsby_whitehouse_theta_cr(D50, rho_s, rho_w, nu, g)
%
%   Computes the critical Shields parameter theta_cr for incipient motion of
%   a non-cohesive sand bed as a function of dimensionless grain size D_star,
%   using the Soulsby & Whitehouse (1997) empirical formula:
%
%       D_star    = D50 * (g * (s-1) / nu^2)^(1/3),     s = rho_s / rho_w
%       theta_cr  = 0.30 / (1 + 1.2 * D_star)
%                 + 0.055 * (1 - exp(-0.020 * D_star))
%
%   This is the de facto standard for fine-to-medium sand in coastal models
%   (Delft3D, XBeach, SISYPHE). It is preferred over the constant theta_cr
%   = 0.05 Shields asymptote for sand in the D_star = 5-10 range, where the
%   viscous sublayer reduces the threshold below the coarse-grain limit.
%
%   Inputs (all scalar or vector-compatible):
%       D50    [m]       median grain diameter
%       rho_s  [kg/m^3]  sediment density (quartz: 2650)
%       rho_w  [kg/m^3]  fluid density (seawater: 1025)
%       nu     [m^2/s]   kinematic viscosity of fluid; use seawater_nu(T)
%                        (1.13e-6 at 17 C, 1.19e-6 at 15 C; 1.05e-6 is ~20 C)
%       g      [m/s^2]   gravitational acceleration (9.81)
%
%   Outputs:
%       theta_cr  critical Shields parameter (dimensionless)
%       D_star    dimensionless grain diameter (dimensionless)
%
%   Reference:
%       Soulsby, R. L., & Whitehouse, R. J. S. (1997). Threshold of sediment
%       motion in coastal environments. In Pacific Coasts and Ports '97
%       Conference Proceedings, Christchurch, pp. 145-150.
%
%   Moved here from Paper_1/DataCodes 2026-10-09: PUV_L3_transport called it but
%   it existed only in Paper_1, found through the MATLAB path, so the pipeline did
%   not run on its own and a Paper_1 edit would have changed L3 silently.

    s      = rho_s / rho_w;
    D_star = D50 .* (g .* (s - 1) ./ nu.^2).^(1/3);

    theta_cr = 0.30 ./ (1 + 1.2 .* D_star) ...
             + 0.055 .* (1 - exp(-0.020 .* D_star));
end
