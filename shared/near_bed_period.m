function [Tb, ub_s, Ab] = near_bed_period(Suu, Svv, f, H, zs, fCut, fSS)
% NEAR_BED_PERIOD  Spectral near-bed orbital period T_b = 2 pi A_b / u_b.
%
%   [Tb, ub_s, Ab] = near_bed_period(Suu, Svv, f, H, zs, fCut, fSS)
%
%   Near-bed orbital velocity spectrum from linear theory,
%       S_ubed(f) = [Suu(f) + Svv(f)] / cosh(k zs)^2,
%   integrated over the sea-swell band 0.04 Hz to min(0.25 Hz, fCut):
%       u_b = sqrt( sum S_ubed df )                  (m/s)
%       A_b = sqrt( sum S_ubed / omega^2 df )        (m)
%       T_b = 2 pi A_b / u_b                         (s)
%   (Wiberg & Sherwood 2008). The excursion used by the bed-stress closure is then
%   A_w = U_b T_b / (2 pi) with U_b = L2.Ub, so A_w is the spectrally consistent
%   excursion rather than U_b T_p / (2 pi).
%
%   INPUTS
%     Suu, Svv - velocity auto-spectra for ONE segment [nf x 1] (m^2/s^2/Hz)
%     f        - frequency vector [nf x 1] (Hz), uniform spacing
%     H        - total water depth bed to surface (m)
%     zs       - sensor height above bed (m), L2.doffp
%     fCut     - pressure-correction cutoff for the segment (Hz); non-finite uses fSS(2)
%     fSS      - sea-swell band [fLow fHigh] (Hz), L2.params.fSS
%
%   OUTPUTS
%     Tb   - near-bed orbital period (s); NaN if H is not finite and positive
%     ub_s - spectral u_b (m/s), closure check against L2.Ub (median ratio ~0.96)
%     Ab   - near-bed orbital excursion amplitude A_b (m)
%
%   Definition identical to PUV_Pipeline/validation/archive/paper1_period_sensitivity.m
%   and Paper_1/scripts/diagnostics/spectral_period_rerun_20261105.m.
% Author: Holden Leslie-Bole, 2026-11-05

Tb = NaN; ub_s = NaN; Ab = NaN;
if ~isfinite(H) || H <= 0, return; end
f = f(:);
df = f(2) - f(1);
if ~isfinite(fCut), fCut = fSS(2); end
iF = f >= fSS(1) & f <= min(fSS(2), fCut);
ff = f(iF); om = 2*pi*ff;
k  = get_wavenumber(om, H);
Su = double(Suu(iF)) + double(Svv(iF));
Su = Su(:);
Su(~isfinite(Su)) = 0;
Su_bed = Su ./ (cosh(k(:)*zs).^2);
ub_s = sqrt(sum(Su_bed) * df);
Ab   = sqrt(sum(Su_bed ./ (om(:).^2)) * df);
Tb   = 2*pi*Ab / max(ub_s, eps);
end
