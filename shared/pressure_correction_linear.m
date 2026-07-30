function [S_eta, Kp, fCut] = pressure_correction_linear(Spp_m, f, H, z_sensor, KpMin)
% PRESSURE_CORRECTION_LINEAR  Pressure spectrum to surface elevation spectrum.
%
%   [S_eta, Kp, fCut] = pressure_correction_linear(Spp_m, f, H, z_sensor, KpMin)
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
%   THE WAVENUMBER COMES FROM A NEWTON SOLVE, NOT AN APPROXIMATION.
%   k is obtained from shared/get_wavenumber.m, which solves
%   omega^2 = g k tanh(k h) by Newton's method to 1e-10. The Wu & Thornton
%   (1986) explicit approximation (their Eqs. 6/8/9) and Bill O'Reilly's
%   modified-Wu coefficients were both evaluated against it and REJECTED --
%   see validation/compare_wavenumber_methods.m, which reports the kh relative
%   error of each and the resulting impact on Hs.
%
%   RENAMED 2026-07-29 from pressure_correction_wu.m. The old name asserted a
%   method this function does not use and had already caused one incorrect claim
%   that the pipeline applies Wu & Thornton. If you are looking for that
%   approximation, it is not here and it is not used anywhere in the pipeline.
%
%   ON THE FORMER "revisit before publication" TODO (closed 2026-07-29).
%   The concern was that a linear transfer function mis-estimates a BOUND
%   harmonic, which is phase-locked to its primary and carries wavenumber 2*k0
%   rather than the free-wave k(2*f0) this function assumes. That is real, and
%   it was quantified rather than left open:
%     - The published weakly-nonlinear correction (Bonneton & Lannes 2018,
%       Coastal Engineering 138, eq. 19 / 46) is implemented in
%       shared/bonneton_nl_correction.m and closure-tested to 3e-16 in
%       L2_spectral/test_bonneton_reconstruction.m.
%     - Measured on 4 records over 5.6-15.5 m and 7,721 hourly segments, this
%       linear form UNDER-estimates harmonic-band energy by 0.46% (peak-band
%       control 1.0004). The direction matters: it makes a measured harmonic
%       excess conservative, not inflated.
%     - Bonneton & Lannes' own Figure 9 states the linear reconstruction
%       describes the first and second harmonics properly; it is the third and
%       fourth where it fails.
%   So this function is fit for purpose for bulk and second-harmonic work, and
%   the residual bias is documented rather than unknown. Use
%   bonneton_nl_correction.m if you need the crest shape, skewness, or harmonics
%   above the second. See Bishop & Donelan (1987) for the transfer-function
%   method itself and Jones & Monismith (2007) on non-hydrostatic effects.
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
%   (The former "TODO: revisit pressure correction coefficients before
%   publication" is CLOSED -- resolved 2026-07-29 and written up above.)
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
