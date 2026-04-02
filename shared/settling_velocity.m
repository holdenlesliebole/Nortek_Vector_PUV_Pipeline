function ws = settling_velocity(D, rho_s, rho, nu)
% SETTLING_VELOCITY  Sediment settling velocity via Ferguson & Church (2004).
%
%   ws = settling_velocity(D, rho_s, rho, nu)
%
%   INPUTS
%     D      - grain diameter (m), scalar or vector
%     rho_s  - sediment density (kg/m^3), e.g. 2650 for quartz
%     rho    - fluid density (kg/m^3), e.g. 1025 for seawater
%     nu     - kinematic viscosity (m^2/s), e.g. 1e-6
%
%   OUTPUT
%     ws     - settling velocity (m/s)
%
%   REFERENCE
%     Ferguson & Church (2004), J. Sedimentary Res. 74(6):933-937.

g  = 9.81;
R  = rho_s / rho - 1;   % submerged specific gravity
C1 = 18;
C2 = 0.4;

ws = (R * g .* D.^2) ./ (C1 * nu + sqrt(0.75 * C2 * R * g .* D.^3));
end
