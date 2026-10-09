function [ws, C1, C2, shape] = settling_velocity(D, rho_s, rho, nu, varargin)
% SETTLING_VELOCITY  Sediment settling velocity via Ferguson & Church (2004).
%
%   ws = settling_velocity(D, rho_s, rho, nu)
%   ws = settling_velocity(D, rho_s, rho, nu, 'shape', 'natural_nominal')
%   ws = settling_velocity(D, rho_s, rho, nu, 'C1', 20, 'C2', 1.1)
%   [ws, C1, C2, shape] = settling_velocity(...)
%
%   INPUTS
%     D      - grain diameter (m), scalar or vector
%     rho_s  - sediment density (kg/m^3), e.g. 2650 for quartz
%     rho    - fluid density (kg/m^3), e.g. 1025 for seawater
%     nu     - kinematic viscosity (m^2/s); use seawater_nu(T) for seawater
%              (1.13e-6 at 17 C, 33.5 psu), not a hard-coded 1e-6
%
%   OPTIONS (Ferguson & Church 2004, p. 937: C1 and C2 by grain shape and by how
%   D was measured)
%     'shape'  'natural_nominal' (DEFAULT) C1 = 20, C2 = 1.1  natural grains, D as
%                                nominal diameter (laser diffraction gives an
%                                equivalent-sphere diameter, treated as nominal)
%              'natural_sieve'   C1 = 18, C2 = 1.0  natural grains, sieve diameter
%              'angular'         C1 = 24, C2 = 1.2  very angular grains
%              'sphere'          C1 = 18, C2 = 0.4  smooth spheres
%              'natural'         alias of 'natural_sieve' (the 2026-08-13 to
%                                2026-10-09 default), kept so old calls still mean
%                                what they meant
%     'C1','C2' override either constant directly (takes precedence over 'shape')
%
%   OUTPUT
%     ws     - settling velocity (m/s)
%     C1, C2 - the constants actually used, so a caller can stamp them without
%              keeping its own copy of the default
%     shape  - the shape option in effect ('natural_sieve' for 'natural'), or
%              'custom' when C1 or C2 was overridden
%
%   DEFAULT HISTORY: C2 = 0.4 (sphere) until 2026-08-13; natural_sieve (18/1.0)
%   2026-08-13 to 2026-10-09; natural_nominal (20/1.1) from 2026-10-09. The
%   2026-10-09 choice rests on F&C p.937 and the measurement method: a
%   pre-registered test against the TBR23 surveys could not discriminate between
%   six formulas (Paper_1/results/ws_choice_test_20261009). At 250 um and 17 C the
%   natural_nominal ws is 0.02648 m/s against 0.02876 for natural_sieve (-7.9%).
%
%   WHICH C2 TO USE
%
%   Ferguson & Church give C2 = 0.4 for smooth spheres and C2 = 1.0 for natural
%   grains. Torrey Pines sand is natural quartz; C2 = 1.0 (natural_sieve) was the
%   default 2026-08-13 to 2026-10-09, and natural_nominal (20/1.1) is the default
%   since (see DEFAULT HISTORY above).
%
%   THE DEFAULT WAS 0.4 UNTIL 2026-08-13. That was wrong. It is kept reachable as
%   'sphere' only so the change can be audited, not because it is a defensible
%   choice for this sediment. Anything computed before that date used 0.4.
%
%   The difference is grain-size dependent, so it shifts cross-shore comparisons
%   as well as absolute values (Torrey depth transect):
%
%     D50 (um)   ws C2=0.4   ws C2=1.0   ratio
%       247.1      0.0360      0.0304     1.18
%       226.3      0.0314      0.0267     1.18
%       168.8      0.0195      0.0170     1.15
%       138.6      0.0139      0.0124     1.12
%
%   ws enters Bailard suspended load INVERSELY (q_s ~ 1/ws), so the old high ws
%   UNDERSTATED q_s by 16-26% at the measured TBR23 grain sizes. It also enters
%   the Rouse number directly, where a high ws understates suspension.
%
%   IMPACT OF THE 2026-08-13 CHANGE, measured before it was made
%   (Paper_1/DataCodes/audit_C2_counterfactual_20260813.m): cumulative transport
%   rises 8.6-12.5%, the suspended term rises 16-26%, and the suspended share
%   rises 3.7-5.8 pp. The sea/swell/cross band attribution moves by <= 0.1 pp,
%   no sign flips occur, and the dominant band is unchanged at all four PUVs.
%   The shift is well inside the D50 sensitivity leg the Paper 1 manuscript
%   already reports, which spans a factor of two in A_s.
%
%   REFERENCE
%     Ferguson & Church (2004), J. Sedimentary Res. 74(6):933-937, eq. 4.
%
% Author: Holden Leslie-Bole, 2026. C2 option added and default corrected to the
% natural-grain value 2026-08-13.
%
% See also ROUSE_NUMBER, WAVE_CURRENT_STRESS, SOULSBY_WHITEHOUSE_THETA_CR.

p = inputParser;
p.addParameter('shape', 'natural_nominal', @(x) any(strcmpi(x, ...
    {'natural_nominal','natural_sieve','natural','angular','sphere'})));
p.addParameter('C1', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
p.addParameter('C2', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
p.parse(varargin{:});

switch lower(p.Results.shape)
    case 'natural_nominal',          C1 = 20; C2 = 1.1;
    case {'natural_sieve','natural'}, C1 = 18; C2 = 1.0;
    case 'angular',                  C1 = 24; C2 = 1.2;
    case 'sphere',                   C1 = 18; C2 = 0.4;
end
shape = lower(p.Results.shape); if strcmp(shape, 'natural'), shape = 'natural_sieve'; end
if ~isempty(p.Results.C1), C1 = p.Results.C1; shape = 'custom'; end
if ~isempty(p.Results.C2), C2 = p.Results.C2; shape = 'custom'; end

g  = 9.81;
R  = rho_s / rho - 1;   % submerged specific gravity

ws = (R * g .* D.^2) ./ (C1 * nu + sqrt(0.75 * C2 * R * g .* D.^3));
end
