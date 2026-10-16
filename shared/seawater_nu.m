function [nu, meta] = seawater_nu(T_C, S_psu)
%SEAWATER_NU  Kinematic viscosity of seawater. The single source of truth for the
%PUV pipeline and the papers (moved here from Paper_1/DataCodes 2026-10-09; Paper_1
%calls this copy). PUV_L3_transport evaluates it per segment from L2.Tmean.
%
%   nu = seawater_nu()            % TBR23 deployment-mean conditions
%   nu = seawater_nu(T_C)         % at a given temperature, S = 33.5 psu
%   nu = seawater_nu(T_C, S_psu)
%   [nu, meta] = seawater_nu(...) % struct with T, S, rho, mu and the provenance
%
%   Returns nu in m^2/s.
%
% WHY THIS FUNCTION EXISTS (2026-09-11)
%   Paper 1 and Paper 2 were each using a different hardcoded value, and Paper 1's
%   fig07 was using both at once -- the tau_c annotation at 1.05e-6 and the D16/D84
%   band via run_transport_model at 1.0e-6. Neither number was derived from anything.
%   Both are wrong for this deployment, and the error is one-sided: both are too
%   SMALL, so both understate tau_c and overstate the mobilization duty cycle.
%
% THE DERIVATION, from this deployment's own data
%   Bed temperature was recorded by all four TBR23 Vectors and is in the L1 product
%   (PUV.T, gated on PUV.qc.valid_T). Over ~46 million samples:
%
%       MOP580 5 m   mean 17.08 C     MOP586 5 m   mean 17.54 C
%       MOP580 7 m   mean 16.58 C     MOP586 7 m   mean 16.58 C
%       pooled       mean 16.94 C, median 17.00, 5th-95th 14.29-19.74
%
%   At T = 16.9 C and S = 33.5 psu (Southern California nearshore), the Sharqawy,
%   Lienhard & Zubair (2010) seawater viscosity correlation with the UNESCO EOS-80
%   density gives mu = 1.158e-3 Pa s, rho = 1024.4 kg/m^3, and
%
%       nu = 1.131e-6 m^2/s
%
%   For scale: 1.05e-6 is seawater at about 20 C and 1.00e-6 at about 23 C, so the
%   values previously in use correspond to water 3 to 6 degrees warmer than the bed
%   actually was. The docstring in soulsby_whitehouse_theta_cr.m calling 1.05e-6
%   "seawater ~15C" is also wrong: seawater at 15 C is 1.19e-6.
%
%   Sensitivity is mild and the temperature term dominates. Over the deployment's
%   5th-95th temperature range nu spans 1.056e-6 to 1.208e-6 (-7% to +7%); over a
%   salinity range of 33.0-34.0 psu it moves by less than 0.1%.
%
% WHAT IT CHANGES
%   nu enters ONLY the Soulsby-Whitehouse critical Shields parameter, through the
%   dimensionless grain size D* ~ nu^(-2/3). It does NOT enter the bed stress: the
%   TBR23 segments are rough-turbulent (A_w/k_s medians 236-372), so the Swart wave
%   friction factor is viscosity-independent. Larger nu -> smaller D* -> larger
%   theta_cr -> larger tau_c -> lower mobilization duty cycle.
%
%   See Paper_1/docs/viscosity_resolution_2026-09-11.md for the full before/after
%   table and the manuscript rows that move.
%
% REFERENCES
%   Sharqawy, M.H., J.H. Lienhard V & S.M. Zubair (2010). Thermophysical properties
%     of seawater: a review of existing correlations and data. Desalination and Water
%     Treatment 16, 354-380.  (viscosity, Sec. 3.6; valid 0-180 C, S = 0-150 g/kg)
%   UNESCO (1981). Background papers and supporting data on the International
%     Equation of State of Seawater 1980. Tech. Papers in Marine Sci. 38. (density)
%
% Holden Leslie-Bole, 2026-09-11.

if nargin < 1 || isempty(T_C),   T_C   = 16.94; end   % TBR23 pooled bed mean
if nargin < 2 || isempty(S_psu), S_psu = 33.5;  end   % SoCal nearshore

% --- dynamic viscosity, Sharqawy et al. (2010) ---
S  = S_psu / 1000;                                    % kg/kg
mu_w = 4.2844e-5 + 1 ./ (0.157*(T_C + 64.993).^2 - 91.296);
A = 1.541  + 1.998e-2*T_C - 9.52e-5*T_C.^2;
B = 7.974  - 7.561e-2*T_C + 4.724e-4*T_C.^2;
mu = mu_w .* (1 + A.*S + B.*S.^2);

% --- density, UNESCO EOS-80 at atmospheric pressure ---
a = [999.842594 6.793952e-2 -9.095290e-3 1.001685e-4 -1.120083e-6 6.536332e-9];
b = [8.24493e-1 -4.0899e-3 7.6438e-5 -8.2467e-7 5.3875e-9];
c = [-5.72466e-3 1.0227e-4 -1.6546e-6];
rho_w0 = polyval(fliplr(a), T_C);
rho = rho_w0 + polyval(fliplr(b), T_C).*S_psu ...
             + polyval(fliplr(c), T_C).*S_psu.^1.5 + 4.8314e-4*S_psu.^2;

nu = mu ./ rho;

if nargout > 1
    meta = struct('T_C', T_C, 'S_psu', S_psu, 'mu_Pa_s', mu, 'rho_kg_m3', rho, ...
        'source', 'Sharqawy et al. (2010) viscosity + UNESCO EOS-80 density', ...
        'provenance', ['TBR23 L1 PUV.T, four Vectors, pooled mean 16.94 C ' ...
                       '(see the header of seawater_nu.m)']);
end
end
