function P = rouse_number(ws, tau_b, rho)
% ROUSE_NUMBER  Rouse number from settling velocity and bed shear stress.
%
%   P = rouse_number(ws, tau_b, rho)
%
%   INPUTS
%     ws    - settling velocity (m/s)
%     tau_b - bed shear stress (Pa)
%     rho   - fluid density (kg/m^3)
%
%   OUTPUT
%     P     - Rouse number (ws / kappa*u_star)
%             P < 0.8  : wash load
%             0.8–1.2  : 100% suspension
%             1.2–2.5  : graded suspension
%             2.5–7.5  : saltation (bedload)
%             P > 7.5  : no motion
% Author: Holden Leslie-Bole, 2026

kappa = 0.41;
u_star = sqrt(tau_b ./ rho);
P = ws ./ (kappa * u_star);
end
