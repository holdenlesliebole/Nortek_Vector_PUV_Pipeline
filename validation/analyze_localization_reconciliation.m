% ANALYZE_LOCALIZATION_RECONCILIATION  Are the bispectral and impedance
% bound-energy localizations the same thing measured two ways?  (todo #59)
%
% The apparent conflict: absolute bispectral E_bound peaks at 0.127 Hz
% (findings_bispectral_beta_2026-07-30.md §5) while the impedance route
% reported "localized 0.145-0.215 Hz, peak 0.180-0.185"
% (findings_hg91_impedance_2026-07-29.md). Those are different weightings:
% the impedance localization is of beta(f), a bound FRACTION per frequency,
% not of absolute bound energy. Absolute energy peaks near 2fp where the
% spectrum is big; a fraction peaks higher, where free energy has fallen.
%
% This script puts both routes in the SAME units -- bound fraction per
% frequency -- and compares peak and half-max span:
%   bispectral: frac(f) = (Eb_ss(f) - EbIm_ss(f)) / P(f), median over the
%               60-set records (Im-part subtracted so high-f rectification
%               noise does not masquerade as a rising fraction);
%   impedance:  median over hours of BETA(:,f) from
%               bound_fraction_spectral.mat (verified to be the doc-15
%               full-theory version: median peak 0.209 at 0.185 Hz).
%
% Weighting caveat that cannot be removed: the bispectral curve is a
% median of per-record ratios (each record one vote), the impedance curve a
% median over 74,658 pooled hours (long records vote more). Stated, not fixed.
%
% Output: outputs/validation/localization_reconciliation.mat
% Run from PUV_Pipeline/:  >> run validation/analyze_localization_reconciliation
% Author: Holden Leslie-Bole, 2026

startup_puv;
root = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'outputs');

BB = load(fullfile(root, 'validation', 'bispectral_beta.mat'));
R  = BB.R;  fG = BB.fGrid;
use = [R.closure_ok] & ~[R.excluded] & [R.in60];

IM = load(fullfile(root, 'validation', 'bound_fraction_spectral.mat'), 'BETA', 'FC');

% --- bispectral fraction curves, median across used records --------------
EbM  = cat(2, R(use).Eb_ss);
ImM  = cat(2, R(use).EbIm_ss);
PM   = cat(2, R(use).P);
fracNet = median((EbM - ImM) ./ PM, 2, 'omitnan');
fracRaw = median(EbM ./ PM,          2, 'omitnan');

% absolute-energy curve (per-record max-normalized), for the contrast
EbN    = EbM ./ max(EbM, [], 1);
absMed = median(EbN, 2, 'omitnan');

% --- impedance beta(f), median over hours --------------------------------
betaImp = median(IM.BETA, 1, 'omitnan').';
fImp    = IM.FC(:);

% --- peaks and half-max spans on a common comparison window --------------
% Restrict to 0.10-0.25 Hz: below 0.10 both curves are ~0/undefined, above
% 0.25 the impedance grid ends.
win  = fG >= 0.10 & fG <= 0.25;
[pkB, spanB] = peak_and_span(fG(win), fracNet(win));
winI = fImp >= 0.10 & fImp <= 0.25;
[pkI, spanI] = peak_and_span(fImp(winI), betaImp(winI));
[pkA, spanA] = peak_and_span(fG(win), absMed(win));

fprintf('\n=============== LOCALIZATION RECONCILIATION (todo #59) ===============\n');
fprintf('bound FRACTION, bispectral (net): peak %.4f at %.3f Hz, half-max %.3f-%.3f Hz\n', ...
    pkB.v, pkB.f, spanB(1), spanB(2));
fprintf('bound FRACTION, impedance beta  : peak %.4f at %.3f Hz, half-max %.3f-%.3f Hz\n', ...
    pkI.v, pkI.f, spanI(1), spanI(2));
fprintf('absolute Eb (record-normalized) : peak at %.3f Hz, half-max %.3f-%.3f Hz\n', ...
    pkA.f, spanA(1), spanA(2));

fprintf('\n%8s %12s %12s %12s\n', 'f (Hz)', 'frac_net', 'frac_raw', 'beta_imped');
for ftest = 0.10:0.02:0.24
    [~, j]  = min(abs(fG   - ftest));
    [~, ji] = min(abs(fImp - ftest));
    fprintf('%8.2f %12.4f %12.4f %12.4f\n', ftest, fracNet(j), fracRaw(j), betaImp(ji));
end

save(fullfile(root, 'validation', 'localization_reconciliation.mat'), ...
    'fG', 'fracNet', 'fracRaw', 'absMed', 'fImp', 'betaImp', ...
    'pkB', 'pkI', 'pkA', 'spanB', 'spanI', 'spanA');
fprintf('\nsaved outputs/validation/localization_reconciliation.mat\n');

function [pk, span] = peak_and_span(f, v)
[vmax, i] = max(v);
pk = struct('f', f(i), 'v', vmax);
ii = find(v > 0.5 * vmax);
span = [f(min(ii)), f(max(ii))];
end
