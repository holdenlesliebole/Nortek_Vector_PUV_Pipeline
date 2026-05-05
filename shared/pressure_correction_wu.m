function [S_eta, Kp, fCut] = pressure_correction_wu(Spp_m, f, H, z_sensor, KpMin)
% PRESSURE_CORRECTION_WU  Pressure spectrum to surface elevation spectrum.
%
%   [S_eta, Kp, fCut] = pressure_correction_wu(Spp_m, f, H, z_sensor, KpMin)
%
%   Applies the linear wave theory pressure transfer function to convert a
%   pressure PSD measured at some height above the bed to a surface elevation
%   PSD.  The transfer function is:
%
%       Kp(f) = cosh(k * z_sensor) / cosh(k * H)
%       S_eta(f) = Spp(f) / Kp(f)^2
%
%   Frequencies where Kp drops below KpMin are zeroed to suppress noise
%   amplification at high frequencies.
%
%   INPUTS
%     Spp_m    - pressure PSD in m^2/Hz [nf x 1]
%                (caller converts dBar to meters before computing PSD)
%     f        - frequency vector (Hz) [nf x 1], from pwelch
%     H        - total water depth, bed to surface (m)
%     z_sensor - sensor height above bed (m), i.e. doffp
%     KpMin    - minimum Kp threshold (default 0.1); frequencies with
%                Kp < KpMin are set to zero in S_eta
%
%   OUTPUTS
%     S_eta - surface elevation PSD (m^2/Hz) [nf x 1]
%     Kp    - pressure transfer function [nf x 1]
%     fCut  - cutoff frequency (Hz) where Kp first drops below KpMin
%
%   REQUIRES
%     get_wavenumber.m on the MATLAB path
%
%   TODO: Revisit pressure correction coefficients before publication.
%         There is disagreement in the literature about the appropriate
%         form of Kp (e.g., non-hydrostatic corrections, depth-dependent
%         modifications). Current implementation uses standard linear wave
%         theory. See also Jones & Monismith (2007), Bishop & Donelan (1987).
% Author: Holden Leslie-Bole, 2026

if nargin < 5 || isempty(KpMin)
    KpMin = 0.1;
end

nf = length(f);
Kp = ones(nf, 1);

% Compute wavenumber for all non-DC frequencies (vectorized)
omega = 2 * pi * f(2:end);
k = get_wavenumber(omega, H);

% Transfer function: ratio of pressure at sensor to surface elevation
Kp(2:end) = cosh(k(:) .* z_sensor) ./ cosh(k(:) .* H);

% Find cutoff frequency
iCut = find(Kp < KpMin, 1, 'first');
if isempty(iCut)
    fCut = f(end);
else
    fCut = f(iCut);
end

% Apply correction
S_eta = Spp_m ./ (Kp.^2);

% Zero out unreliable high-frequency bins
S_eta(Kp < KpMin) = 0;

% DC bin has no wave energy
S_eta(1) = 0;

end
