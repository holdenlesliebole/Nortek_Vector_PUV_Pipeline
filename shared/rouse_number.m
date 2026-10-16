function [P, regime] = rouse_number(ws, tau, rho)
% ROUSE_NUMBER  Rouse number from settling velocity and bed shear stress.
%
%   P = rouse_number(ws, tau, rho)
%   [P, regime] = rouse_number(ws, tau, rho)
%
%   INPUTS
%     ws   - settling velocity (m/s). Pass a COLUMN vector of per-fraction
%            values (e.g. [ws_D16; ws_D50; ws_D84]) to resolve selective
%            transport; see "per-fraction" below.
%     tau  - bed shear stress (Pa). READ THE NEXT SECTION: which stress you pass
%            changes the answer by more than any other choice here.
%     rho  - fluid density (kg/m^3)
%
%   OUTPUTS
%     P      - Rouse number, ws / (kappa * u_star)
%     regime - cellstr classification, same size as P
%
%              P < 0.8   wash load
%              0.8 - 1.2 full suspension
%              1.2 - 2.5 graded suspension
%              2.5 - 7.5 saltation
%              P > 7.5   no suspension (bedload only, IF mobilised at all)
%
%              NOTE the last band means "not suspended", NOT "not moving".
%              Whether the bed moves is set by tau vs a critical Shields stress,
%              which this function knows nothing about. The docstring here said
%              "no motion" until 2026-08-13; that was wrong.
%
%   WHICH STRESS TO PASS
%
%   The Rouse profile assumes a STEADY boundary layer whose sediment diffusivity
%   is kappa*u_star*z over the water column. So u_star must come from a stress
%   that represents time-averaged, column-scale mixing.
%
%     tau_m from WAVE_CURRENT_STRESS   <- correct for suspension under waves
%     tau_c (current only)             <- acceptable when waves are weak
%     tau_w (wave amplitude)           <- WRONG, but see below
%
%   Passing the oscillatory wave stress amplitude (tau_w = 0.5*rho*f_w*U_bed^2,
%   which is what L2.tau_b holds) is a category error twice over: the wave
%   boundary layer is only centimetres thick, so its u_star does not describe
%   column-scale mixing, and the amplitude is a peak rather than a mean. Both
%   errors inflate u_star, so they OVERSTATE suspension.
%
%   That bias direction matters for reading old results. PUV_L3_transport.m fed
%   tau_w to this function until 2026-08-13, and still concluded "bedload
%   dominated across all sites". Because the bias runs toward suspension, that
%   conclusion is conservative and survives the correction; if anything the sites
%   are MORE bedload dominated than reported.
%
%   PER-FRACTION
%
%   A single D50 Rouse number is blind to selective transport, which is the
%   mechanism by which fines are exported offshore while the median stays put.
%   At Torrey the measured D16 suspends at 0.20-0.29x the stress D50 needs, and
%   at 10 m the D16 fraction is already suspended at stresses below the D50
%   mobilisation threshold.
%
%   ws as a column and tau as a row broadcast to a [nFraction x nTime] matrix:
%
%     ws  = settling_velocity([D16; D50; D84], rho_s, rho, nu, 'shape','natural');
%     tau = wave_current_stress(tau_c(:)', tau_w(:)');
%     P   = rouse_number(ws, tau, rho);        % 3 x nTime
%
% Author: Holden Leslie-Bole, 2026. Stress guidance + per-fraction 2026-08-13.
%
% See also WAVE_CURRENT_STRESS, SETTLING_VELOCITY, SOULSBY_WHITEHOUSE_THETA_CR.

kappa  = 0.41;
u_star = sqrt(tau ./ rho);
P      = ws ./ (kappa * u_star);       % broadcasts if ws is a column, tau a row

if nargout > 1
    regime = repmat({''}, size(P));
    regime(P <  0.8)              = {'wash load'};
    regime(P >= 0.8  & P <  1.2)  = {'full suspension'};
    regime(P >= 1.2  & P <  2.5)  = {'graded suspension'};
    regime(P >= 2.5  & P <  7.5)  = {'saltation'};
    regime(P >= 7.5)              = {'no suspension'};
    regime(~isfinite(P))          = {'undefined'};
end
end
