function [D, C1, C2, shape] = ws_to_D(ws, rho_s, rho, nu, varargin)
% WS_TO_D  Grain diameter from settling velocity: the inverse of SETTLING_VELOCITY.
%
%   D = ws_to_D(ws, rho_s, rho, nu)
%   D = ws_to_D(ws, rho_s, rho, nu, 'shape', 'natural_sieve')
%   [D, C1, C2, shape] = ws_to_D(...)
%
%   Solves Ferguson & Church (2004) eq. 4 for D, element by element, with
%   fzero. ws(D) increases monotonically with D, so each root is unique. The
%   forward model is SETTLING_VELOCITY itself, called with the same options, so
%   the two cannot drift apart.
%
%   INPUTS
%     ws     - settling velocity (m/s), scalar or array; ws <= 0 or NaN -> NaN
%     rho_s  - sediment density (kg/m^3), 2650 for quartz
%     rho    - fluid density (kg/m^3) of the fluid the grains settled in
%     nu     - kinematic viscosity (m^2/s) of that fluid, at its temperature
%     options are passed straight to SETTLING_VELOCITY ('shape', 'C1', 'C2')
%
%   OUTPUT
%     D      - diameter (m), same size as ws
%     C1, C2, shape - the constants used, as returned by SETTLING_VELOCITY
%
%   WHICH DIAMETER COMES BACK. D is whatever diameter the chosen C1/C2 pair
%   was fitted to: a sieve diameter for 'natural_sieve' (18/1.0), a nominal
%   diameter for 'natural_nominal' (20/1.1, the default). The same ws gives a
%   different D under each pair, so choose the pair for the dataset D will be
%   compared against, and record it.
%
%   SETTLING-TUBE DATA (the reason this exists, 2026-10-14). Lab tubes are
%   usually fresh water at room temperature, not seawater: use the tube's
%   fluid, e.g. [nu, m] = seawater_nu(T_lab, 0); rho = m.rho. nu changes about
%   2.5% per degree C, and at 246 um a 10% rise in nu moves D by +4% (246 to
%   256 um; nu^(1/2) in the Stokes limit), so an unknown lab temperature is a
%   real uncertainty; bracket it. If a report gives a
%   "fall diameter" rather than fall times, that number already went through
%   the authors' own conversion (often a sphere curve), so recover their ws
%   with THEIR relation before inverting with this one. See
%   sediment_grain_size/docs/todo.md, "USACE settling-tube dataset".
%
%   REFERENCE
%     Ferguson & Church (2004), J. Sedimentary Res. 74(6):933-937, eq. 4.
%
% Author: Holden Leslie-Bole, 2026-10-14.
%
% See also SETTLING_VELOCITY, SEAWATER_NU.

[~, C1, C2, shape] = settling_velocity(1e-4, rho_s, rho, nu, varargin{:});

D = nan(size(ws));
for i = 1:numel(ws)
    if ~(ws(i) > 0), continue; end
    f = @(logD) settling_velocity(exp(logD), rho_s, rho, nu, varargin{:}) - ws(i);
    D(i) = exp(fzero(f, log([1e-7 1e-1]), optimset('TolX', 1e-12)));   % 0.1 um to 10 cm
end
end
