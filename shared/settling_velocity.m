function ws = settling_velocity(D, rho_s, rho, nu, varargin)
% SETTLING_VELOCITY  Sediment settling velocity via Ferguson & Church (2004).
%
%   ws = settling_velocity(D, rho_s, rho, nu)
%   ws = settling_velocity(D, rho_s, rho, nu, 'shape', 'natural')
%   ws = settling_velocity(D, rho_s, rho, nu, 'C2', 1.0)
%
%   INPUTS
%     D      - grain diameter (m), scalar or vector
%     rho_s  - sediment density (kg/m^3), e.g. 2650 for quartz
%     rho    - fluid density (kg/m^3), e.g. 1025 for seawater
%     nu     - kinematic viscosity (m^2/s), e.g. 1e-6
%
%   OPTIONS
%     'shape'  'natural' (DEFAULT, C2 = 1.0) natural sand grains
%              'sphere'  (C2 = 0.4)          smooth spheres
%     'C2'     override the drag coefficient directly
%
%   OUTPUT
%     ws     - settling velocity (m/s)
%
%   WHICH C2 TO USE
%
%   Ferguson & Church give C2 = 0.4 for smooth spheres and C2 = 1.0 for natural
%   grains. Torrey Pines sand is natural angular quartz, so 1.0 is correct and is
%   the default as of 2026-08-13.
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
p.addParameter('shape', 'natural', @(x) any(strcmpi(x, {'sphere','natural'})));
p.addParameter('C2', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
p.parse(varargin{:});

if ~isempty(p.Results.C2)
    C2 = p.Results.C2;
elseif strcmpi(p.Results.shape, 'sphere')
    C2 = 0.4;
else
    C2 = 1.0;
end

g  = 9.81;
R  = rho_s / rho - 1;   % submerged specific gravity
C1 = 18;

ws = (R * g .* D.^2) ./ (C1 * nu + sqrt(0.75 * C2 * R * g .* D.^3));
end
